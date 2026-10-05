#!/usr/bin/env bash
# Publish a frozen release from a name prefix, notes file, and directory of assets.
set -euxo pipefail
prefix=${1:?Expected release name prefix}
notes_file=${2:?Expected release notes file}
assets_dir=${3:?Expected asset directory}
test -f "$notes_file"
test -d "$assets_dir"
date_suffix=$(date -u +%Y%m%d%H%M)
if [[ "$GITHUB_EVENT_NAME" == workflow_dispatch ]]; then
    tag="${prefix}-${date_suffix}"
else
    branch=$(printf '%s' "$GITHUB_HEAD_REF" | tr '/' '-' | tr -cd '[:alnum:]-')
    tag="${prefix}-${branch}-${date_suffix}"
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
# Create the release tag automatically at the exact build recipe commit.
gh release create "$tag" --target "$GITHUB_SHA" --draft --prerelease="$prerelease" \
    --title "$tag" --notes-file "$notes_file"
gh release upload "$tag" "$assets_dir"/*
# Leave the repository's latest-release selection unchanged.
gh release edit "$tag" --draft=false --latest=false
# Checking the release needs only contents access; reading the repository setting needs an admin token.
test "$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$tag" --jq .immutable)" = true
gh release view "$tag" --json url,assets
