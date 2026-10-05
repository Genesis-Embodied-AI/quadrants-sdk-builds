#!/usr/bin/env bash
set -euxo pipefail
(
    cd dist
    for arch in x86_64 aarch64; do
        source ../scripts/glslang/pins.sh "$arch"
        test -s "$PACKAGE.validation.txt"
        grep -F "PASS: $PACKAGE in $TARGET_IMAGE" "$PACKAGE.validation.txt"
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
- C++ runtime libraries are static; glibc remains dynamic. Build tools come from the selected container image.
- Both extracted archives passed the exact --no-link -Od Vulkan 1.0 helper compilation in fresh target containers.
- Validation also checks SPIR-V 1.0, exported helper, WorkgroupId, ELF dependencies and the glibc ceiling.
- Per-archive SHA-256 files, SHA256SUMS, and full validation logs are attached.
- Validation logs record the container image digests actually used; images are selected by tag.
- BUILD-INFO.txt in each archive records the exact source commit built.

This workflow never replaces releases or assets. Uploads finish in draft state before publication,
so repository release immutability can freeze the complete asset set.

SHA-256:
\`\`\`
$(cat dist/SHA256SUMS)
\`\`\`
NOTES
bash scripts/publish-release.sh "glslang-${GLSLANG_VERSION}" tmp/release-notes.md dist
