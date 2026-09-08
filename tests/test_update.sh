#!/usr/bin/env bash
set -Eeuo pipefail
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

git init --bare -q "$TEST_TMP/origin.git"
git clone -q "$TEST_TMP/origin.git" "$TEST_TMP/seed"
git -C "$TEST_TMP/seed" config user.name Test
git -C "$TEST_TMP/seed" config user.email test@example.invalid
printf 'v1\n' >"$TEST_TMP/seed/version"
git -C "$TEST_TMP/seed" add version
git -C "$TEST_TMP/seed" commit -qm initial
git -C "$TEST_TMP/seed" branch -M main
git -C "$TEST_TMP/seed" push -qu origin main
git --git-dir="$TEST_TMP/origin.git" symbolic-ref HEAD refs/heads/main

git clone -q "$TEST_TMP/origin.git" "$TEST_TMP/installed"
git clone -q "$TEST_TMP/origin.git" "$TEST_TMP/upstream"
git -C "$TEST_TMP/upstream" config user.name Test
git -C "$TEST_TMP/upstream" config user.email test@example.invalid
printf 'v2\n' >"$TEST_TMP/upstream/version"
git -C "$TEST_TMP/upstream" add version
git -C "$TEST_TMP/upstream" commit -qm update
git -C "$TEST_TMP/upstream" push -q

PROJECT_ROOT="$TEST_TMP/installed"
command_exists() { command -v "$1" >/dev/null 2>&1; }
warn() { printf '%s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }
confirm() { return 0; }
log_event() { :; }
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/update.sh"

update_project
[[ $UPDATE_APPLIED == 1 ]]
[[ $(<"$PROJECT_ROOT/version") == v2 ]]
[[ -z $(git -C "$PROJECT_ROOT" status --porcelain) ]]
printf 'Prueba de actualización segura aprobada.\n'
