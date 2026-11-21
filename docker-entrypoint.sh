#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

# Rails signs sessions and cookies with SECRET_KEY_BASE. Without one, a random
# key is used, so every restart signs everybody out.
if [[ -z "${SECRET_KEY_BASE}" ]]; then
    SECRET_KEY_BASE="${REDMINE_SECRET_KEY_BASE}"
fi
if [[ -z "${SECRET_KEY_BASE}" ]]; then
    echo >&2 "Warning: SECRET_KEY_BASE is not set, using a random key: sessions end on restart."
    SECRET_KEY_BASE="$(head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi
export SECRET_KEY_BASE
unset REDMINE_SECRET_KEY_BASE

mkdir -p "${REDMINE_FILES_DIR:-/mnt/files}"

# A container restarted with the same file system.
rm -f "${APP_ROOT}/tmp/pids/server.pid"

exec "${@}"
