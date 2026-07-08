#!/usr/bin/env bash
set -e
IMAGE="${1:-your-dockerhub-user/server-info:1.0.0}"

docker build -t "$IMAGE" .
echo "Собран образ: $IMAGE"
echo "Локальный тест: docker run --rm -p 8080:80 $IMAGE  # затем http://localhost:8080"
echo "Публикация:    docker push $IMAGE"
