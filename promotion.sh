#!/usr/bin/env bash
set -euo pipefail

ENV=$1
GITOPS_DIR="$(pwd)/gitops"

if [[ ! "$ENV" =~ ^(dev|pt|qa|prod)$ ]]; then
  echo "ERROR: Invalid environment $ENV"
  exit 1
fi

if [[ ! -f immutable_image.txt ]]; then
  echo "ERROR: immutable_image.txt not found"
  exit 1
fi

IMAGE=$(cat immutable_image.txt)

if [[ -z "$IMAGE" ]]; then
  echo "ERROR: Image is empty"
  exit 1
fi

echo "========================================="
echo "Promoting image to environment: $ENV"
echo "Image: $IMAGE"
echo "========================================="

cd "$GITOPS_DIR"

git config user.name "ci-bot"
git config user.email "ci-bot@example.com"

git checkout main
git pull origin main

DEPLOY_FILE="myapp/$ENV/deployment.yaml"

sed -i.bak -E "s|image: .*|image: $IMAGE|" "$DEPLOY_FILE"
rm -f "$DEPLOY_FILE.bak"

git add "$DEPLOY_FILE"
git commit -m "Promote $IMAGE to $ENV"
git push origin main
