#!/usr/bin/env bash
set -euo pipefail

ENV=$1
IMAGE=$(cat immutable_image.txt)

if [[ -z "$ENV" || -z "$IMAGE" ]]; then
  echo "Usage: promotion.sh <env>"
  exit 1
fi

NAME=$(echo "$IMAGE" | cut -d@ -f1)
DIGEST=$(echo "$IMAGE" | cut -d@ -f2)

cd gitops/myapp/overlays/$ENV

git config user.name "ci-bot"
git config user.email "ci-bot@example.com"

yq -i "
.images[0].newName = \"$NAME\" |
.images[0].digest  = \"$DIGEST\"
" kustomization.yaml

kubectl kustomize . > /tmp/rendered.yaml
kubectl apply --dry-run=client --validate=true -f /tmp/rendered.yaml

git add kustomization.yaml
git commit -m "Promote $IMAGE to $ENV"
git push origin main
