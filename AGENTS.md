# AGENTS.md

Agent guidance for the `ansible-role-xvfb` Ansible role.

For project overview and install instructions, see [README.md](README.md).

## Setup & Environment Invariants

- Python 3.10+ required; Pipfile pins `python_version = "3.10"` but 3.11/3.12 work via virtualenv.
- Install dependencies: `pip install -r .devcontainer/requirements.txt`.
- Ansible collections: `ansible-galaxy install -r requirements.yml`.
- Required collections: `community.docker`, `community.general >= 10.6.0`.
- `community.docker` MUST be installed before Molecule can create/destroy containers.
- `community.general.from_ini` filter requires `community.general >= 10.6.0`.

## Key Files & Context Injection

| Path | Purpose |
| --- | --- |
| `defaults/main.yml` | Role defaults (`xvfb_display`, `xvfb_install_x11_utils`, `xvfb_service_enabled`) |
| `vars/main.yml` | NixOS package list for `nix-env` installs |
| `tasks/main.yml` | Entry point; dispatches to OS-family task file |
| `tasks/{Alpine,Debian,NixOS}.yml` | OS-specific install + supervisor setup |
| `tasks/supervisord.yml` | Supervisor config detection, template rendering, daemon start |
| `handlers/main.yml` | `supervisorctl` restart/present handlers |
| `molecule/default/molecule.yml` | Molecule scenario config (platforms, provisioner, test sequence) |
| `molecule/default/{prepare,converge,verify}.yml` | Molecule playbooks |
| `molecule/resources/playbooks/Dockerfile.j2` | NixOS container build template |
| `requirements.yml` | Ansible Galaxy collection dependencies |
| `.pre-commit-config.yaml` | Pre-commit hooks (yamllint, ansible-lint, j2lint, etc.) |
| `.github/prompts/molecule-test.prompt.md` | Step-by-step Molecule test runner prompt |
| `.ansible-lint` | Ansible-lint configuration |
| `.yamllint` | YAML lint rules (max line length 120) |
| `.markdownlint.yaml` | Markdown lint rules (max line length 120) |

## Agent Directives

- MUST use FQCN for all modules (`ansible.builtin.*`, `community.general.*`).
- MUST keep YAML keys sorted alphabetically in config files when possible.
- MUST ensure idempotency in all Ansible tasks.
- MUST wrap lines at 120 characters (YAML and Markdown).
- MUST end files with a newline character.
- MUST use `true`/`false` for truthy values (not `yes`/`no`).
- NEVER hardcode sensitive information; use variables.
- NEVER remove or modify unrelated tests.
- On variable changes, update both `defaults/main.yml` and `README.md`.

## Testing & Verification Gates

### Molecule Platforms

| Platform | Image | Notes |
| --- | --- | --- |
| `alpine-latest` | `i386/alpine:latest` | 32-bit Alpine, uses `apk` |
| `debian-latest` | `debian:latest` | Uses `apt` |
| `nixos-latest` | Custom Dockerfile from `nixos/nix:latest` | Requires `pre_build_image: false` |
| `ubuntu-jammy` | `ubuntu:jammy` | Uses `apt` |
| `ubuntu-noble` | `ubuntu:noble` | Uses `apt` |
| `ubuntu-latest` | `ubuntu:latest` | Uses `apt` |

### Running Tests

When asked to run molecule test, follow the step-by-step instructions in
[`.github/prompts/molecule-test.prompt.md`](.github/prompts/molecule-test.prompt.md).

```bash
# Full test suite (all platforms)
molecule test

# Single platform
molecule test --platform-name debian-latest

# Syntax check only
molecule syntax

# Lint only
pre-commit run -a
```

### Test Sequence

`dependency -> cleanup -> destroy -> syntax -> create -> prepare -> converge ->
idempotence -> side_effect -> verify -> cleanup -> destroy`

## Troubleshooting Matrix

### `community.docker.docker_container` module not found

> Molecule destroy/create fails with:
> `ERROR! couldn't resolve module/action 'community.docker.docker_container'`

- **Root cause**: `community.docker` collection not installed in the execution
  environment.
- **Fix**: Run `ansible-galaxy collection install -r requirements.yml` before
  `molecule test`. In CI, the `gofrolist/molecule-action` container must have
  the collection pre-installed or an install step must precede the test step.
- **CI context**: The Molecule workflow uses `gofrolist/molecule-action@v2`;
  ensure the `Install Ansible collections` step runs before the molecule step.

### Alpine Docker build TLS errors

> `WARNING: updating and opening https://dl-cdn.alpinelinux.org/...
> TLS: unspecified error`

- **Root cause**: Sandboxed/firewalled environments block or MITM Alpine
  CDN TLS connections. The `i386/alpine:latest` image uses musl-based TLS
  which is more sensitive to CA certificate issues.
- **Fix (CI)**: Runs normally on GitHub Actions runners with direct internet.
- **Fix (local)**: Ensure Docker daemon has valid CA certificates and the
  host can reach `dl-cdn.alpinelinux.org`. If behind a corporate proxy,
  inject CA certs into the Docker build context.

