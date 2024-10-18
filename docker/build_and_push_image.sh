#!/bin/bash

# Set your Docker Hub username and image name
DOCKER_HUB_USERNAME="tuee22"
IMAGE_NAME="amoebius"
VERSION="0.0.1"  # Set your version

# Login to Docker Hub
echo "Logging in to Docker Hub..."
docker login

# Create a new builder instance
echo "Creating a new builder instance..."
docker buildx create --name amoebiusbuilder --use

# Inspect the builder to ensure it's ready
echo "Inspecting the builder..."
docker buildx inspect --bootstrap

# Build and push multi-arch image
echo "Building and pushing multi-arch image..."
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${VERSION} \
  -t ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:latest \
  --push \
  -f ./amoebius/Dockerfile \
  ..

# Remove the builder instance
echo "Removing the builder instance..."
docker buildx rm amoebiusbuilder