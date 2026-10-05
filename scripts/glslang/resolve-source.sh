#!/usr/bin/env bash
# Resolve a release tag once, before starting either architecture's build.
set -euo pipefail
version=${GLSLANG_VERSION:?Set GLSLANG_VERSION to the release version}
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'Expected a glslang release version such as 15.4.0.' >&2
    exit 1
fi
if [[ "$(printf '%s\n' 13.1.0 "$version" | sort -V | head -1)" != 13.1.0 ]]; then
    echo 'glslang 13.1.0 or newer is required for --no-link.' >&2
    exit 1
fi

mkdir -p "${RUNNER_TEMP:-tmp}"
work=$(mktemp -d "${RUNNER_TEMP:-tmp}/glslang-source.XXXXXX")
trap 'rm -rf "$work"' EXIT
git init -q "$work"
git -C "$work" fetch --depth 1 https://github.com/KhronosGroup/glslang.git "refs/tags/$version"
git -C "$work" checkout --detach -q FETCH_HEAD
GLSLANG_REVISION=$(git -C "$work" rev-parse HEAD)
export GLSLANG_REVISION
source scripts/glslang/pins.sh x86_64

printf 'glslang %s: %s\n' "$GLSLANG_VERSION" "$GLSLANG_REVISION"
{
    echo "version=$GLSLANG_VERSION"
    echo "revision=$GLSLANG_REVISION"
} >> "${GITHUB_OUTPUT:?Set GITHUB_OUTPUT to the output file}"
