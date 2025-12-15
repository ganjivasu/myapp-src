#!/bin/bash
# promotion.sh
# Usage: ./promotion.sh <target_env>
# Example: ./promotion.sh qa

set -e

TARGET_ENV=$1  # pt or qa or prod

# Map environment to paths
declare -A ENV_PATHS
ENV_PATHS=( ["dev"]="myapp/dev/deployment.yaml" ["pt"]="myapp/pt/deployment.yaml" ["qa"]="myapp/qa/deployment.yaml" ["prod"]="myapp/prod/deployment.yaml" )

SOURCE_PATH=${ENV_PATHS["dev"]}
TARGET_PATH=${ENV_PATHS[$TARGET_ENV]}

cd gitops
git checkout -b promote-to-$TARGET_ENV

# Copy Dev manifest to target env
cp $SOURCE_PATH $TARGET_PATH

# Update namespace dynamically
sed -i "s|namespace: dev|namespace: $TARGET_ENV|" $TARGET_PATH

# Update image with immutable digest
sed -i "s|image: .*|image: $IMMUTABLE_IMAGE|" $TARGET_PATH

git add $TARGET_PATH
git commit -m "Promote immutable image $GITHUB_SHA to $TARGET_ENV"
git push origin promote-to-$TARGET_ENV

# Create PR
gh pr create --title "Promote to $TARGET_ENV: $GITHUB_SHA" \
             --body "GitOps promotion using immutable image $IMMUTABLE_IMAGE" \
             --base main --head promote-to-$TARGET_ENV
