#!/bin/bash
set -euo pipefail

version="${1:?usage: scripts/build-dmg.sh <version, for example 1.0.0>}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must have the form 1.2.3. Got: $version" >&2
  exit 1
fi
build_number="${BUILD_NUMBER:-1}"

root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="$root/build/DerivedData"
dist="$root/build/dist"
staging="$root/build/dmg-staging"
dmg_name="SamsungDisplay-$version.dmg"

cd "$root"
rm -rf "$staging" "$dist"
mkdir -p "$staging" "$dist"

xcodegen generate

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  xcodebuild test \
    -scheme SamsungDisplay \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived_data"
fi

xcodebuild build \
  -scheme SamsungDisplay \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build_number"

ditto "$derived_data/Build/Products/Release/SamsungDisplay.app" "$staging/SamsungDisplay.app"
ln -s /Applications "$staging/Applications"

hdiutil create \
  -volname SamsungDisplay \
  -srcfolder "$staging" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$dist/$dmg_name"

(cd "$dist" && shasum -a 256 "$dmg_name" > "$dmg_name.sha256")

echo "$dist/$dmg_name"
