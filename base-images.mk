# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := redmine
BASE_IMAGE_VERSION_SUFFIX := -trixie

BASE_IMAGE_DIGEST_7.0.3-trixie := sha256:d73994dbe634fb8eef5add6ddaf70639285009156e8b0eb2a151a5eddb1e2cfb
BASE_IMAGE_DIGEST_6.1.6-trixie := sha256:5f5ceb01f68aa45e3bd66606af7a07ec1919b6ff47ad387815f29ee29e2ce1ab

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
