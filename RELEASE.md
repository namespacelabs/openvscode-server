# Releases

## Cutting a release

A release is a build of an **upstream Gitpod version**, shipped under a Namespace
release tag. You cut one by running the `OpenVSCode Server Release` workflow and
telling it which upstream tag to build and which revision this is.

The workflow runs from `main` (so the release logic is always current), checks
out the chosen [`gitpod-io/openvscode-server`](https://github.com/gitpod-io/openvscode-server)
tag on a throwaway runner, builds it, and — when publishing — creates the
release tag and GitHub release. **It never changes `main` or any branch**; the
upstream sources only ever exist in the runner's workspace.

Run it from **Actions → OpenVSCode Server Release → Run workflow**, or with the
CLI:

```bash
gh workflow run "OpenVSCode Server Release" \
  -f upstream_ref=openvscode-server-v1.109.5 \
  -f revision=1 \
  -f quality=stable \
  -f publish=true
```

Inputs:

- `upstream_ref` — the Gitpod tag (or ref) to build, e.g.
  `openvscode-server-v1.109.5`.
- `revision` — the Namespace revision `N` (see
  [the `-N` suffix](#the-required--n-revision-suffix) below); starts at `1`.
- `quality` — `stable` (default) or `insider`. Insiders are published as a
  GitHub pre-release.
- `publish` — `true` creates the tag + release; **uncheck it for a build-only
  validation run** that just uploads the tarballs (they expire after 7 days).

The built version comes from the upstream tag's `package.json`, and the release
tag is `openvscode-server-v<version>-<N>` (insiders:
`openvscode-server-insiders-v<version>-<N>`). The run builds Linux `x64`, Linux
`arm64` and macOS `arm64`, and attaches all three tarballs to the release:

```text
<tag>-linux-x64.tar.gz
<tag>-linux-arm64.tar.gz
<tag>-darwin-arm64.tar.gz
```

The created tag points at the exact upstream commit that was built, so a release
is always traceable to its Gitpod source. The workflow refuses to run if that
tag already exists, or if `upstream_ref` doesn't reference the version it builds.

### The required `-N` revision suffix

Every release tag ends with a `-N` revision that Namespace controls. It lets you
ship more than one release for a single upstream VS Code version — for example
after adding or changing a Namespace patch on top of the same Gitpod/VS Code
base. The suffix is **required on every release**, not optional.

- The revision **starts at `-1`** for the first release of a version. There is
  no `-0`, and a bare, unsuffixed tag is not a valid release tag.
- Each subsequent re-cut of that same version increments the revision: `-2`,
  `-3`, and so on.

So a version's releases progress as:

```text
openvscode-server-v1.109.5-1    # first release of 1.109.5
openvscode-server-v1.109.5-2    # re-cut with new/changed patches
openvscode-server-v1.109.5-3    # and so on
```

Each is an independent tag, so the number is entirely yours to manage.

## Version parity with Gitpod

This fork mirrors [gitpod-io/openvscode-server](https://github.com/gitpod-io/openvscode-server),
which tags releases as `openvscode-server-v<vscode-version>`. Because you pass
their tag straight to the workflow's `upstream_ref`, our releases line up with
theirs automatically — their `openvscode-server-v1.109.5` becomes our
`openvscode-server-v1.109.5-1`.

Gitpod cuts stable releases from dedicated release commits, **not** from their
`main` (which is bleeding-edge). We do the same: the release always builds the
upstream *release tag* you name, regardless of what `main` currently is — so you
never have to move `main` to a particular version to ship it.

## Staying current with Gitpod

Our `main` tracks `gitpod-io/openvscode-server` for sources and CI, with our
fork-owned files (this release workflow, `namespace-ci.yml`, docs) layered on
top. To pull in Gitpod's newer code, merge their branch or a tag — our files
ride along, no rebasing required:

```bash
git remote add upstream https://github.com/gitpod-io/openvscode-server.git   # once
git fetch upstream --tags
git merge upstream/main    # or a specific tag, e.g. openvscode-server-v1.109.5
# resolve any conflicts, then push
```

Keeping `main` current is **independent of releasing** — you can release any
upstream version at any time via the workflow's `upstream_ref` input without
touching `main`.

## Verifying a release

Download the tarball, extract it, and run:

```bash
./openvscode-server-*/bin/openvscode-server \
  --port 3000 --without-connection-token --host 127.0.0.1
```

On macOS, remove the quarantine attribute if the archive was downloaded by a
browser:

```bash
xattr -dr com.apple.quarantine openvscode-server-*
```

## Building locally

To build a target outside the release workflow, install dependencies with
`npm ci`, then run its Gulp task.

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

Under Apple Clang 21, the `CXXFLAGS` workaround avoids a vendored fmt compile
error in `@vscode/spdlog`. It is harmless on older macOS runners.
