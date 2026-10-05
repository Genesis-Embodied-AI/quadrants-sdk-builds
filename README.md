# quadrants-sdk-builds

For building SDKs needed by Quadrants CI.

## Workflow and release conventions

For a regular release, open the workflow in **Actions**, select **Run workflow** on `main`, and enter the SDK
version. The workflow builds the SDK and creates the GitHub release with its downloads attached. Do not create
a release tag yourself: the publisher creates one automatically.

`workflow_dispatch` starts a manual run. Where enabled, `pull_request` starts automatic builds for PRs targeting
`main`. These builds use the workflow's default SDK version. Successful same-repository PR runs publish
branch-named prereleases for testing before merge. Runs on `main` publish regular releases.

See the [workflow files](.github/workflows) for each SDK's inputs, defaults, triggers, and build steps.
When adding a workflow, follow these conventions. Avoid a tag-push trigger alongside PR builds, because publishing
a release tag can then start a duplicate build.

Release immutability is enabled for this repository. Upload all downloads to a draft release before publishing
it, because its files become frozen when published. Keep **Settings → General → Releases → Enable release
immutability** enabled. Existing releases are not retroactively frozen.
