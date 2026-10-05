#!/usr/bin/env bash
set -euxo pipefail
source scripts/glslang/pins.sh x86_64
date_suffix=$(date -u +%Y%m%d%H%M)
if [[ "$GITHUB_EVENT_NAME" == workflow_dispatch ]]; then
    tag="glslang-${GLSLANG_VERSION}-${date_suffix}"
else
    branch=$(printf '%s' "$GITHUB_HEAD_REF" | tr '/' '-' | tr -cd '[:alnum:]-')
    tag="glslang-${GLSLANG_VERSION}-${branch}-${date_suffix}"
fi
prerelease=true
if [[ "$GITHUB_REF_NAME" == main ]]; then
    prerelease=false
fi
# Never update an existing release. A failed draft must be inspected instead of silently overwritten.
if gh release view "$tag" >/dev/null 2>&1; then
    echo "Release $tag already exists; use a new tag." >&2
    exit 1
fi
(
    cd dist
    for arch in x86_64 aarch64; do
        source ../scripts/glslang/pins.sh "$arch"
        test -s "$PACKAGE.validation.txt"
        grep -F "PASS: $PACKAGE in $BUILD_IMAGE" "$PACKAGE.validation.txt"
        sha256sum -c "$PACKAGE.tar.xz.sha256"
    done
    cat ./*.tar.xz.sha256 | LC_ALL=C sort -k2 > SHA256SUMS
)
mkdir -p tmp
cat > tmp/release-notes.md <<NOTES
glslang ${GLSLANG_VERSION} GLSL compilers for Quadrants' manylinux CI.

- Source: https://github.com/KhronosGroup/glslang/tree/${GLSLANG_VERSION}
- Build recipe: https://github.com/${GITHUB_REPOSITORY}/tree/${GITHUB_SHA}/scripts/glslang
- Build and validation run: https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
- Each archive contains bin/glslang, bin/glslangValidator (symlink), licenses/, and BUILD-INFO.txt
  under its glslang-${GLSLANG_VERSION}-manylinux_* directory.
- GLSL/SPIR-V enabled; optional HLSL and SPIRV-Tools optimizer disabled. No external source dependencies.
- C++ runtime libraries are static; glibc remains dynamic. All build tools are pinned by container digest.
- Both extracted archives passed the exact --no-link -Od Vulkan 1.0 helper compilation in fresh target containers.
- Validation also checks SPIR-V 1.0, exported helper, WorkgroupId, ELF dependencies and the glibc ceiling.
- Per-archive SHA-256 files, SHA256SUMS, and full validation logs are attached.
- BUILD-INFO.txt in each archive records the exact source commit built.

This workflow never replaces releases or assets. Uploads finish in draft state before publication,
so repository release immutability can freeze the complete asset set.

SHA-256:
\`\`\`
$(cat dist/SHA256SUMS)
\`\`\`
NOTES
# Create the release tag automatically at the exact build recipe commit.
gh release create "$tag" --target "$GITHUB_SHA" --draft --prerelease="$prerelease" \
    --title "$tag" --notes-file tmp/release-notes.md
gh release upload "$tag" dist/*
# Do not mark this dependency release as the repository's latest LLVM/SDK release.
gh release edit "$tag" --draft=false --latest=false
# Checking the release needs only contents access; reading the repository setting needs an admin token.
test "$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$tag" --jq .immutable)" = true
gh release view "$tag" --json url,assets > tmp/published-release.json
cat tmp/published-release.json
