# Molecule Testing

## Molecule Platforms

| Platform | Image | Notes |
| --- | --- | --- |
| `xvfb-default-alpine-latest` | `i386/alpine:latest` | 32-bit Alpine, uses `apk` |
| `xvfb-default-debian-latest` | `debian:latest` | Uses `apt` |
| `xvfb-default-nixos-latest` | Custom Dockerfile from `nixos/nix:latest` | Requires `pre_build_image: false` |
| `xvfb-default-ubuntu-jammy` | `ubuntu:jammy` | Uses `apt` |
| `xvfb-default-ubuntu-noble` | `ubuntu:noble` | Uses `apt` |
| `xvfb-default-ubuntu-latest` | `ubuntu:latest` | Uses `apt` |

Platform names follow the `<role>-<scenario>-<platform>` convention (e.g.
`xvfb-default-debian-latest`) because Molecule's Docker driver names each
container exactly after its platform. Generic names such as `debian-latest`
would collide with concurrent Molecule runs of other roles or scenarios.

## Running Tests

Molecule and Ansible are installed via the project `Pipfile`, so run every
command through `pipenv` (they are not on `PATH`):

```bash
# Install/refresh dependencies (first run)
pipenv install

# Full test suite (all platforms)
pipenv run molecule test

# Single platform
pipenv run molecule test --platform-name xvfb-default-debian-latest

# Syntax check only
pipenv run molecule syntax

# Lint only
pre-commit run -a
```

When asked to run molecule test, follow the step-by-step instructions in
[`.github/prompts/molecule-test.prompt.md`](../.github/prompts/molecule-test.prompt.md).

### Sandboxed / firewalled environments

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

## Test Sequence

`dependency -> destroy -> syntax -> create -> prepare -> converge -> idempotence -> verify -> destroy`

## Troubleshooting Matrix

### Molecule prepare fails with DNS resolution errors

> `Temporary failure resolving 'deb.debian.org'` (or `azure.archive.ubuntu.com`), followed by
> `E: Unable to locate package python3` during the `prepare` step.

- **Root cause**: `docker0` has lost the `bridge` network's configured gateway address, so containers
  on the default bridge have no working gateway and cannot resolve DNS or reach the network.
- **Check**: `ip -4 addr show docker0` vs
  `docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'`.
  If the gateway address is missing from `docker0`, this is the cause.
- **Fix (durable)**: `sudo systemctl restart docker` recreates `docker0` with the configured gateway.
  This restarts the daemon and stops any running containers.
- **Fix (non-disruptive, not persistent)**: `sudo ip addr add 172.17.0.1/16 dev docker0`
  (use the gateway reported by the check above).
- **Workaround (no sudo)**: run the tests on the host network, which bypasses the broken bridge.

```bash
MOLECULE_DOCKER_NETWORK=host \
MOLECULE_DOCKER_FORCE_IPV4=true \
MOLECULE_XVFB_DISPLAY_BASE=90 \
pipenv run molecule test
```

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
