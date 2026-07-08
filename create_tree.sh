#!/usr/bin/env bash
# Creates the empty server-info project tree (folders + empty files only).
set -e

ROOT="server-info"

mkdir -p "$ROOT/app"
mkdir -p "$ROOT/base"
mkdir -p "$ROOT/overlays/dev"
mkdir -p "$ROOT/overlays/prod"
mkdir -p "$ROOT/argocd"

touch "$ROOT/Dockerfile"
touch "$ROOT/build.sh"
touch "$ROOT/README.md"

touch "$ROOT/app/index.html"
touch "$ROOT/app/default.conf.template"

touch "$ROOT/base/kustomization.yaml"
touch "$ROOT/base/deployment.yaml"
touch "$ROOT/base/ingress.yaml"

touch "$ROOT/overlays/dev/kustomization.yaml"
touch "$ROOT/overlays/prod/kustomization.yaml"

touch "$ROOT/argocd/app-dev.yaml"
touch "$ROOT/argocd/app-prod.yaml"

chmod +x "$ROOT/build.sh"

echo "Created empty tree:"
find "$ROOT" | sort
