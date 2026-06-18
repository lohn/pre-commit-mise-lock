#!/bin/sh
# Run the bats suite under whatever bash the surrounding container provides, to
# guard the portability of mise-lock.sh across bash versions (notably 3.2, the
# version shipped with macOS). The script clones bats and its libraries and runs
# the suite with the container's bash, so the bash version is chosen entirely by
# the image it runs in.
#
# Meant to be executed inside a `bash:<version>` Docker image, e.g.
# `docker run --rm -v "$PWD:/code" -w /code bash:3.2 sh test/run-bats.sh`
# (see `mise run test` / `mise run test:bash32` and the CI matrix).
set -eu

# renovate: datasource=github-releases depName=bats-core/bats-core
BATS_CORE_VERSION="v1.13.0"
# renovate: datasource=github-releases depName=bats-core/bats-support
BATS_SUPPORT_VERSION="v0.3.0"
# renovate: datasource=github-releases depName=bats-core/bats-assert
BATS_ASSERT_VERSION="v2.2.4"

apk add --no-cache git >/dev/null

# Shallow-clone a tag quietly. `-c advice.detachedHead=false` silences the
# detached-HEAD advice, and stderr is dropped to hide the harmless
# "refs/tags/... is not a commit!" warning git emits for `--depth 1 -b <tag>`;
# real failures are still surfaced explicitly.
clone() {
  if ! git -c advice.detachedHead=false clone -q --depth 1 -b "$2" "$1" "$3" 2>/dev/null; then
    echo "Failed to clone $1 @ $2" >&2
    exit 1
  fi
}

clone https://github.com/bats-core/bats-core "$BATS_CORE_VERSION" /tmp/bats
clone https://github.com/bats-core/bats-support "$BATS_SUPPORT_VERSION" /tmp/lib/bats-support
clone https://github.com/bats-core/bats-assert "$BATS_ASSERT_VERSION" /tmp/lib/bats-assert

export BATS_LIB_PATH=/tmp/lib

bash --version | head -1
exec /tmp/bats/bin/bats "${1:-test}"
