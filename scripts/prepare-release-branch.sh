#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Usage: $0 <version> (for example: $0 1.109.5)" >&2
	exit 1
fi

version=$1
branch="namespace-release/v${version}"
upstream_tag="openvscode-server-v${version}"
upstream_url="https://github.com/gitpod-io/openvscode-server.git"
root=$(git rev-parse --show-toplevel)

cd "$root"

if [[ -n $(git status --porcelain) ]]; then
	echo "Working tree must be clean before preparing $branch" >&2
	exit 1
fi

if [[ ! -f .release ]]; then
	echo "Missing .release; run scripts/set-release-version.sh $version on main first" >&2
	exit 1
fi

release_version=$(cat .release)
if [[ $release_version != "$version" ]]; then
	echo ".release targets $release_version, expected $version" >&2
	exit 1
fi

current_branch=$(git branch --show-current)
if [[ $current_branch != main && $current_branch != "$branch" ]]; then
	echo "Run this script from main or $branch (currently on $current_branch)" >&2
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

remote_exists=false
if git ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; then
	git fetch origin "refs/heads/${branch}:refs/remotes/origin/${branch}"
	remote_exists=true
fi

if git show-ref --verify --quiet "refs/heads/${branch}"; then
	git switch "$branch"
elif git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
	git switch --create "$branch" --track "origin/${branch}"
else
	if [[ $current_branch != main ]]; then
		echo "$branch does not exist and must be created from main" >&2
		exit 1
	fi
	git switch --create "$branch" main
fi

remote_status=absent
if [[ $remote_exists == true ]]; then
	local_sha=$(git rev-parse HEAD)
	remote_sha=$(git rev-parse "origin/${branch}")
	if [[ $local_sha == "$remote_sha" ]]; then
		remote_status=equal
	elif git merge-base --is-ancestor "$local_sha" "$remote_sha"; then
		echo "Local $branch is behind origin/$branch; fast-forward it explicitly and rerun:" >&2
		echo "  git merge --ff-only origin/$branch" >&2
		exit 1
	elif git merge-base --is-ancestor "$remote_sha" "$local_sha"; then
		remote_status=ahead
	else
		echo "Local $branch has diverged from origin/$branch; reconcile it explicitly before releasing" >&2
		exit 1
	fi
fi

branch_version=$(node -p "require('./package.json').version")
if [[ $branch_version != "$version" ]]; then
	echo "$branch contains package version $branch_version, expected $version" >&2
	exit 1
fi

upstream_sha=$(git rev-parse "${upstream_tag}^{commit}")
if ! git merge-base --is-ancestor "$upstream_sha" HEAD; then
	echo "$branch does not contain $upstream_tag; merge it into main before cutting the branch" >&2
	exit 1
fi

source_sha=$(git rev-parse HEAD)
echo "$branch is ready at $source_sha and contains $upstream_tag at $upstream_sha."
if [[ $remote_status == absent ]]; then
	echo "Publish it with: git push --set-upstream origin $branch"
elif [[ $remote_status == ahead ]]; then
	echo "$branch contains local commits that are not on origin/$branch."
	echo "Publish them with: git push origin $branch"
fi
