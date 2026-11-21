#!/usr/bin/env bash

# Version aliases identify published releases; only primary tags publish images.
if [[ "${GITHUB_REF:-}" =~ ^refs/tags/.+-r[0-9]+$ ]]; then
    exit 0
fi

set -exo pipefail

if [[ "${GITHUB_REF}" == refs/heads/main || "${GITHUB_REF}" == refs/tags/* ]]; then
  # REDMINE_VER is a Redmine release, such as 7.0.3. Images are published per
  # release line (7.0), because a new line brings database migrations and
  # plugins are written for a line.
  minor_ver="${REDMINE_VER%.*}"

  tags=("${minor_ver}")

  if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    image_revision="${GITHUB_REF##*/}"
    tags=("${minor_ver}-${image_revision}")
  elif [[ -n "${LATEST}" ]]; then
    tags+=("latest")
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create IMAGETOOLS_TAG=${tag}
  done
fi
