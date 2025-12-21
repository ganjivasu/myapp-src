#!/bin/bash
set -e

ENV=$1

if [ -z "$IMMUTABLE_IMAGE" ]; then
  echo "ERROR: IMMUTABLE_IMAGE is empty"
  exit 1
fi

cd gitops

git config user.name "ci-bot"
git config user.email "ci-bot@example.com"

git checkout main
git pull origin main

FILE="myapp/$ENV/deployment.yaml"

sed -i "s|image:.*|image: $IMMUTABLE_IMAGE|" $FILE

git add $FILE
git commit -m "Promote $IMMUTABLE_IMAGE to $ENV" || echo "No changes"
git push origin main
