#!/bin/bash
set -e

platforms=(
  android-amd64
  android-arm64
  darwin-amd64
  darwin-arm64
  freebsd-386
  freebsd-amd64
  freebsd-arm64
  linux-386
  linux-amd64
  linux-arm
  linux-arm64
  windows-386
  windows-amd64
  windows-arm64
)

if [[ $GITHUB_REF = refs/tags/* ]]; then
  tag="${GITHUB_REF#refs/tags/}"
else
  tag="$(git describe --tags --abbrev=0)"
fi

prerelease=""
if [[ $tag = *-* ]]; then
  prerelease="--prerelease"
fi

if [ -n "$GH_EXT_BUILD_SCRIPT" ]; then
  echo "invoking build script override $GH_EXT_BUILD_SCRIPT"
  ./"$GH_EXT_BUILD_SCRIPT" "$tag"
else
  for p in "${platforms[@]}"; do
    goos="${p%-*}"
    goarch="${p#*-}"
    ext=""
    if [ "$goos" = "windows" ]; then
      ext=".exe"
    fi
    GOOS="$goos" GOARCH="$goarch" go build -trimpath -ldflags="-s -w" -o "dist/${p}${ext}"
  done
fi

assets=()
for f in dist/*; do
  if [ -f "$f" ]; then
    assets+=("$f")
  fi
done

if [ "${#assets[@]}" -eq 0 ]; then
  echo "error: no files found in dist/*" >&2
  exit 1
fi

if [ -n "$GPG_FINGERPRINT" ]; then
  shasum -a 256 "${assets[@]}" > checksums.txt
  gpg --output checksums.txt.sig --detach-sign checksums.txt
  assets+=(checksums.txt checksums.txt.sig)
fi

if ! gh release create "$tag" $prerelease --title="${GITHUB_REPOSITORY#*/} ${tag#v}" --generate-notes -- "${assets[@]}"; then
  echo "trying to upload assets to an existing release instead..."
  gh release upload "$tag" --clobber -- "${assets[@]}"
fi
