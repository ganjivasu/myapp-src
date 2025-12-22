#!/bin/bash
set -euo pipefail

ENV="$1"

if [[ -z "${ENV:-}" ]]; then
  echo "ERROR: Environment not provided (dev|pt|qa|prod)"
  exit 1
fi

if [[ -z "${IMMUTABLE_IMAGE:-}" ]]; then
  echo "ERROR: IMMUTABLE_IMAGE is empty"
  exit 1
fi

echo "========================================="
echo "Promoting image to environment: $ENV"
echo "Image: $IMMUTABLE_IMAGE"
echo "========================================="

# Move into GitOps repo
cd gitops

# Git config (required in CI)
git config user.name "ci-bot"
git config user.email "ci-bot@example.com"

git checkout main
git pull origin main

# Path to environment manifest
FILE="myapp/${ENV}/deployment.yaml"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: Deployment file not found: $FILE"
  exit 1
fi

echo "Updating image in $FILE"

# Replace image line (works for Rollout & Deployment)
sed -i "s|^\([[:space:]]*image:\).*|\1 ${IMMUTABLE_IMAGE}|" "$FILE"

echo "Verifying change:"
grep -n "image:" "$FILE"

# Commit & push only if changed
git add "$FILE"

if git diff --cached --quiet; then
  echo "No changes detected, skipping commit"
  exit 0
fi

git commit -m "Promote ${IMMUTABLE_IMAGE} to ${ENV}"
git push origin main

echo "Promotion to $ENV completed successfully"
