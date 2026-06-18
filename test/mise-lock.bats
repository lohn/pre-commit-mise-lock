#!/usr/bin/env bats

# Tests for mise-lock.sh.
#
# `mise` is replaced by a stub on PATH that just echoes the arguments it was
# called with, so each test asserts *which* `mise lock` invocations the script
# would make for a given set of config files — without touching a real toolchain.
#
# Uses the bats-support / bats-assert libraries (provided via BATS_LIB_PATH by test/run-bats.sh).

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  SCRIPT="${BATS_TEST_DIRNAME}/../mise-lock.sh"

  WORKDIR="$(mktemp -d)"
  STUBDIR="${WORKDIR}/.stub"
  mkdir -p "$STUBDIR"
  cat > "${STUBDIR}/mise" <<'STUB'
#!/usr/bin/env bash
echo "mise $*"
STUB
  chmod +x "${STUBDIR}/mise"

  PATH="${STUBDIR}:${PATH}"
  cd "$WORKDIR"
}

teardown() {
  cd /
  rm -rf "$WORKDIR"
}

# Create an (empty) config file, including any parent directories.
mkconf() {
  mkdir -p "$(dirname "$1")"
  touch "$1"
}

# Assert that exactly the given lock invocations ran, in any order
# (env locks come from an associative array, so order is not guaranteed).
assert_locks() {
  assert_success
  local line
  for line in "$@"; do
    assert_line "$line"
  done
  assert_equal "${#lines[@]}" "$#"
}

@test "mise.toml locks the default config" {
  mkconf mise.toml
  run "$SCRIPT" mise.toml
  assert_locks "mise lock"
}

@test "mise.<env>.toml locks that environment" {
  mkconf mise.dev.toml
  run "$SCRIPT" mise.dev.toml
  assert_locks "mise lock --env dev"
}

@test "mise/config.toml locks the default config" {
  mkconf mise/config.toml
  run "$SCRIPT" mise/config.toml
  assert_locks "mise lock"
}

@test ".mise/config.<env>.toml locks that environment" {
  mkconf .mise/config.qa.toml
  run "$SCRIPT" .mise/config.qa.toml
  assert_locks "mise lock --env qa"
}

@test ".config/mise.<env>.toml locks that environment" {
  mkconf .config/mise.ci.toml
  run "$SCRIPT" .config/mise.ci.toml
  assert_locks "mise lock --env ci"
}

@test ".config/mise/config.<env>.toml locks that environment" {
  mkconf .config/mise/config.staging.toml
  run "$SCRIPT" .config/mise/config.staging.toml
  assert_locks "mise lock --env staging"
}

@test "conf.d/*.toml locks the default config" {
  mkconf .config/mise/conf.d/00-base.toml
  run "$SCRIPT" .config/mise/conf.d/00-base.toml
  assert_locks "mise lock"
}

@test "conf.d/*.local.toml is still locked" {
  mkconf .config/mise/conf.d/99-override.local.toml
  run "$SCRIPT" .config/mise/conf.d/99-override.local.toml
  assert_locks "mise lock"
}

@test "top-level *.local.toml is skipped (nothing is locked)" {
  mkconf mise.local.toml
  run "$SCRIPT" mise.local.toml
  assert_success
  assert_output ""
}

@test "a config in a subdirectory is locked from that directory" {
  # Override the stub to report the directory mise actually runs in.
  cat > "${STUBDIR}/mise" <<'STUB'
#!/usr/bin/env bash
echo "$PWD"
STUB
  mkconf packages/foo/mise.toml
  run "$SCRIPT" packages/foo/mise.toml
  assert_success
  assert_output --partial "/packages/foo"
}

@test "duplicate environments are locked only once" {
  mkconf mise.dev.toml
  mkconf mise/config.dev.toml
  run "$SCRIPT" mise.dev.toml mise/config.dev.toml
  assert_locks "mise lock --env dev"
}

@test "a mix of default, env and local files locks each target once" {
  mkconf mise.toml
  mkconf mise.dev.toml
  mkconf mise/config.prod.toml
  mkconf mise.local.toml
  mkconf .config/mise/conf.d/00-base.toml
  run "$SCRIPT" \
    mise.toml mise.dev.toml mise/config.prod.toml mise.local.toml \
    .config/mise/conf.d/00-base.toml
  assert_locks "mise lock" "mise lock --env dev" "mise lock --env prod"
}

@test "no arguments discovers every config in the working directory" {
  mkconf mise.toml
  mkconf mise.dev.toml
  mkconf .config/mise/config.staging.toml
  mkconf .config/mise/conf.d/00-base.toml
  mkconf mise.local.toml
  run "$SCRIPT"
  assert_locks "mise lock" "mise lock --env dev" "mise lock --env staging"
}
