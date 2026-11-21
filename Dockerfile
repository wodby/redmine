ARG BASE_IMAGE

# Redmine's official image: Debian with Ruby, Redmine and its gems, including
# every database adapter and Puma. Its version comes from the pinned base image.
FROM ${BASE_IMAGE}

ARG WODBY_USER_ID=1000
ARG WODBY_GROUP_ID=1000

ENV APP_ROOT="/usr/src/redmine" \
    HOME="/home/wodby" \
    REDMINE_FILES_DIR="/mnt/files"

USER root

RUN set -eux; \
    \
    # Upgrade inherited packages even when their existing versions satisfy dependencies.
    apt-get update; \
    apt-get upgrade -y; \
    # curl for health checks and scripts.
    apt-get install -y --no-install-recommends curl; \
    rm -rf /var/lib/apt/lists/*; \
    \
    groupadd -g "${WODBY_GROUP_ID}" wodby; \
    useradd -u "${WODBY_USER_ID}" -g wodby -m -s /bin/bash wodby; \
    \
    mkdir -p "${REDMINE_FILES_DIR}"; \
    chown -R wodby:wodby "${APP_ROOT}" "${REDMINE_FILES_DIR}"; \
    \
    { \
        echo 'export PS1="\u@$(hostname):\w $ "'; \
        echo "export PATH=${PATH}"; \
    } | tee -a /home/wodby/.bashrc /home/wodby/.profile >/dev/null

COPY --chown=wodby:wodby config ${APP_ROOT}/config/
COPY --chown=wodby:wodby lib ${APP_ROOT}/lib/
COPY bin /usr/local/bin/
COPY share /usr/local/share/wodby/
COPY docker-entrypoint.sh /

USER wodby

WORKDIR ${APP_ROOT}

# Compile the stylesheets and scripts once here, so containers start without
# doing it. The database is not used.
RUN set -eux; \
    SECRET_KEY_BASE=assets bin/rails assets:precompile; \
    rm -rf tmp/cache

EXPOSE 3000

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "/usr/local/share/wodby/puma.rb"]
