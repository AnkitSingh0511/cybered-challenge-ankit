#!/usr/bin/env sh
# =============================================================================
# push_image.sh
# Pulls a Docker image from Docker Hub, tags it for a student's private ECR
# repository, pushes it, then cleans up all local Docker artifacts.
#
# All inputs received via environment variables from terraform_data local-exec.
# Required env vars:
#   AWS_REGION    — AWS region (e.g. ap-south-1)
#   ECR_REPO_URL  — Full ECR repository URL
#   SOURCE_IMAGE  — Docker Hub image name (e.g. kasmweb/desktop)
#   SOURCE_TAG    — Docker Hub image tag (e.g. latest)
#   STUDENT_ID    — Sanitized student ID (used as ECR image tag)
#
# NOTE: No working directory needed — all operations happen at Docker layer
# cache level. WORK_DIR will be reintroduced when image customization
# via Dockerfile is required in a future phase.
#
# Exit codes:
#   0 — Success
#   1 — Validation failure or any command failure (set -e)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CLEANUP — runs on EXIT regardless of success or failure via trap.
# Removes local Docker images pulled and tagged during this run.
# -----------------------------------------------------------------------------
cleanup() {
  echo "[push_image.sh] INFO: Running cleanup for student: ${STUDENT_ID}"

  if docker image inspect "${ECR_REPO_URL}:${STUDENT_ID}" > /dev/null 2>&1; then
    docker rmi "${ECR_REPO_URL}:${STUDENT_ID}" || true
    echo "[push_image.sh] INFO: Removed local ECR-tagged image."
  fi

  if docker image inspect "${SOURCE_IMAGE}:${SOURCE_TAG}" > /dev/null 2>&1; then
    docker rmi "${SOURCE_IMAGE}:${SOURCE_TAG}" || true
    echo "[push_image.sh] INFO: Removed local source image."
  fi

  echo "[push_image.sh] INFO: Cleanup complete."
}

trap cleanup EXIT

# -----------------------------------------------------------------------------
# STEP 1 — Validate required environment variables
# -----------------------------------------------------------------------------
echo "[push_image.sh] INFO: Validating environment variables..."

REQUIRED_VARS=("AWS_REGION" "ECR_REPO_URL" "SOURCE_IMAGE" "SOURCE_TAG" "STUDENT_ID")

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "[push_image.sh] ERROR: Required environment variable '${var}' is not set or empty."
    exit 1
  fi
done

echo "[push_image.sh] INFO: All required environment variables present."

# -----------------------------------------------------------------------------
# STEP 2 — Validate required tooling
# -----------------------------------------------------------------------------
echo "[push_image.sh] INFO: Validating required tooling..."

for tool in docker aws; do
  if ! command -v "${tool}" > /dev/null 2>&1; then
    echo "[push_image.sh] ERROR: Required tool '${tool}' is not installed or not in PATH."
    exit 1
  fi
done

# Validate Docker daemon is running
if ! docker info > /dev/null 2>&1; then
  echo "[push_image.sh] ERROR: Docker daemon is not running. Start Docker Desktop and retry."
  exit 1
fi

echo "[push_image.sh] INFO: All required tools available."

# -----------------------------------------------------------------------------
# STEP 3 — Authenticate Docker to ECR
# -----------------------------------------------------------------------------
echo "[push_image.sh] INFO: Authenticating Docker to ECR..."

ECR_REGISTRY=$(echo "${ECR_REPO_URL}" | cut -d'/' -f1)

aws ecr get-login-password \
  --region "${AWS_REGION}" | \
  docker login \
    --username AWS \
    --password-stdin \
    "${ECR_REGISTRY}"

echo "[push_image.sh] INFO: Docker authenticated to ECR registry: ${ECR_REGISTRY}"

# -----------------------------------------------------------------------------
# STEP 4 — Pull source image from Docker Hub
# -----------------------------------------------------------------------------
echo "[push_image.sh] INFO: Pulling source image: ${SOURCE_IMAGE}:${SOURCE_TAG}"
docker pull "${SOURCE_IMAGE}:${SOURCE_TAG}"
echo "[push_image.sh] INFO: Pull complete."

# -----------------------------------------------------------------------------
# STEP 5 — Tag image for student's ECR repository
# Image tag = student ID for unambiguous tenant identification in ECR.
# -----------------------------------------------------------------------------
echo "[push_image.sh] INFO: Tagging image as ${ECR_REPO_URL}:${STUDENT_ID}"
docker tag "${SOURCE_IMAGE}:${SOURCE_TAG}" "${ECR_REPO_URL}:${STUDENT_ID}"
echo "[push_image.sh] INFO: Tag complete."

# -----------------------------------------------------------------------------
# STEP 6 — Push image to ECR
# -----------------------------------------------------------------------------
echo "[push_image.sh] INFO: Pushing image to ECR: ${ECR_REPO_URL}:${STUDENT_ID}"
docker push "${ECR_REPO_URL}:${STUDENT_ID}"
echo "[push_image.sh] INFO: Push complete."

# -----------------------------------------------------------------------------
# STEP 7 — Verify image exists in ECR
# -----------------------------------------------------------------------------
echo "[push_image.sh] INFO: Verifying image in ECR..."

ECR_REPO_NAME=$(echo "${ECR_REPO_URL}" | cut -d'/' -f2)

IMAGE_DIGEST=$(aws ecr describe-images \
  --repository-name "${ECR_REPO_NAME}" \
  --region "${AWS_REGION}" \
  --image-ids imageTag="${STUDENT_ID}" \
  --query "imageDetails[0].imageDigest" \
  --output text 2>/dev/null || echo "")

if [ -z "${IMAGE_DIGEST}" ] || [ "${IMAGE_DIGEST}" = "None" ]; then
  echo "[push_image.sh] ERROR: Image verification failed. Image not found in ECR after push."
  exit 1
fi

echo "[push_image.sh] INFO: Image verified in ECR. Digest: ${IMAGE_DIGEST}"
echo "[push_image.sh] INFO: Successfully pushed ${ECR_REPO_URL}:${STUDENT_ID}"

# trap cleanup EXIT fires here automatically