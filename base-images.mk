# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := redmine
BASE_IMAGE_VERSION_SUFFIX := -trixie

BASE_IMAGE_DIGEST_6.1.6-trixie := sha256:8beffc2ae1d39d418ccd12e0c05587716ce4eb03d38a269a52dbbe5c366534fd
BASE_IMAGE_DIGEST_7.0.3-trixie := sha256:c3c9da0407e99b2a47af9e0af7b06bce1a3cfec16def1c14cd1fae61e3fa0770

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
