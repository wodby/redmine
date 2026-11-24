# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := redmine
BASE_IMAGE_VERSION_SUFFIX := -trixie

BASE_IMAGE_DIGEST_6.1.6-trixie := sha256:e657ac320781815dd910ae1a33025a7d37f84eef88dbb4e082c4bd7e9050f27f
BASE_IMAGE_DIGEST_7.0.3-trixie := sha256:ba4c0380f17a3cf0d935279c7e60d6c017501330c1bb63217a8e89a3f93ccd8b

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
