#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"
IMAGE="${2:-}"

if [[ -z "$ENV" ]]; then
  echo "Usage: promotion.sh <env> [image]"
  exit 1
fi

# Use argument image if provided
if [[ -z "$IMAGE" ]]; then
  # Fallback for backward compatibility
  if [[ ! -f immutable_image.txt ]]; then
    echo "❌ immutable_image.txt not found and no image provided"
    exit 1
  fi
  IMAGE=$(cat immutable_image.txt)
fi

# Split image into name + digest
NAME=$(echo "$IMAGE" | cut -d@ -f1)
DIGEST=$(echo "$IMAGE" | cut -d@ -f2)

OVERLAY_DIR="gitops/myapp/overlays/$ENV"

if [[ ! -d "$OVERLAY_DIR" ]]; then
  echo "❌ Overlay directory not found: $OVERLAY_DIR"
  exit 1
fi

cd "$OVERLAY_DIR"

git config user.name "ci-bot"
git config user.email "ci-bot@example.com"

# Update kustomization.yaml using yq
yq -i "
.images[0].newName = \"$NAME\" |
.images[0].digest  = \"$DIGEST\"
" kustomization.yaml

# Commit only if changes exist
git diff --quiet && {
  echo "ℹ️ No changes to commit for $ENV"
  exit 0
}

git add kustomization.yaml
git commit -m "Promote $IMAGE to $ENV"
git push origin main
