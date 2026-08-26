# Pinned native-AArch64 builder for the generated Phase-25 monocontainer.
# The final image Dockerfile remains generated from BakeCatalog.dhall; this
# file produces its real arm64 BuildProduct input under binfmt/QEMU when the
# host is not arm64.
FROM haskell@sha256:6700d2932ef1e58acbb3fe3d0158e86455ee4549d2d0265b115265cad46d9ab1 AS toolchain

RUN apt-get update \
    && apt-get install --yes --no-install-recommends pkg-config zlib1g-dev libgmp-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

ADD --checksum=sha256:41d8fc43de1c652c00d85799d0273f8b6600bc71603126bc651ca4e3917a1b84 \
    https://downloads.haskell.org/cabal/cabal-install-3.16.1.0/cabal-install-3.16.1.0-aarch64-linux-deb12.tar.xz \
    /tmp/cabal-install.tar.xz
RUN mkdir -p /opt/cabal-3.16.1.0 \
    && tar --extract --xz --file /tmp/cabal-install.tar.xz --directory /opt/cabal-3.16.1.0 \
    && /opt/cabal-3.16.1.0/cabal --numeric-version \
    && test "$(ghc --numeric-version)" = "9.12.4" \
    && test "$(uname -m)" = "aarch64"

FROM toolchain AS build
WORKDIR /src
COPY . /src
RUN --mount=type=cache,id=amoebius-base-image-registry-arm64-cabal,target=/root/.cache/cabal \
    --mount=type=cache,id=amoebius-base-image-registry-arm64-store,target=/root/.local/state/cabal \
    --mount=type=cache,id=amoebius-base-image-registry-arm64-dist,target=/src/dist-newstyle \
    /opt/cabal-3.16.1.0/cabal update \
    && /opt/cabal-3.16.1.0/cabal build exe:amoebius -j4 --with-compiler=/opt/ghc/9.12.4/bin/ghc \
    && mkdir -p /out \
    && cp "$(/opt/cabal-3.16.1.0/cabal list-bin exe:amoebius --with-compiler=/opt/ghc/9.12.4/bin/ghc)" /out/amoebius-jit-build-resolver \
    && /out/amoebius-jit-build-resolver jit-build-resolver --version

FROM scratch AS export
COPY --from=build /out/amoebius-jit-build-resolver /amoebius-jit-build-resolver
