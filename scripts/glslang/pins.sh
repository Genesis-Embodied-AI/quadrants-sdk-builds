# Source this file from Bash. Select the target image tag and package name.
[[ "${GLSLANG_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
if [[ "$(printf '%s\n' 13.1.0 "$GLSLANG_VERSION" | sort -V | head -1)" != 13.1.0 ]]; then
    echo 'glslang 13.1.0 or newer is required for --no-link.' >&2
    return 1
fi
case "${1:?Expected x86_64 or aarch64}" in
    x86_64)
        PLATFORM=manylinux_2_28_x86_64
        TARGET_IMAGE=quay.io/pypa/manylinux_2_28_x86_64:latest
        GLIBC_MAX=2.28
        ;;
    aarch64)
        PLATFORM=manylinux_2_34_aarch64
        TARGET_IMAGE=quay.io/pypa/manylinux_2_34_aarch64:2025.11.11-1
        GLIBC_MAX=2.34
        ;;
    *) echo 'Unsupported architecture' >&2; return 1 ;;
esac
PACKAGE="glslang-${GLSLANG_VERSION}-${PLATFORM}"
export GLSLANG_VERSION
