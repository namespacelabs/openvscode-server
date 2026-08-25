# Releases

## Branch model

Released artifacts are built from this repository, not directly from a Gitpod checkout. Each supported upstream version has a
`release/vX.Y.Z` branch (for example, `release/v1.109.5`) that contains:

1. the matching upstream Gitpod release history; and
2. the smallest reviewed set of Namespace-specific packaging or security commits.

`main` contains the most recently released version, or the next release while it is being prepared. This keeps the default
branch—and therefore Dependabot—on the code and dependencies that Namespace actually ships. When a version is ready, a release
branch is created at the tested `main` commit. `main` is not deleted or reset; it can subsequently advance to the next selected
upstream release.

The release workflow itself runs from `main`, resolves the derived release branch once, and builds that immutable commit on every
platform. The release tag points to that same commit, making the source, artifacts, and tag agree exactly.

## Release walkthrough

Set the upstream version and Namespace revision once for the commands below:

```bash
export VERSION=1.109.5
export REVISION=2
```

### 1. Prepare `main`

Start from a clean `main`, fetch the upstream release, and merge its exact tag:

```bash
git switch main
git status --short
git fetch upstream --tags
git merge --no-ff "openvscode-server-v${VERSION}"
```

Resolve any conflicts without discarding Namespace changes. Apply or update Namespace patches, then run the appropriate install,
audit, build, and test checks. Once reviewed, publish the release-ready `main`:

```bash
git push origin main
```

### 2. Cut the release branch

Run the helper with the upstream version. It verifies `main` and creates `release/v1.109.5` at the exact tested commit:

```bash
./scripts/prepare-release-branch.sh "$VERSION"
git push --set-upstream origin "release/v${VERSION}"
```

### 3. Build and release

Run a build-only validation first:

```bash
gh workflow run "OpenVSCode Server Release" \
  --ref main \
  -f version="$VERSION" \
  -f revision="$REVISION" \
  -f quality=stable \
  -f publish=false
```

After all platform builds succeed and their artifacts have been checked, rerun with `publish=true` to build again, create
`openvscode-server-v1.109.5-2`, and publish the GitHub release:

```bash
gh workflow run "OpenVSCode Server Release" \
  --ref main \
  -f version="$VERSION" \
  -f revision="$REVISION" \
  -f quality=stable \
  -f publish=true
```

## Cutting a release

A release is a build of a `release/vX.Y.Z` branch in this repository, shipped under a Namespace release tag. Prepare and validate
the upstream version and all Namespace changes on `main`, then cut the release branch from that exact commit. The release workflow
validates the branch name, package version, and upstream ancestry; it does not modify either branch.

Run it from **Actions → OpenVSCode Server Release → Run workflow**, or with the CLI:

```bash
gh workflow run "OpenVSCode Server Release" \
  --ref main \
  -f version="$VERSION" \
  -f revision="$REVISION" \
  -f quality=stable \
  -f publish=true
```

Inputs:

- `version` — the upstream OpenVSCode Server version, e.g. `1.109.5`. The workflow derives branch `release/v1.109.5` and upstream
  tag `openvscode-server-v1.109.5`.
