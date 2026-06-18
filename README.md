# pre-commit-mise-lock

A [pre-commit](https://pre-commit.com) hook that keeps your [mise](https://mise.jdx.dev)
lockfile (`mise.lock`) up to date. Whenever a mise configuration file is staged for
commit, the hook runs `mise lock` so the lockfile never drifts away from your config.

## Requirements

- [`mise`](https://mise.jdx.dev) available on `PATH`
- [`pre-commit`](https://pre-commit.com) (or a compatible runner such as
  [`prek`](https://github.com/j178/prek))
- A mise config with `lockfile = true` enabled, e.g.:

  ```toml
  [settings]
  lockfile = true
  ```

## Usage

Add the hook to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/lohn/pre-commit-mise-lock
    rev: v0.1.0 # use the latest tag
    hooks:
      - id: mise-lock
```

Then install the hook:

```sh
pre-commit install
```

From now on, committing a change to any tracked mise configuration regenerates
`mise.lock` automatically.

## What gets locked

The hook triggers on the standard locations mise loads configuration from. The `*`
(except in `conf.d/*.toml`) corresponds to a `MISE_ENV` environment name:

| Pattern                          | Lock target             |
| -------------------------------- | ----------------------- |
| `mise.toml`                      | default (`mise lock`)   |
| `mise.<env>.toml`                | `mise lock --env <env>` |
| `mise/config.toml`               | default                 |
| `mise/config.<env>.toml`         | `mise lock --env <env>` |
| `.mise/config.toml`              | default                 |
| `.mise/config.<env>.toml`        | `mise lock --env <env>` |
| `.config/mise.toml`              | default                 |
| `.config/mise.<env>.toml`        | `mise lock --env <env>` |
| `.config/mise/config.toml`       | default                 |
| `.config/mise/config.<env>.toml` | `mise lock --env <env>` |
| `.config/mise/conf.d/*.toml`     | default                 |

### Exclusions

`*.local.toml` files (e.g. `mise.local.toml`) are local overrides and are **never**
locked, so they are excluded from the hook.

The one exception is `conf.d/`: there, `.local.toml` is just an ordinary filename
with no override semantics, so `.config/mise/conf.d/*.local.toml` files **are** still
locked.

## How it works

The hook runs [`mise-lock.sh`](./mise-lock.sh) with the staged config files as
arguments. The script:

1. Skips any `*.local.toml` override.
2. Maps each remaining file to a lock target — the default config (`mise lock`) or a
   specific environment (`mise lock --env <env>`), based on its name.
3. Runs `mise lock` for the default config and once per affected environment.

Running `mise-lock.sh` with no arguments discovers every supported config in the
current directory and locks them all, which is handy for a one-off refresh.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the development setup, testing, and
contribution conventions.

## License

MIT
