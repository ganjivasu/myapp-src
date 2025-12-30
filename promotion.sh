#!/usr/bin/env bash
set -euo pipefail

ENV=$1
IMAGE=$(cat immutable_image.txt)

if [[ -z "$ENV" || -z "$IMAGE" ]]; then
  echo "Usage: promotion.sh <env>"
  exit 1
fi

NAME=$(echo "$IMAGE" | cut -d@ -f1)
DIGEST=$(echo "$IMAGE" | cut -d@ -f2 | sed 's/sha256:/sha256-/')

cd gitops/myapp/overlays/$ENV

yq -i "
.images[0].newName = \"$NAME\" |
.images[0].newTag  = \"$DIGEST\"
" kustomization.yaml

git add kustomization.yaml
git commit -m "Promote $IMAGE to $ENV"
git push origin main