- `revision` — the Namespace revision `N` (see [the `-N` suffix](#the-required--n-revision-suffix) below); starts at `1`.
- `quality` — `stable` (default) or `insider`. Insiders are published as a GitHub pre-release.
- `publish` — `true` creates the tag + release; **uncheck it for a build-only validation run** that just uploads the tarballs
  (they expire after 7 days).

The built version comes from the release branch's `package.json`, and the release tag is `openvscode-server-v<version>-<N>`
(insiders: `openvscode-server-insiders-v<version>-<N>`). The run builds Linux `x64`, Linux `arm64` and macOS `arm64`, and attaches
all three tarballs to the release:

```text
<tag>-linux-x64.tar.gz
<tag>-linux-arm64.tar.gz
<tag>-darwin-arm64.tar.gz
```

The created tag points at the exact fork commit that was built. The workflow refuses to run if that tag already exists, if the
branch does not match the `release/vX.Y.Z` name derived from the requested version, if `package.json` does not match that version,
or if the upstream tag is not an ancestor of the fork commit.

### The required `-N` revision suffix

Every release tag ends with a `-N` revision that Namespace controls. It lets you ship more than one release for a single upstream
VS Code version—for example, after adding or changing a Namespace patch on top of the same Gitpod/VS Code base. The suffix is
**required on every release**, not optional.

- The revision **starts at `-1`** for the first release of a version. There is no `-0`, and a bare, unsuffixed tag is not a valid
  release tag.
- Each subsequent re-cut of that same version increments the revision: `-2`, `-3`, and so on.

So a version's releases progress as:

```text
openvscode-server-v1.109.5-1    # first release of 1.109.5
openvscode-server-v1.109.5-2    # re-cut with new/changed patches
openvscode-server-v1.109.5-3    # and so on
```

Each is an independent tag, so the number is entirely yours to manage.

## Version parity with Gitpod

This fork mirrors [gitpod-io/openvscode-server](https://github.com/gitpod-io/openvscode-server), which tags releases as
`openvscode-server-v<vscode-version>`. The release branch must contain that tag, so their `openvscode-server-v1.109.5` becomes our
`openvscode-server-v1.109.5-N` with only the commits visible on our branch added.

Namespace uses a branch for each exact upstream version so an older version can receive a new Namespace revision after `main`
advances. Active patches remain on `main` when it moves to the next upstream release, where Dependabot and CI can continue to
evaluate them; obsolete patches should be removed explicitly when upstream incorporates the fix.

## Staying current with Gitpod

Configure and fetch the upstream repository once:

```bash
git remote add upstream https://github.com/gitpod-io/openvscode-server.git   # once
git fetch upstream --tags
```

To prepare the next upstream version, merge its exact tag into `main`. Resolve conflicts without discarding Namespace patches,
then run the normal validation:

```bash
git switch main
git fetch upstream --tags
git merge --no-ff "openvscode-server-v${VERSION}"
# Resolve conflicts, install dependencies, and run CI before continuing.
```

Once `main` is ready, use the preparation script to validate it against the exact upstream tag and create or switch to its derived
release branch:

```bash
./scripts/prepare-release-branch.sh "$VERSION"
```

The script verifies the versions in upstream and local `package.json`, checks that the working tree is clean, ensures the upstream
tag is in the history, and creates `release/v1.109.5` from the current `main` commit when needed. If the branch already exists, it
switches to and validates that branch without moving it. The script changes only the local repository. Review the result and
publish the branch explicitly:

```bash
git push --set-upstream origin "release/v${VERSION}"
```

Do not rebase a published release branch: release tags and prior builds must keep their source history. Apply maintenance fixes
directly to that branch and publish a new `-N` revision. Once the branch is ready, run the release workflow from `main`; it
automates source validation, immutable-SHA checkout, all platform builds, artifact upload, and optional tag/release publication.

## Verifying a release

Download the tarball, extract it, and run:

```bash
./openvscode-server-*/bin/openvscode-server \
  --port 3000 --without-connection-token --host 127.0.0.1
```

On macOS, remove the quarantine attribute if the archive was downloaded by a browser:

```bash
xattr -dr com.apple.quarantine openvscode-server-*
```

## Building locally

To build a target outside the release workflow, install dependencies with `npm ci`, then run its Gulp task.

Linux x64:

```bash
npm run gulp vscode-reh-web-linux-x64-min
```

Linux arm64:

```bash
npm run gulp vscode-reh-web-linux-arm64-min
```

macOS arm64:

```bash
CXXFLAGS=-DFMT_CONSTEVAL= npm run gulp vscode-reh-web-darwin-arm64-min
```

Under Apple Clang 21, the `CXXFLAGS` workaround avoids a vendored fmt compile error in `@vscode/spdlog`. It is harmless on older
macOS runners.
