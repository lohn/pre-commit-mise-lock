#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

# Locations mise loads configuration from (see https://mise.jdx.dev/configuration.html).
# The `*` (except for conf.d/*.toml) stands for MISE_ENV. Top-level `*.local.toml`
# files are local overrides and are intentionally never locked, but files inside
# conf.d/ are always locked regardless of their name.
#
# Implemented with plain (indexed) arrays and POSIX-ish constructs only, so it
# runs on bash 3.2 (the default on macOS) as well as modern bash.

# Resolve the mise config root (the directory `mise lock` must run in) for a
# config path, by stripping the recognized mise config suffix. Echoes "." for a
# config at the repository root. Order matters: most specific patterns first.
config_root_of() {
  local p="$1" r
  case "$p" in
    *.config/mise/conf.d/*.toml) r="${p%.config/mise/conf.d/*.toml}" ;;
    *.config/mise/config.toml | *.config/mise/config.*.toml) r="${p%.config/mise/*}" ;;
    *.config/mise.toml | *.config/mise.*.toml) r="${p%.config/mise*}" ;;
    *.mise/config.toml | *.mise/config.*.toml) r="${p%.mise/*}" ;;
    *mise/config.toml | *mise/config.*.toml) r="${p%mise/*}" ;;
    *)
      r="${p%/*}"
      [ "$r" = "$p" ] && r="."
      ;;
  esac
  r="${r%/}"
  [ -z "$r" ] && r="."
  printf '%s' "$r"
}

# Deduplicated queue of "<root><TAB><target>" jobs, where target is "default" or
# "env:<name>". `seen` mirrors `jobs` purely for membership testing.
jobs=()
seen=$'\n'

queue() {
  local key="$1"$'\t'"$2"
  case "$seen" in
    *$'\n'"$key"$'\n'*) return ;;
  esac
  seen="$seen$key"$'\n'
  jobs+=("$key")
}

if [ "$#" -eq 0 ]; then
  configs=(
    mise.toml mise.*.toml
    mise/config.toml mise/config.*.toml
    .mise/config.toml .mise/config.*.toml
    .config/mise.toml .config/mise.*.toml
    .config/mise/config.toml .config/mise/config.*.toml
    .config/mise/conf.d/*.toml
  )
else
  configs=("$@")
fi

for config in "${configs[@]}"; do
  [ -e "$config" ] || continue

  root="$(config_root_of "$config")"
  base="${config##*/}"

  # conf.d is checked first so its files match before the *.local.toml rule:
  # there `.local.toml` is just an ordinary name and is still locked, whereas
  # top-level `*.local.toml` overrides are dummies and skipped.
  case "$config" in
    */conf.d/*.toml | conf.d/*.toml)
      # conf.d entries contribute to the default config, not to a MISE_ENV.
      queue "$root" "default"
      continue
      ;;
    *.local.toml)
      continue
      ;;
  esac

  case "$base" in
    mise.toml | config.toml)
      queue "$root" "default"
      ;;
    mise.*.toml)
      env_name="${base#mise.}"
      queue "$root" "env:${env_name%.toml}"
      ;;
    config.*.toml)
      env_name="${base#config.}"
      queue "$root" "env:${env_name%.toml}"
      ;;
  esac
done

# Guard the array expansion: empty-array expansion under `set -u` errors on
# bash < 4.4, and there is nothing to do anyway.
[ "${#jobs[@]}" -ne 0 ] || exit 0

for job in "${jobs[@]}"; do
  root="${job%%$'\t'*}"
  target="${job#*$'\t'}"
  case "$target" in
    default) (cd "$root" && mise lock) ;;
    env:*) (cd "$root" && mise lock --env "${target#env:}") ;;
  esac
done
