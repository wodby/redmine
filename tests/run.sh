#!/usr/bin/env bash

# Starts the image against an empty PostgreSQL database, as the Redmine stack
# runs it, then checks the health endpoint, the install action, signing in,
# the stylesheets, an attachment upload through the REST API and a second run
# of the action.

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

network="${NAME}-net"
postgres="${NAME}-postgres"
files="${NAME}-files"
web="${NAME}-web"
job="${NAME}-job"
# Characters that break unquoted YAML and URLs.
db_password="redmine p'a#{s}s/w:rd@1"
admin_password='Adm1n pass/w:rd'

cleanup() {
    local status=$?
    if [[ "${status}" -ne 0 ]]; then
        docker logs --tail 50 "${web}" 2>&1 || true
    fi
    docker rm -vf "${job}" "${web}" "${postgres}" > /dev/null 2>&1 || true
    docker volume rm -f "${files}" > /dev/null 2>&1 || true
    docker network rm "${network}" > /dev/null 2>&1 || true
    exit "${status}"
}
trap cleanup EXIT

expect() {
    local description=$1 actual=$2 expected=$3
    echo -n "${description}... "
    if [[ "${actual}" != *"${expected}"* ]]; then
        echo "Error: expected ${expected}, got: ${actual}"
        exit 1
    fi
    echo "OK"
}

# Requests from inside the container, as the gateway sends them.
request() {
    docker exec "${web}" curl -sS -H 'Host: redmine.example.com' -H 'X-Forwarded-Proto: https' "${@}"
}

status() {
    request -o /dev/null -w '%{http_code}' "http://localhost:3000$1"
}

env=(
    -e DB_HOST="${postgres}"
    -e DB_NAME=redmine
    -e DB_USER=redmine
    -e DB_PASSWORD="${db_password}"
    -e SECRET_KEY_BASE=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
    -e WEB_CONCURRENCY=2
    # No mail server answers there: sending email during a request must not
    # break the request.
    -e SMTP_HOST="${NAME}-no-smtp"
)
setup_env=(
    -e REDMINE_ADMIN_LOGIN=owner
    -e REDMINE_ADMIN_PASSWORD="${admin_password}"
    -e REDMINE_ADMIN_EMAIL=owner@example.com
    -e REDMINE_MAIL_FROM=noreply@redmine.example.com
    -e WODBY_PRIMARY_URL=https://redmine.example.com
)

docker network create "${network}" > /dev/null
docker volume create "${files}" > /dev/null
docker run -d --name "${postgres}" --network "${network}" \
    -e POSTGRES_DB=redmine -e POSTGRES_USER=redmine -e POSTGRES_PASSWORD="${db_password}" \
    postgres:17-alpine > /dev/null
for _ in $(seq 1 60); do
    docker exec "${postgres}" pg_isready -U redmine -d redmine > /dev/null 2>&1 && break
    sleep 2
done

docker run -d --name "${web}" --network "${network}" -v "${files}:/mnt/files" "${env[@]}" "${IMAGE}" > /dev/null

# The container is ready before the first installation creates the tables.
for _ in $(seq 1 60); do
    [[ "$(status /-/health 2>/dev/null)" == 200 ]] && break
    sleep 2
done
expect "Health check before installation" "$(status /-/health)" 200

expect "Redmine version" "$(docker exec "${web}" bin/rails runner 'puts Redmine::VERSION.to_s' 2>/dev/null)" "${REDMINE_VER}"
# Emails are sent during the request, not from a queue in memory that a restart loses.
expect "Mailer queue" "$(docker exec "${web}" bin/rails runner 'puts ActionMailer::MailDeliveryJob.queue_adapter.class.name' 2>/dev/null)" "InlineAdapter"

