#!/usr/bin/env bash
# Run in a fresh target container. Deliberately remove the development toolchain's loader/search paths.
set -euxo pipefail
cd /work
source scripts/glslang/pins.sh "$(uname -m)"
export LC_ALL=C PATH=/usr/bin:/bin
unset LD_LIBRARY_PATH LD_PRELOAD LIBRARY_PATH
work=/work/tmp/validate
mkdir -p "$work"
(cd dist && sha256sum -c "$PACKAGE.tar.xz.sha256")
tar -xJf "dist/$PACKAGE.tar.xz" -C "$work"
exe="$work/$PACKAGE/bin/glslangValidator"
test -x "$exe"
test "$(readlink "$exe")" = glslang
"$exe" --version | tee "$work/version.txt"
grep -F '15.4.0' "$work/version.txt"
# glslang 15.4.0 exits with status 1 after printing help, even for an explicit --help request.
help_status=0
"$exe" --help > "$work/help.txt" || help_status=$?
test "$help_status" -le 1
grep -F -- '--no-link' "$work/help.txt"
file "$exe" "$work/$PACKAGE/bin/glslang"
readelf -h "$exe"
readelf -d "$exe" | tee "$work/dynamic.txt"
ldd "$exe" | tee "$work/ldd.txt"
if grep -F 'not found' "$work/ldd.txt"; then
    echo 'Unresolved runtime dependency' >&2
    exit 1
fi
if grep -E 'libstdc\+\+|libgcc_s|RPATH|RUNPATH' "$work/dynamic.txt"; then
    echo 'Unexpected dynamic C++ runtime or embedded search path' >&2
    exit 1
fi
# Check actual ELF symbol requirements, not just the container's installed libc version.
readelf --version-info "$exe" > "$work/symbols.txt"
required_glibc=$(grep -oE 'GLIBC_[0-9]+\.[0-9]+' "$work/symbols.txt" | sort -Vu | tail -1)
printf 'Maximum required glibc: %s; target ceiling: GLIBC_%s\n' "$required_glibc" "$GLIBC_MAX"
test "$(printf '%s\n' "${required_glibc#GLIBC_}" "$GLIBC_MAX" | sort -V | tail -1)" = "$GLIBC_MAX"
if grep -E 'GLIBCXX_|CXXABI_' "$work/symbols.txt"; then
    echo 'Unexpected C++ runtime symbol dependency' >&2
    exit 1
fi
cp scripts/glslang/workgroup.comp "$work/workgroup.comp"
cd "$work"
"$exe" -V --target-env vulkan1.0 --no-link -Od workgroup.comp -o workgroup.spv
/opt/python/cp310-cp310/bin/python3 /work/scripts/glslang/check-spirv.py workgroup.spv
# Also exercise conventional executable shader compilation.
printf '#version 450\nlayout(local_size_x = 1) in;\nvoid main() {}\n' > main.comp
"$exe" -V --target-env vulkan1.0 main.comp -o main.spv
test -s main.spv
sha256sum workgroup.spv main.spv
printf 'PASS: %s in %s\n' "$PACKAGE" "$BUILD_IMAGE"
