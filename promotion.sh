#!/bin/bash
set -e

ENV=$1

cd gitops

git checkout main
git pull origin main

FILE="myapp/$ENV/deployment.yaml"

sed -i "s|image: .*|image: $IMMUTABLE_IMAGE|" $FILE

git add $FILE
git commit -m "Promote $IMMUTABLE_IMAGE to $ENV" || echo "No changes"
git push origin main
