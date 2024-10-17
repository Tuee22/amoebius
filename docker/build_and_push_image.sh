#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Set your Docker Hub username and image name
DOCKER_HUB_USERNAME="tuee22"
IMAGE_NAME="amoebius"
VERSION="0.0.1"  # Set your version
CLEANUP=false  # Set to true if you want to force a cleanup

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --cleanup) CLEANUP=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Login to Docker Hub
echo "Logging in to Docker Hub..."
docker login

# Function to check if a manifest exists
manifest_exists() {
    local tag=$1
    docker manifest inspect ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${tag} > /dev/null 2>&1
}

# Function to cleanup existing tags and manifests
cleanup_existing_tags() {
    local tag=$1
    echo "Cleaning up existing tag: $tag"
    docker manifest rm ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${tag} || true
    docker rmi ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${tag} || true
}

# Function to build and push for a specific architecture
build_and_push() {
    local arch=$1
    local platform=$2
    
    echo "Building for $arch..."
    docker build -t ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${VERSION}-${arch} -f ./amoebius/Dockerfile ../
    
    echo "Pushing ${arch} image..."
    docker push ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${VERSION}-${arch}
}

# Function to create or update and push manifest
create_or_update_and_push_manifest() {
    local tag=$1
    local arch=$2
    local platform=$3

    if manifest_exists $tag; then
        echo "Updating existing manifest for $tag..."
        docker manifest create --amend ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${tag} \
            ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${VERSION}-${arch}
    else
        echo "Creating new manifest for $tag..."
        docker manifest create ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${tag} \
            ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${VERSION}-${arch}
    fi

    docker manifest annotate ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${tag} \
        ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${VERSION}-${arch} --os linux --arch ${platform}

    echo "Pushing manifest for $tag..."
    docker manifest push ${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${tag}
}

# Cleanup existing tags if CLEANUP is true
if [ "$CLEANUP" = true ]; then
    cleanup_existing_tags ${VERSION}
    cleanup_existing_tags "latest"
fi

# Detect current architecture
current_arch=$(uname -m)

if [ "$current_arch" = "x86_64" ]; then
    arch="amd64"
    platform="amd64"
elif [ "$current_arch" = "aarch64" ]; then
    arch="arm64"
    platform="arm64"
else
    echo "Unsupported architecture: $current_arch"
    exit 1
fi

build_and_push $arch $platform

# Create or update and push manifests
create_or_update_and_push_manifest ${VERSION} $arch $platform
create_or_update_and_push_manifest "latest" $arch $platform

echo "Multi-arch image built and pushed successfully!"