### Alpine bootstrap fails with TLS error

- **Root cause**: Alpine `apk update` fails with `TLS: unspecified error` when behind an SSL-intercepting proxy
  if the proxy CA is not in the build-time trust store.
- **Fix**: The custom `Dockerfile.j2` injects host CA certificates directly into `/etc/ssl/cert.pem`
  during the build phase so `apk` can fetch dependencies safely.
- **Prevention**: Verify `dl-cdn.alpinelinux.org` is reachable from inside the container.

### NixOS Docker build SSL failures

> `error: unable to download 'https://channels.nixos.org/nixpkgs-unstable':
> SSL peer certificate or SSH remote key was not OK (60)`

- **Root cause**: Same as Alpine TLS issue; sandboxed environments with
  MITM proxies or missing CA bundles break `nix-channel --update`.
- **Fix (CI)**: Runs normally on GitHub Actions runners.
- **Fix (local)**: Ensure valid CA certificates. If behind proxy, set
  `NIX_SSL_CERT_FILE` or inject certs into the NixOS Docker image.

### NixOS containerd symlink error

> `path escapes from parent` during NixOS container creation.

- **Root cause**: containerd >= 2.2.0 / Go 1.24 rejects absolute symlinks
  in `/etc/passwd` and `/etc/group` that point into `/nix/store`.
- **Fix**: The `Dockerfile.j2` template converts these to relative symlinks
  via `realpath --relative-to`. See `molecule/resources/playbooks/Dockerfile.j2`.
- **Reference**: <https://github.com/containerd/containerd/issues/12683>

### molecule-docker broken conditionals deprecation

> `DEPRECATION WARNING: Conditional result (True) was derived from value
> of type 'str'`

- **Root cause**: `molecule-docker 2.1.0` create/destroy playbooks use
  `when: (lookup('env', 'HOME'))` which is a string, not boolean. This
  becomes an error in `ansible-core >= 2.23`.
- **Workaround**: `molecule.yml` sets   `allow_broken_conditionals: true` in
  `provisioner.config_options.defaults`. See:
  <https://github.com/ansible-community/molecule-plugins/issues/320>
- **Long-term fix**: Wait for upstream `molecule-docker` patch.

### GitHub Actions Molecule report step fails with summary size limit

- **Root cause**: GitHub job summaries are capped at 1 MiB, but full Molecule HTML-to-Markdown conversions can exceed it.
- **Fix**: Upload full Molecule HTML reports as workflow artifacts and append only a concise filtered summary
  (e.g., Play Recap, errors, and warnings) to `$GITHUB_STEP_SUMMARY`.

### Molecule report `EACCES: permission denied`

- **Root cause**: The report file generated by `gofrolist/molecule-action` is owned by root with restricted permissions
  because it is created inside a Docker container.
- **Fix**: Run `sudo chown "$USER":"$USER"` on the report file before attempting to read it (for summary) or upload it.

### Pipfile requires Python 3.10

> `Warning: Python 3.10 was not found on your system...`

- **Root cause**: `Pipfile` pins `python_version = "3.10"` but the host
  has a different Python version.
- **Fix**: Use a virtualenv with `pip install -r .devcontainer/requirements.txt`
  instead of `pipenv`. Or install Python 3.10 via `pyenv`/`asdf`.

### Prepare playbook Ubuntu mirror redirect

> The prepare playbook rewrites Ubuntu `sources.list` to use
> `azure.archive.ubuntu.com` for faster downloads in Azure-hosted runners.

- **Context**: This is intentional for CI speed. If running locally on
  non-Azure networks, the redirect is still functional but may be slower.
- **File**: `molecule/default/prepare.yml`

## Common Tasks

### Before Each Commit

- Verify changes: `git diff --no-color`.
- NEVER use `git add .` without reviewing staged files.
- Run linters: `pre-commit run -a`.

### Linting and Validation

```bash
# All pre-commit checks
pre-commit run -a

# Individual checks
pre-commit run yamllint -a
pre-commit run ansible-lint -a
pre-commit run markdownlint -a
pre-commit run j2lint -a
```

### Editing Files

- Max line length: 120 characters (enforced by `.yamllint` and `.markdownlint.yaml`).
- YAML indentation: 2 spaces.
- End all files with a newline.
- Keep lists and keys in lexicographical order when possible.

### Adding or Modifying Workflows

- Workflows live in `.github/workflows/`.
- Use `actionlint` to validate workflow syntax.
- Molecule workflow uses `gofrolist/molecule-action@v2` with per-platform matrix.
- `paths-ignore` excludes `**.md`, `**.cfg`, `.*`, `LICENSE`, `Pipfile*` from triggers.

## References

- Project documentation: [README.md](README.md)
- Agent conventions: [.github/copilot-instructions.md](.github/copilot-instructions.md)
- Molecule docs: <https://docs.ansible.com/projects/molecule/>
- Ansible lint rules: <https://docs.ansible.com/projects/lint/rules/>
- Org baseline: <https://github.com/Cogni-AI-OU/.github/blob/main/AGENTS.md>