# The install action, in a separate container like the post-deploy job.
run_update() {
    docker rm -f "${job}" > /dev/null 2>&1 || true
    docker run --name "${job}" --network "${network}" -v "${files}:/mnt/files" "${env[@]}" "${@}" \
        "${IMAGE}" redmine-update 2>&1
}

if output="$(run_update)"; then
    echo "Error: the install action succeeded without an admin password"
    exit 1
fi
expect "Install without an admin password fails" "${output}" "REDMINE_ADMIN_PASSWORD is empty"
stock_status="$(docker exec "${postgres}" psql -qtAU redmine -d redmine -c "select status from users where login = 'admin'")"
expect "The stock admin account is locked" "${stock_status}" 3

output="$(run_update "${setup_env[@]}")"
expect "Install sets up the administrator" "${output}" "Set up the administrator owner"
expect "Install sets the host name" "${output}" "Set the host name to https://redmine.example.com"

output="$(run_update "${setup_env[@]}")"
echo -n "Second run leaves the installation alone... "
if [[ "${output}" == *"Set up the administrator"* || "${output}" == *"Loaded the default"* ]]; then
    echo "Error: ${output}"
    exit 1
fi
echo "OK"

expect "Sign-in page" "$(status /login)" 200

# The stylesheet the page links to is served.
css="$(request http://localhost:3000/login | grep -o '/assets/application-[^"]*\.css' | head -n1)"
expect "Stylesheet link" "${css}" "/assets/application-"
expect "Stylesheet" "$(status "${css}")" 200

# Sign in with the form, as a browser does.
docker exec "${web}" rm -f /tmp/cookies
token="$(request -c /tmp/cookies http://localhost:3000/login | grep -o 'name="authenticity_token" value="[^"]*"' | head -n1 | sed 's/.*value="//; s/"$//')"
expect "Sign-in form token" "${token}" ""
location="$(request -b /tmp/cookies -c /tmp/cookies -o /dev/null -w '%{redirect_url}' \
    --data-urlencode "authenticity_token=${token}" --data-urlencode username=owner \
    --data-urlencode "password=${admin_password}" http://localhost:3000/login)"
expect "Sign in as the administrator" "${location}" "https://redmine.example.com/my/page"
expect "Signed-in page" "$(request -b /tmp/cookies http://localhost:3000/my/page)" "owner"

# An attachment through the REST API lands in the files volume.
# The administrator is notified of its own changes too, so creating the issue
# sends an email.
docker exec "${web}" bin/rails runner 'Setting.rest_api_enabled = "1"; User.find_by(login: "owner").pref.update!(no_self_notified: false)' > /dev/null 2>&1
upload="$(request -u "owner:${admin_password}" -H 'Content-Type: application/octet-stream' \
    --data-binary 'wodby test attachment' 'http://localhost:3000/uploads.json?filename=test.txt')"
expect "Upload an attachment" "${upload}" '"token"'
project="$(request -u "owner:${admin_password}" -H 'Content-Type: application/json' \
    -d '{"project": {"name": "Wodby test", "identifier": "wodby-test"}}' http://localhost:3000/projects.json)"
expect "Create a project" "${project}" '"identifier":"wodby-test"'
upload_token="$(echo "${upload}" | sed 's/.*"token":"\([^"]*\)".*/\1/')"
issue="$(request -u "owner:${admin_password}" -H 'Content-Type: application/json' \
    -d "{\"issue\": {\"project_id\": \"wodby-test\", \"subject\": \"Test\", \"uploads\": [{\"token\": \"${upload_token}\", \"filename\": \"test.txt\"}]}}" \
    http://localhost:3000/issues.json)"
expect "Create an issue with the attachment" "${issue}" '"subject":"Test"'
expect "The notification email was tried during the request" "$(docker logs "${web}" 2>&1)" "Email delivery error"
expect "Attachment in the files volume" "$(docker exec "${web}" sh -c 'cat $(find /mnt/files -type f -name "*test.txt")')" "wodby test attachment"

echo "All checks passed"
