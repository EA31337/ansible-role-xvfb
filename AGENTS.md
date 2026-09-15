# AGENTS.md

Agent guidance for the `ansible-role-xvfb` Ansible role.

For project overview and install instructions, see [README.md](README.md).
For project facts and architecture mindmap, see [FACTS.mmd](docs/FACTS.mmd).
For execution flows and logic diagrams, see [FLOWS.mmd](docs/FLOWS.mmd).

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
| `.devcontainer/devcontainer.json` | Dev container definition (base image, Features, `onCreateCommand`) |
| `.devcontainer/provision.yml` | Ansible playbook run by `onCreateCommand` to provision the container |
| `.devcontainer/requirements.txt` | Python dependencies installed in the dev container |
| `defaults/main.yml` | Role defaults (`xvfb_display`, `xvfb_install_x11_utils`, `xvfb_service_enabled`) |
| `vars/main.yml` | NixOS package list for `nix-env` installs |
| `tasks/main.yml` | Entry point; dispatches to OS-family task file |
| `tasks/{Alpine,Debian,NixOS}.yml` | OS-specific install + supervisor setup |
| `tasks/supervisord.yml` | Supervisor config detection, template rendering, daemon start |
| `handlers/main.yml` | `supervisorctl` restart/present handlers |
| `molecule/default/molecule.yml` | Molecule scenario config (platforms, provisioner, test sequence) |
| `molecule/default/{prepare,converge,verify}.yml` | Molecule playbooks |
| `molecule/resources/playbooks/Dockerfile.j2` | NixOS container build template |
| `docs/{FACTS,FLOWS}.mmd` | Project facts and execution flow diagrams |
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

### Dev Container Build & Test

The dev container is defined in `.devcontainer/` and is the primary development environment.
`devcontainer.json` uses the `mcr.microsoft.com/devcontainers/base:jammy` image plus devcontainer
Features; its `onCreateCommand` installs Ansible and runs `provision.yml`.

```bash
# Build the image only (base image + Features)
devcontainer build --workspace-folder .

# Build, start the container, and run onCreateCommand (provision.yml)
devcontainer up --workspace-folder .

# Run a command inside the running container
devcontainer exec --workspace-folder . bash -lc 'ansible --version'
```

- `devcontainer build` prints `{"outcome":"success",...}` on success.
- `devcontainer up` additionally returns a `containerId` and a clean Ansible recap (`failed=0`);
  it installs the apt packages, pipx Ansible, collections, and the pre-commit hook from `provision.yml`.

Requirements:

- Docker daemon reachable and the `devcontainer` CLI (v0.89+) installed.
- A working default Docker bridge (see the troubleshooting entry below).
- Outbound access to `ghcr.io`, `.github.com`, `*.githubusercontent.com`, and the apt / PyPI /
  Galaxy hosts. Host firewalls that prompt per connection (e.g. Portmaster) block the `nanolayer`
  downloads long enough to time out - pre-allow those domains.

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

Molecule and Ansible are installed via the project `Pipfile`, so run every
command through `pipenv` (they are not on `PATH`):

```bash
# Install/refresh dependencies (first run)
pipenv install

# Full test suite (all platforms)
pipenv run molecule test

# Single platform
pipenv run molecule test --platform-name debian-latest

# Syntax check only
pipenv run molecule syntax

# Lint only
pre-commit run -a
```

When asked to run molecule test, follow the step-by-step instructions in
[`.github/prompts/molecule-test.prompt.md`](.github/prompts/molecule-test.prompt.md).

#### Sandboxed / firewalled environments

The Molecule Docker playbooks support opt-in environment variables for
environments where the default Docker bridge has no outbound NAT, DNS returns
unroutable IPv6 addresses, or the host already runs an X server on `:0`:

| Variable | Purpose |
| --- | --- |
| `MOLECULE_DOCKER_NETWORK=host` | Run containers and image builds on the host network. |
| `MOLECULE_DOCKER_FORCE_IPV4=true` | Prefer IPv4 for DNS resolution inside containers. |
| `MOLECULE_XVFB_DISPLAY_BASE=90` | Assign a unique X display per host (base + host index). |

