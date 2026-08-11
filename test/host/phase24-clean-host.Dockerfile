FROM ubuntu:24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl docker.io g++ gcc git libffi-dev libgmp-dev libncurses-dev \
      libnuma-dev make pkg-config python3 strace xz-utils zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
