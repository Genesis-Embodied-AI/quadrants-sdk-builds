# quadrants-sdk-builds

For building SDKs needed by quadrants CI.

## Workflow and release conventions

For a regular release, open the workflow in **Actions**, select **Run workflow** on `main`, and enter the SDK
version. The workflow builds the SDK and creates the GitHub release with its downloads attached. Do not create
a release tag yourself: the publisher creates one automatically.

`workflow_dispatch` is the manual event; it is not the event used to test PR changes. The LLVM and glslang
workflows also use `pull_request` for automatic PR builds targeting `main`, limited to their relevant files.
These runs use the workflow's default SDK version. Successful same-repository PR runs publish branch-named
prereleases, meaning releases marked for testing before merge. Runs on `main` publish regular releases.

| Workflow | Manual version input | Automatic PR builds |
| --- | --- | --- |
| [LLVM](.github/workflows/llvm-ci.yml) | `llvm_version` | Changes to its workflow file |
| [glslang](.github/workflows/glslang-manylinux.yml) | `glslang_version` | Its workflow or `scripts/glslang/**` |
| [Vulkan ARM](.github/workflows/vulkan-arm.yml) | `version` | Currently disabled in that workflow |

For example, [PR #14](https://github.com/Genesis-Embodied-AI/quadrants-sdk-builds/pull/14) ran through the
`pull_request` event and published branch-named LLVM prereleases. The later manual run on `main` published the
regular LLVM release. Follow that pattern for new SDK build workflows. Do not add a tag-push trigger alongside
PR builds: it is unnecessary for publication and can duplicate the same build.

Release immutability is enabled for this repository. Upload all downloads to a draft release before publishing
it, because its files become frozen when published. The glslang publisher implements this sequence explicitly
and checks GitHub's `immutable` field afterward. Existing releases are not retroactively frozen.

## glslang for manylinux

[Build glslang (manylinux)](.github/workflows/glslang-manylinux.yml) defaults to **15.4.0** at
`8a85691a0740d390761a1008b4696f57facd02c4` on native x86_64 and ARM64 runners. Builds and smoke tests run in
separate, fresh containers. [pins.sh](scripts/glslang/pins.sh) selects the same image tags used by Quadrants.
GCC, CMake, Make, Python and binutils come from those images; no package installation or external source
dependencies are needed.
Like LLVM, each architecture fetches the requested upstream version tag directly. Version defaults live only
in the workflow; scripts require `GLSLANG_VERSION`. There is no separate source-resolution job or shared
revision input. Each archive records its actual source commit in `BUILD-INFO.txt` using `git rev-parse HEAD`.

The container image tags are:

- x86_64: `quay.io/pypa/manylinux_2_28_x86_64:latest`
- ARM64: `quay.io/pypa/manylinux_2_34_aarch64:2025.11.11-1`

Each `glslang-<version>-manylinux_<baseline>_<arch>.tar.xz` contains a same-named root directory with `bin/glslang`,
`bin/glslangValidator` (a relative symlink), `licenses/`, and `BUILD-INFO.txt`. The latter records source and build
recipe revisions, the image tag, configuration, compiler version, and installed container RPM versions.
Only GLSL/SPIR-V compilation is enabled: optional HLSL and the SPIRV-Tools optimizer are disabled. The requested
`-V --target-env vulkan1.0 --no-link -Od` path is supported; `-Os` is intentionally unavailable. C++ runtime
libraries are linked statically, with their license notices included; glibc is dynamic.

### Build and publish

Open **Actions → Build glslang (manylinux) → Run workflow** on `main`, enter `glslang_version` (default `15.4.0`),
and run it. The workflow builds and validates both architectures, then automatically creates the release and attaches the
downloads. There is no publish checkbox and no need to create a Git tag. GitHub's manual-dispatch UI requires
the workflow to be present on the default branch.

Like the existing LLVM workflow, pull requests targeting `main` automatically build when they change this
workflow or `scripts/glslang/**`. PR builds use the workflow’s default `GLSLANG_VERSION` and publish a branch-named prerelease
after validation. A prerelease is a published release marked for testing before the changes reach `main`.
Manual runs on `main` publish regular releases; other branches publish prereleases. Fork PRs build and validate
but do not publish. There is no `push` trigger, so pushing a release tag does not start a second build.

The version must name an upstream release in `major.minor.patch` form and be at least 13.1.0 for `--no-link`.
15.4.0 is the validated default; other versions must pass the same build and validation checks before publication.
Like LLVM, manual release tags use `glslang-<version>-<YYYYMMDDHHMM>` with the current UTC date and time.
PR tags use `glslang-<version>-<branch>-<YYYYMMDDHHMM>`. Runs on `main` are regular releases; other branches
are prereleases. A publication that would reuse an existing tag fails instead of replacing frozen assets.
Each publication waits for both architectures and fails if its release already exists. Per-archive SHA-256 files,
combined `SHA256SUMS` and validation logs accompany the archives.

Publication creates a draft, uploads all assets, then publishes without changing the repository's latest release.
Keep **Settings → General → Releases → Enable release immutability** enabled. The publisher verifies that GitHub
froze the release after publication and fails if it did not. This setting is enabled for this repository.
This repository setting affects future releases of all SDKs: other publishers must also upload their assets before
publishing. Already published releases are not retroactively frozen. No workflow uses `--clobber` or force-pushes.

### Reproduce on a native Linux host with Docker

Check out the SDK release tag. From that directory, set the glslang version to build and run the following
commands (requires Docker and the matching host architecture):

```bash
set -euo pipefail
export GLSLANG_VERSION=15.4.0 # Set this to the requested upstream release version.
source scripts/glslang/pins.sh "$(uname -m)"
mkdir -p tmp dist
docker pull "$TARGET_IMAGE"
docker run --rm -v "$PWD:/work" -w /work -e SDK_BUILDS_REVISION="$(git rev-parse HEAD)" \
  -e GLSLANG_VERSION \
  "$TARGET_IMAGE" bash scripts/glslang/build.sh 2>&1 | tee tmp/build.log
docker run --rm -v "$PWD:/work" -w /work \
  -e GLSLANG_VERSION \
  "$TARGET_IMAGE" bash scripts/glslang/validate.sh 2>&1 | tee tmp/validation.log
(cd dist && sha256sum -c "$PACKAGE.tar.xz.sha256")
```

Use a clean checkout/work directory per build. Packaging uses ordinary file timestamps, matching the other SDK workflows.
Source and container images are selected by tag, matching the other workflows. Archive checksums can differ because timestamps differ.
Validation uses the extracted archive with toolchain search paths removed, checks its ELF
runtime dependencies and glibc symbol ceiling, compiles [the requested shader](scripts/glslang/workgroup.comp),
checks the emitted SPIR-V library structure and export, and compiles an additional shader with a main entry point.
This is a compiler packaging smoke test, not a GPU execution test or full SPIR-V semantic validation.
