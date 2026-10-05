# Source this file from Bash. Toolchains and build utilities are pinned by the image digests.
[[ "${GLSLANG_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
[[ "${GLSLANG_REVISION:-}" =~ ^[0-9a-f]{40}$ ]] || return 1
case "${1:?Expected x86_64 or aarch64}" in
    x86_64)
        PLATFORM=manylinux_2_28_x86_64
        TARGET_IMAGE=quay.io/pypa/manylinux_2_28_x86_64:latest
        IMAGE_DIGEST=sha256:39df0042d5cc900b085aa25a0659368b42a0006c54c474299b785b44c1b4ff82
        GLIBC_MAX=2.28
        ;;
    aarch64)
        PLATFORM=manylinux_2_34_aarch64
        TARGET_IMAGE=quay.io/pypa/manylinux_2_34_aarch64:2025.11.11-1
        IMAGE_DIGEST=sha256:9d5213557f9111049d305a421731cef264a9370d723a3ba05282b87bfcbdc73e
        GLIBC_MAX=2.34
        ;;
    *) echo 'Unsupported architecture' >&2; return 1 ;;
esac
BUILD_IMAGE="${TARGET_IMAGE%@*}@${IMAGE_DIGEST}"
PACKAGE="glslang-${GLSLANG_VERSION}-${PLATFORM}"
export GLSLANG_VERSION GLSLANG_REVISION
