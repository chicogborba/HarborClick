#!/usr/bin/env bash
# Install one immutable HarborClick release and atomically make it current.
set -euo pipefail

readonly DEPLOY_USER="harborclick-deploy"
readonly BASE_DIR="/var/www/harborclick-deploy"
readonly RELEASES_DIR="$BASE_DIR/releases"
readonly ARTIFACTS_DIR="$BASE_DIR/artifacts"
readonly CURRENT_LINK="$BASE_DIR/current"
readonly INCOMING_DIR="/home/$DEPLOY_USER/incoming"

die() {
  printf 'deploy error: %s\n' "$*" >&2
  exit 1
}

release_sha="${1:-}"
[[ "$release_sha" =~ ^[0-9a-f]{40}$ ]] || die "expected a full Git commit SHA"
[[ "$(id -un)" == "$DEPLOY_USER" ]] || die "must run as $DEPLOY_USER"

archive="$INCOMING_DIR/$release_sha.tar.gz"
release_dir="$RELEASES_DIR/$release_sha"
artifact="$ARTIFACTS_DIR/$release_sha.tar.gz"
next_link="$BASE_DIR/.current-$release_sha-$$"
temp_dir=""

cleanup() {
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf -- "$temp_dir"
  fi
  if [[ -L "$next_link" ]]; then
    rm -f -- "$next_link"
  fi
}
trap cleanup EXIT

install -d -m 0755 "$RELEASES_DIR" "$ARTIFACTS_DIR" "$INCOMING_DIR"
[[ -f "$archive" ]] || die "release archive was not uploaded"

if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  die "archive contains an unsafe path"
fi

temp_dir="$(mktemp -d "$RELEASES_DIR/.release-$release_sha-XXXXXX")"
tar -xzf "$archive" --no-same-owner --no-same-permissions -C "$temp_dir"

if [[ -n "$(find "$temp_dir" -type l -print -quit)" ]]; then
  die "release archive contains an unexpected symbolic link"
fi

required_files=(
  index.html
  styles.css
  script.js
  jogar/index.html
  jogar/index.pck
  jogar/index.wasm
)
for relative_path in "${required_files[@]}"; do
  [[ -s "$temp_dir/$relative_path" ]] || die "missing $relative_path"
done

chmod -R u=rwX,go=rX "$temp_dir"
if [[ ! -d "$release_dir" ]]; then
  mv "$temp_dir" "$release_dir"
  temp_dir=""
fi

mv -f -- "$archive" "$artifact"
ln -s "releases/$release_sha" "$next_link"
mv -Tf -- "$next_link" "$CURRENT_LINK"

printf 'DEPLOYED_SHA=%s\n' "$release_sha"
