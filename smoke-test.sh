#!/bin/bash
set -e

URL=$1

echo "Smoke testing $URL"

for i in {1..10}; do
  if curl -sf "$URL/health"; then
    echo "Smoke test passed"
    exit 0
  fi
  echo "Waiting for app..."
  sleep 10
done

echo "Smoke test failed"
exit 1
