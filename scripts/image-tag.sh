#!/usr/bin/env bash
# Prints the image tag for the current checkout: the short commit SHA, with
# "-dirty" appended when there are uncommitted changes. A dirty tag warns that
# the image doesn't match any commit, and rebuilding it overwrites the old one.
set -euo pipefail

tag=$(git rev-parse --short HEAD)
if [ -n "$(git status --porcelain)" ]; then
    tag="$tag-dirty"
fi
echo "$tag"
