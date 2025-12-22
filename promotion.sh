#!/bin/bash
set -e

ENV="$1"
IMAGE="$2"

if [[ -z "$IMAGE" ]]; then
  echo "ERROR: Image argument is empty"
  exit 1
fi

echo "========================================="
echo "Promoting image to environment: $ENV"
echo "Image: $IMAGE"
echo "========================================="

cd gitops

git config user.name "ci-bot"
git config user.email "ci-bot@example.com"

git checkout main
git pull origin main

FILE="myapp/$ENV/deployment.yaml"

sed -i "s|image: .*|image: $IMAGE|" "$FILE"

grep "image:" "$FILE"

git add "$FILE"
git commit -m "Promote $IMAGE to $ENV" || echo "No changes"
git push origin main
