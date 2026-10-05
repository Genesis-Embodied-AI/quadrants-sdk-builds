#!/usr/bin/env bash
# Run in the digest-pinned target container, with the repository mounted at /work.
set -euxo pipefail
cd /work
source scripts/glslang/pins.sh "$(uname -m)"
export LC_ALL=C TZ=UTC
umask 022
work=/work/tmp/glslang
mkdir -p "$work" /work/dist
src="$work/source"
git init "$src"
git -C "$src" remote add origin https://github.com/KhronosGroup/glslang.git
git -C "$src" fetch --depth 1 origin "$GLSLANG_REVISION"
git -C "$src" checkout --detach FETCH_HEAD
test "$(git -C "$src" rev-parse HEAD)" = "$GLSLANG_REVISION"
test "$(git -C "$src" show -s --format=%ct)" = "$SOURCE_DATE_EPOCH"

# GLSL-only, with no optimizer: the --no-link -Od helper compilation needs no external source dependencies.
# Static C++ runtimes avoid dependencies on the manylinux build toolchain at execution time.
cmake_args=(
    -S "$src" -B "$work/build" -G 'Unix Makefiles'
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
    -DPython3_EXECUTABLE=/opt/python/cp310-cp310/bin/python3
    -DCMAKE_CXX_FLAGS="-ffile-prefix-map=$work=/usr/src/glslang -fdebug-prefix-map=$work=/usr/src/glslang"
    -DCMAKE_EXE_LINKER_FLAGS='-static-libstdc++ -static-libgcc -Wl,--build-id=sha1'
    -DGLSLANG_TESTS=OFF -DGLSLANG_ENABLE_INSTALL=OFF
    -DBUILD_EXTERNAL=OFF -DALLOW_EXTERNAL_SPIRV_TOOLS=OFF
    -DENABLE_OPT=OFF -DENABLE_HLSL=OFF -DENABLE_PCH=OFF
    -DENABLE_SPIRV=ON -DENABLE_GLSLANG_BINARIES=ON -DENABLE_SPVREMAPPER=OFF
)
cmake "${cmake_args[@]}"
cmake --build "$work/build" --target glslang-standalone --parallel "${BUILD_JOBS:-4}"

stage="$work/package/$PACKAGE"
mkdir -p "$stage/bin" "$stage/licenses"
install -m 755 "$work/build/StandAlone/glslang" "$stage/bin/glslang"
strip --strip-unneeded "$stage/bin/glslang"
ln -s glslang "$stage/bin/glslangValidator"
cp "$src/LICENSE.txt" "$stage/licenses/glslang-LICENSE.txt"
cp scripts/glslang/licenses/* "$stage/licenses/"
# Include all source copyright headers together with upstream's aggregate license.
git -C "$src" grep -h -E 'Copyright|copyright' -- '*.cpp' '*.h' '*.y' '*.l' \
    | LC_ALL=C sort -u > "$stage/licenses/glslang-COPYRIGHT-NOTICES.txt"
{
    echo "glslang_version=$GLSLANG_VERSION"
    echo "glslang_revision=$GLSLANG_REVISION"
    echo 'source_url=https://github.com/KhronosGroup/glslang'
    echo "sdk_builds_revision=${SDK_BUILDS_REVISION:?}"
    echo "target_image=$TARGET_IMAGE"
    echo "build_image=$BUILD_IMAGE"
    echo "source_date_epoch=$SOURCE_DATE_EPOCH"
    echo 'executable=bin/glslang; compatibility_symlink=bin/glslangValidator'
    echo 'features=GLSL,SPIR-V,no-link; disabled=HLSL,SPIRV-Tools optimizer'
    echo 'runtime=static libstdc++ and libgcc; dynamic glibc'
    echo 'external_source_dependencies=none'
    printf 'cmake_command=cmake'; printf ' %q' "${cmake_args[@]}"; printf '\n'
    gcc --version
    cmake --version
    make --version
    strip --version
    /opt/python/cp310-cp310/bin/python3 --version
    "$stage/bin/glslang" --version
    echo 'Container RPM versions:'
    rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | LC_ALL=C sort
} > "$stage/BUILD-INFO.txt"

# Stable ordering, ownership, permissions and timestamps; single-threaded xz is deterministic.
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner \
    -C "$work/package" -cf - "$PACKAGE" | xz -T1 -9 > "/work/dist/$PACKAGE.tar.xz"
(cd /work/dist && sha256sum "$PACKAGE.tar.xz" > "$PACKAGE.tar.xz.sha256")
