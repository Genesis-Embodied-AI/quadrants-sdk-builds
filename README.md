# quadrants-sdk-builds

For building SDKs needed by quadrants CI.

## glslang for manylinux

[Build glslang (manylinux)](.github/workflows/glslang-manylinux.yml) builds **15.4.0** at
`8a85691a0740d390761a1008b4696f57facd02c4` on native x86_64 and ARM64 runners. Builds and smoke tests run in
separate, fresh containers. [pins.sh](scripts/glslang/pins.sh) pins both images by digest, including the GCC,
CMake, Make, Python and binutils versions; no package installation or external source dependencies are needed.
The image tags whose digests were resolved are:

- x86_64: `quay.io/pypa/manylinux_2_28_x86_64:latest`
- ARM64: `quay.io/pypa/manylinux_2_34_aarch64:2025.11.11-1`

Each `glslang-15.4.0-manylinux_<baseline>_<arch>.tar.xz` contains a same-named root directory with `bin/glslang`,
`bin/glslangValidator` (a relative symlink), `licenses/`, and `BUILD-INFO.txt`. The latter records source and build
recipe revisions, the image digest, configuration, compiler version, and installed container RPM versions.
Only GLSL/SPIR-V compilation is enabled: optional HLSL and the SPIRV-Tools optimizer are disabled. The requested
`-V --target-env vulkan1.0 --no-link -Od` path is supported; `-Os` is intentionally unavailable. C++ runtime
libraries are linked statically, with their license notices included; glibc is dynamic.

### Build and publish

To publish, push a new `glslang-15.4.0-<unique-suffix>` tag at the recipe commit, or dispatch the workflow with
`publish: true` once it is on the default branch. Manual dispatch defaults to validation only. Pull requests do
not trigger builds, avoiding duplicate builds when updating a PR and pushing a release tag. Each publication
waits for both architectures and fails if its release already exists. Per-archive SHA-256 files, combined
`SHA256SUMS`, and validation logs accompany the archives.

Publication creates a draft, uploads all assets, then publishes without changing the repository's latest release.
Keep **Settings → General → Releases → Enable release immutability** enabled. The publisher verifies that GitHub
froze the release after publication and fails if it did not. This setting is enabled for this repository.
This repository setting affects future releases of all SDKs: other publishers must also upload their assets before
publishing. Already published releases are not retroactively frozen. No workflow uses `--clobber` or force-pushes.

### Reproduce on a native Linux host with Docker

Check out the release tag, then run from the repository root (requires Docker and the matching host architecture):

```bash
source scripts/glslang/pins.sh "$(uname -m)"
mkdir -p tmp dist
docker pull "$BUILD_IMAGE"
docker run --rm -v "$PWD:/work" -w /work -e SDK_BUILDS_REVISION="$(git rev-parse HEAD)" \
  "$BUILD_IMAGE" bash scripts/glslang/build.sh 2>&1 | tee tmp/build.log
docker run --rm -v "$PWD:/work" -w /work \
  "$BUILD_IMAGE" bash scripts/glslang/validate.sh 2>&1 | tee tmp/validation.log
(cd dist && sha256sum -c "$PACKAGE.tar.xz.sha256")
```

Use a clean checkout/work directory per build. Packaging normalizes file order, ownership, timestamps and xz
compression. Source and toolchain inputs are pinned; byte-for-byte reproducibility across independent hosts has
not been established. Validation uses the extracted archive with toolchain search paths removed, checks its ELF
runtime dependencies and glibc symbol ceiling, compiles [the requested shader](scripts/glslang/workgroup.comp),
checks the emitted SPIR-V library structure and export, and compiles an additional shader with a main entry point.
This is a compiler packaging smoke test, not a GPU execution test or full SPIR-V semantic validation.
