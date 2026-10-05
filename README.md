# quadrants-sdk-builds

For building SDKs needed by quadrants CI.

## glslang for manylinux

[Build glslang (manylinux)](.github/workflows/glslang-manylinux.yml) defaults to **15.4.0** at
`8a85691a0740d390761a1008b4696f57facd02c4` on native x86_64 and ARM64 runners. Builds and smoke tests run in
separate, fresh containers. [pins.sh](scripts/glslang/pins.sh) pins both images by digest, including the GCC,
CMake, Make, Python and binutils versions; no package installation or external source dependencies are needed.
Other requested release versions are resolved once to an exact source commit before either architecture starts.
Both builds receive that same commit and source timestamp. The default 15.4.0 revision remains fixed even if its
upstream tag moves. The image tags whose digests were resolved are:

- x86_64: `quay.io/pypa/manylinux_2_28_x86_64:latest`
- ARM64: `quay.io/pypa/manylinux_2_34_aarch64:2025.11.11-1`

Each `glslang-<version>-manylinux_<baseline>_<arch>.tar.xz` contains a same-named root directory with `bin/glslang`,
`bin/glslangValidator` (a relative symlink), `licenses/`, and `BUILD-INFO.txt`. The latter records source and build
recipe revisions, the image digest, configuration, compiler version, and installed container RPM versions.
Only GLSL/SPIR-V compilation is enabled: optional HLSL and the SPIRV-Tools optimizer are disabled. The requested
`-V --target-env vulkan1.0 --no-link -Od` path is supported; `-Os` is intentionally unavailable. C++ runtime
libraries are linked statically, with their license notices included; glibc is dynamic.

### Build and publish

Open **Actions → Build glslang (manylinux) → Run workflow** on `main`, enter `glslang_version` (default `15.4.0`),
and run it.
The workflow builds and validates both architectures, then automatically creates the release and attaches the
downloads. There is no publish checkbox and no need to create a Git tag. GitHub's manual-dispatch UI requires
the workflow to be present on the default branch.

Like the existing LLVM workflow, pull requests targeting `main` automatically build when they change this
workflow or `scripts/glslang/**`. PR builds use `DEFAULT_GLSLANG_VERSION` and publish a branch-named prerelease
after validation. A prerelease is a published release marked for testing before the changes reach `main`.
Manual runs on `main` publish regular releases; other branches publish prereleases. Fork PRs build and validate
but do not publish. There is no `push` trigger, so pushing a release tag does not start a second build.

The version must name an upstream release in `major.minor.patch` form and be at least 13.1.0 for `--no-link`.
15.4.0 is the validated default; other versions must pass the same build and validation checks before publication.
Manual release tags use `glslang-<version>-<UTC timestamp>-<run ID>`; PR tags also include the branch name.
Each publication waits for both architectures and fails if its release already exists. Per-archive SHA-256 files,
combined `SHA256SUMS`, validation logs, and
`glslang-source.env` accompany the archives. The latter records the exact source commit and timestamp.

Publication creates a draft, uploads all assets, then publishes without changing the repository's latest release.
Keep **Settings → General → Releases → Enable release immutability** enabled. The publisher verifies that GitHub
froze the release after publication and fails if it did not. This setting is enabled for this repository.
This repository setting affects future releases of all SDKs: other publishers must also upload their assets before
publishing. Already published releases are not retroactively frozen. No workflow uses `--clobber` or force-pushes.

### Reproduce on a native Linux host with Docker

Check out the release tag and download its `glslang-source.env` asset to the repository root. Then run from that
directory (requires Docker and the matching host architecture):

```bash
set -euo pipefail
source glslang-source.env
source scripts/glslang/pins.sh "$(uname -m)"
mkdir -p tmp dist
docker pull "$BUILD_IMAGE"
docker run --rm -v "$PWD:/work" -w /work -e SDK_BUILDS_REVISION="$(git rev-parse HEAD)" \
  -e GLSLANG_VERSION -e GLSLANG_REVISION -e SOURCE_DATE_EPOCH \
  "$BUILD_IMAGE" bash scripts/glslang/build.sh 2>&1 | tee tmp/build.log
docker run --rm -v "$PWD:/work" -w /work \
  -e GLSLANG_VERSION -e GLSLANG_REVISION -e SOURCE_DATE_EPOCH \
  "$BUILD_IMAGE" bash scripts/glslang/validate.sh 2>&1 | tee tmp/validation.log
(cd dist && sha256sum -c "$PACKAGE.tar.xz.sha256")
```

Use a clean checkout/work directory per build. Packaging normalizes file order, ownership, timestamps and xz
compression. Source and toolchain inputs are pinned; byte-for-byte reproducibility across independent hosts has
not been established. Validation uses the extracted archive with toolchain search paths removed, checks its ELF
runtime dependencies and glibc symbol ceiling, compiles [the requested shader](scripts/glslang/workgroup.comp),
checks the emitted SPIR-V library structure and export, and compiles an additional shader with a main entry point.
This is a compiler packaging smoke test, not a GPU execution test or full SPIR-V semantic validation.
