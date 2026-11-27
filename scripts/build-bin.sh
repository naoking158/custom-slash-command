#!/usr/bin/env bash
# build-bin.sh — Build bin/my-toolkit-<os>-<arch> from cmd/my-toolkit for every
# platform the hooks run on. The build is reproducible (no build ID, no VCS
# stamp, paths trimmed, no cgo), so CI rebuilds and compares the committed
# binaries.
#
#   scripts/build-bin.sh
#
# Exit status: 0 built, non-zero when go failed.
# Dependencies: go (the version in mise.toml).
set -eu
cd "$(dirname "$0")/.."
for target in darwin/arm64 darwin/amd64 linux/arm64 linux/amd64; do
  CGO_ENABLED=0 GOOS="${target%/*}" GOARCH="${target#*/}" \
    go build -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -o "bin/my-toolkit-${target%/*}-${target#*/}" ./cmd/my-toolkit
done
