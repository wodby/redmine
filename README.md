# Redmine Docker Container Image

[![Build Status](https://github.com/wodby/redmine/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/redmine/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/redmine.svg)](https://hub.docker.com/r/wodby/redmine)

[Redmine](https://www.redmine.org), based on the [official image](https://hub.docker.com/_/redmine), with its
configuration taken from environment variables, precompiled assets, Puma, a command that installs Redmine into an empty
database or upgrades an installed one, and a regular `wodby` user (uid 1000).

## Docker Images

❗For better reliability we release images with stability tags (`wodby/redmine:7.0-rN`) which correspond to
[git tags](https://github.com/wodby/redmine/releases). We strongly recommend using images only with stability tags.

- Base image: [redmine](https://hub.docker.com/_/redmine) (Debian), pinned by digest
- [GitHub actions builds](https://github.com/wodby/redmine/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/redmine)

Supported tags:

| Tag             | Redmine |
|-----------------|---------|
| `7.0`, `latest` | 7.0.x   |
| `6.1`           | 6.1.x   |

All images are built for `linux/amd64` and `linux/arm64`.

## Installing and upgrading

`redmine-update` runs Redmine's database migrations and the plugins' migrations, then:

- Loads Redmine's default configuration (trackers, statuses, roles, workflows) in `REDMINE_LANG` once, into an empty
  database.
- Sets up the first administrator from `REDMINE_ADMIN_LOGIN`, `REDMINE_ADMIN_PASSWORD` and `REDMINE_ADMIN_EMAIL`: it
  replaces Redmine's stock `admin` account while that account still has the password `admin`, or creates one when the
  database has no administrator. Without a password, or with one Redmine refuses, the stock account is locked and the
  command fails. An administrator changed in Redmine is never touched again.
- Sets Redmine's host name and protocol from `REDMINE_HOST_URL` (or `WODBY_PRIMARY_URL`) and the email sender from
  `REDMINE_MAIL_FROM`, unless they were already set in Redmine's settings.

The migrations and the setup run in one process, so a new database never keeps the stock `admin`/`admin` account for
more than a moment. Containers start before the first installation: run the command once they are up, and after every
image upgrade.

## Plugins and themes

Build your own image `FROM wodby/redmine:<version>` and copy plugins to `/usr/src/redmine/plugins` and themes to
`/usr/src/redmine/themes`. Plugins with their own gems need `bundle install` in your build; the image has no compilers,
so install `build-essential` and the libraries the gems need first. `redmine-update` runs the plugins' migrations.

## Environment Variables

| Variable                          | Default      | Description                                                                 |
|-----------------------------------|--------------|-----------------------------------------------------------------------------|
| `DB_ADAPTER`                      | `postgresql` | `postgresql` or `mysql2`                                                    |
| `DB_HOST`                         | `postgres`   |                                                                             |
| `DB_PORT`                         | `5432`       | `3306` for `mysql2`                                                         |
| `DB_NAME`                         | `redmine`    |                                                                             |
| `DB_USER`                         | `redmine`    |                                                                             |
| `DB_PASSWORD`                     |              |                                                                             |
| `DB_SSL_CA`                       |              | CA certificate file of the database server: connect over verified TLS       |
| `DB_SSL_MODE`                     | `prefer`     | `verify-full` when `DB_SSL_CA` is set (`verify_identity` for `mysql2`)      |
| `DB_POOL`                         | threads + 2  | Database connections per process                                            |
| `SECRET_KEY_BASE`                 | random       | Signs sessions and cookies. Without it, every restart signs everybody out   |
| `REDMINE_FILES_DIR`               | `/mnt/files` | Attachments. Every replica must share it                                    |
| `REDMINE_AUTOLOGIN_COOKIE_SECURE` | `false`      | `true` sends the "Stay logged in" cookie over HTTPS only                    |
| `REDMINE_AVATAR_SERVER_URL`       | Gravatar     |                                                                             |
| `SMTP_HOST`                       |              | Outgoing mail server. Without it Redmine sends no email                     |
| `SMTP_PORT`                       | `25`         |                                                                             |
| `SMTP_DOMAIN`                     |              | HELO domain                                                                 |
| `SMTP_STARTTLS`                   | `true`       | Use STARTTLS when the server offers it                                      |
| `SMTP_TLS`                        |              | `true` for implicit TLS (port 465)                                          |
| `SMTP_USERNAME`                   |              |                                                                             |
| `SMTP_PASSWORD`                   |              |                                                                             |
| `SMTP_AUTHENTICATION`             | `login`      | `plain`, `login` or `cram_md5`, with `SMTP_USERNAME`                        |
| `WEB_CONCURRENCY`                 | `0`          | Puma worker processes. `0` runs one process                                 |
| `RAILS_MAX_THREADS`               | `5`          | Puma threads per process                                                    |
| `PUMA_PERSISTENT_TIMEOUT`         | `75`         | Seconds an idle keep-alive connection stays open                            |
| `REDMINE_ADMIN_LOGIN`             | `admin`      | `redmine-update` only: the first administrator                              |
| `REDMINE_ADMIN_PASSWORD`          |              | `redmine-update` only: required while no administrator is set up            |
| `REDMINE_ADMIN_EMAIL`             |              | `redmine-update` only                                                       |
| `REDMINE_LANG`                    | `en`         | `redmine-update` only: language of the default configuration and the administrator |
| `REDMINE_HOST_URL`                |              | `redmine-update` only: Redmine's host name and protocol, such as `https://redmine.example.com` |
| `WODBY_PRIMARY_URL`               |              | `redmine-update` only: used when `REDMINE_HOST_URL` is empty                |
| `REDMINE_MAIL_FROM`               |              | `redmine-update` only: the email sender                                     |

`config/database.yml` and `config/configuration.yml` read these variables when Redmine starts. Replace the files in
your own image to configure anything else.

## Ports

| Port | Used for                                                                    |
|------|-----------------------------------------------------------------------------|
| 3000 | Redmine. `/-/health` answers without the database                           |

## Orchestration Actions

```bash
docker exec CONTAINER redmine-update   # install or upgrade
```
