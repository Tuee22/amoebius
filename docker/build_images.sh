#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Variables - replace these with your own Docker Hub username and image name
DOCKER_USERNAME="tuee22"
DOCKER_IMAGE="amoebius"
IMAGE_TAG="0.0.1"

# Login to Docker Hub (ensure you have Docker credentials set up)
echo "Logging into Docker Hub..."
docker login || { echo "Docker login failed"; exit 1; }

# Create and use a new Buildx builder instance if it doesn't exist
BUILDER_INSTANCE="multiarch_builder"
if ! docker buildx inspect "$BUILDER_INSTANCE" > /dev/null 2>&1; then
    echo "Creating new Buildx builder instance..."
    docker buildx create --use --name "$BUILDER_INSTANCE" --driver docker-container
else
    echo "Using existing Buildx builder instance..."
    docker buildx use "$BUILDER_INSTANCE"
fi

# Ensure QEMU is registered (optional, but recommended)
echo "Setting up QEMU emulation..."
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Inspect and bootstrap the builder to ensure it's ready
docker buildx inspect --bootstrap

# Build and push the multi-arch image with multiple tags
echo "Building and pushing Docker image for multiple architectures..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "$DOCKER_USERNAME/$DOCKER_IMAGE:$IMAGE_TAG" \
  -t "$DOCKER_USERNAME/$DOCKER_IMAGE:latest" \
  -f ./Dockerfile \
  ../ \
  --push

# Optional: Remove the builder instance after the build
# echo "Removing Buildx builder instance..."
docker buildx rm "$BUILDER_INSTANCE"

echo "Done!"
