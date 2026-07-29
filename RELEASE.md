# Releases

## Cutting a release

Releasing is just tagging. Every release tag **must** carry a trailing `-N`
revision (see [the `-N` suffix](#the-required--n-revision-suffix) below). Create
and push a tag on the commit you want to ship:

```bash
git tag openvscode-server-v1.109.5-1
git push origin openvscode-server-v1.109.5-1
```

The `OpenVSCode Server Release` workflow triggers on that tag, builds Linux
`x64`, Linux `arm64` and macOS `arm64`, and publishes a GitHub release named
after the tag with all three tarballs attached:

```text
<tag>-linux-x64.tar.gz
<tag>-linux-arm64.tar.gz
<tag>-darwin-arm64.tar.gz
```

- The tag name is the release name, so it is fully under your control.
- For an insiders build, tag `openvscode-server-insiders-v<version>-N`; it is
  published as a pre-release.

To validate a build without publishing, run the workflow manually
(**Actions → OpenVSCode Server Release → Run workflow**) — a `workflow_dispatch`
run builds the artifacts but does not create a release.

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
which tags releases as `openvscode-server-v<vscode-version>`. Use the same
VS Code version for the tag you are shipping (plus our required `-N` revision) so
our releases line up with theirs — e.g. their `openvscode-server-v1.109.5`
becomes our `openvscode-server-v1.109.5-1`.

## Staying current with Gitpod

We track `gitpod-io/openvscode-server`; our own patches live as commits on top
of it. To pull in Gitpod's newer code, merge their branch or a release tag —
our patches ride along, no rebasing required:

```bash
git remote add upstream https://github.com/gitpod-io/openvscode-server.git   # once
git fetch upstream --tags
git merge openvscode-server-v1.109.5    # the upstream tag; or: git merge upstream/main
# resolve any conflicts, then push
```

Then cut the release by tagging as above.

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