```bash
MOLECULE_DOCKER_NETWORK=host \
MOLECULE_DOCKER_FORCE_IPV4=true \
MOLECULE_XVFB_DISPLAY_BASE=90 \
pipenv run molecule test
```

When unset (the default), the playbooks use bridge networking, the container's
default DNS behaviour, and display `:0` - matching CI.

### Test Sequence

`dependency -> destroy -> syntax -> create -> prepare -> converge -> idempotence -> verify -> destroy`

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

### Dev container Feature install fails

> `ERROR: Feature "..." failed to install!` with `curl: (6) Could not resolve host: github.com`
> or `urllib.error.URLError: <urlopen error [Errno 113] No route to host>`

- **Root cause (no network)**: `docker0`'s address does not match the `bridge` network's configured
  gateway, so containers on the default bridge have no working gateway and BuildKit `RUN` steps
  cannot reach the network.
  - **Check**: `ip -4 addr show docker0` vs
    `docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'`.
  - **Fix**: `sudo systemctl restart docker` recreates `docker0` with the configured gateway.
    Non-disruptive workaround (not persistent): `sudo ip addr add <gateway>/16 dev docker0`.
- **Root cause (blocked downloads)**: a host firewall that prompts per connection (e.g. Portmaster)
  blocks `nanolayer`'s `ghcr.io` / `api.github.com` requests while the prompt is pending, and
  `nanolayer` times out first.
  - **Fix**: pre-allow `ghcr.io`, `.github.com`, `*.githubusercontent.com`, and the apt / PyPI /
    Galaxy hosts in the firewall's outgoing rules. `github.com` matches only the apex; use
    `.github.com` to match subdomains such as `api.github.com`.

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

### Updating Pre-commit Hooks

Run `pre-commit autoupdate`, then `pre-commit run -a`. Revert any hook that breaks and file an issue for it.

Known blockers (as of the 2026-09 update):

- `ansible-lint` v26.8.0 declares `language_version: python3.14`. Without a Python 3.14
  interpreter, either keep the ref pinned or override the hook with `language_version: python3`.
- `pre-commit-hooks` v6.0.0 removed `check-byte-order-marker`; replace it with
  `fix-byte-order-marker`.
- `markdownlint-cli` v0.49.1 needs node >= 22.20 (its dev dependency `ava@8`). If the hook pins
  `language_version: 22.14.0`, the env fails to install; pin markdownlint-cli or bump the pinned node.
- `ansible-lint` + `community.docker`: a stale, empty
  `.ansible/collections/ansible_collections/community/docker` directory shadows the real collection
  and causes `couldn't resolve module/action 'community.docker.docker_container'`. Remove it.
- `additional_dependencies` with a version range must use the block form
  (`- ansible-core>=2.16,<2.21`); the inline flow form splits on the comma into separate
  requirements, and the no-space form trips ansible-lint's `yaml[commas]` rule.

`pre-commit run -a` can also surface pre-existing failures (e.g. `yamlfix`/`black` reformatting,
`flake8` violations) unrelated to the ref bump; CI lints only changed files, so file these separately.

### Editing Files

- Max line length: 120 characters (enforced by `.yamllint` and `.markdownlint.yaml`).
- YAML indentation: 2 spaces.
- End all files with a newline.
- Keep lists and keys in lexicographical order when possible.

### Adding or Modifying Workflows

- Workflows live in `.github/workflows/`.
- Use `actionlint` to validate workflow syntax.
- Molecule workflow uses `gofrolist/molecule-action@v2` with per-platform matrix.
- `paths-ignore` excludes `**.md`, `**.mmd`, `**.cfg`, `.*`, `LICENSE`, `Pipfile*` from triggers.

## References

- Project documentation: [README.md](README.md)
- Project facts: [FACTS.mmd](docs/FACTS.mmd)
- Project flows: [FLOWS.mmd](docs/FLOWS.mmd)
- Agent conventions: [.github/copilot-instructions.md](.github/copilot-instructions.md)
- Molecule docs: <https://docs.ansible.com/projects/molecule/>
- Ansible lint rules: <https://docs.ansible.com/projects/lint/rules/>
- Org baseline: <https://github.com/Cogni-AI-OU/.github/blob/main/AGENTS.md>
