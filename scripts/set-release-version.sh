#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Usage: $0 <version> (for example: $0 1.109.5)" >&2
	exit 1
fi

version=$1
upstream_tag="openvscode-server-v${version}"
upstream_url="https://github.com/gitpod-io/openvscode-server.git"
root=$(git rev-parse --show-toplevel)

cd "$root"

if [[ $(git branch --show-current) != main ]]; then
	echo "Release targets must be set on main" >&2
	exit 1
fi

if [[ -n $(git diff --name-only --diff-filter=U) ]]; then
	echo "Resolve merge conflicts before setting the release version" >&2
	exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
	git remote add upstream "$upstream_url"
fi

echo "Fetching upstream $upstream_tag..."
git fetch upstream "refs/tags/${upstream_tag}:refs/tags/${upstream_tag}"

tag_version=$(git show "${upstream_tag}:package.json" | node -e \
	"let input = ''; process.stdin.on('data', chunk => input += chunk); process.stdin.on('end', () => console.log(JSON.parse(input).version));")
if [[ $tag_version != "$version" ]]; then
	echo "$upstream_tag contains package version $tag_version, expected $version" >&2
	exit 1
fi

package_version=$(node -p "require('./package.json').version")
if [[ $package_version != "$version" ]]; then
	echo "main contains package version $package_version, expected $version" >&2
	exit 1
fi

upstream_sha=$(git rev-parse "${upstream_tag}^{commit}")
if ! git merge-base --is-ancestor "$upstream_sha" HEAD; then
	echo "main does not contain $upstream_tag; merge it before setting the release version" >&2
	exit 1
fi

printf '%s\n' "$version" > .release
echo ".release now targets $version"
