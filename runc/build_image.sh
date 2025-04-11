#!/bin/bash


if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <Dockerfile>"
    exit 1
fi


DOCKERFILE="$1"
IMAGE_NAME="${DOCKERFILE#Dockerfile.}"    
BUILD_CONTEXT=".."


echo "[Configuration]"
echo "  - Dockerfile    : $DOCKERFILE"
echo "  - Image Name    : $IMAGE_NAME"
echo "  - Build Context : $(realpath "$BUILD_CONTEXT")"


echo "Building the image ..."
sudo docker build -f "$DOCKERFILE" -t "$IMAGE_NAME":latest "$BUILD_CONTEXT"

echo "Stopping and removing containers with same image ..."
sudo docker ps -a --filter "name=^${IMAGE_NAME}" --format "{{.Names}}" \
  | xargs -r -I{} sh -c 'sudo docker stop {} >/dev/null; sudo docker rm {} >/dev/null'

echo "Cleaning up dangling images ..."
sudo docker image prune -f

echo "Build completed successfully."
sudo docker images | grep "$IMAGE_NAME"

echo "Pushing to Docker Hub ..."
sudo docker tag "$IMAGE_NAME" choiyhking/"${IMAGE_NAME}":latest
sudo docker push choiyhking/"${IMAGE_NAME}":latest
