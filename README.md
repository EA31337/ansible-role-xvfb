# Ansible Role: Xvfb

[![License][license-badge]][license-link]
[![Check][check-badge]][check-link]
[![Dev][dev-badge]][dev-link]
[![Molecule][molecule-badge]][molecule-link]
[![Pull Requests][pr-badge]][pr-link]
[![Test][test-badge]][test-link]
[![Edit][gh-edit-badge]][gh-edit-link]

Ansible role to install Xvfb (X virtual framebuffer) on UNIX-like platforms.

## Requirements

This role requires:

- Ansible
- Python
- Administrative/root access on target hosts
- One of the following operating systems:
  - Alpine Linux
  - Debian/Ubuntu
  - NixOS or systems with Nix package manager

## Install

### Install from Ansible Galaxy

To install this role from Ansible Galaxy, run the following command:

```console
ansible-galaxy install ea31337.xvfb
```

### Install from GitHub

To install this role, you can use the following terminal command:

```shell
ansible-galaxy install git+https://github.com/EA31337/ansible-role-xvfb.git
```

## Role Variables

For available variables,
check [`defaults/main.yml`][defaults-link].

## Testing

### Docker

Steps to test role on Docker containers.

1. Install the current role by running the following commands in shell:

    ```shell
    ansible-galaxy install -r requirements.yml
    jinja2 requirements-local.yml.j2 -D "pwd=$PWD" -o requirements-local.yml
    ansible-galaxy install -r requirements-local.yml
    ```

    Alternatively, for development purposes, you can consider using symbolic link, e.g.

    ```shell
    ln -vs "$PWD" ~/.ansible/roles/ea31337.xvfb
    ```

2. Ensure Docker service (e.g. Docker Desktop) is running.
3. Run playbook from `tests/`:

    ```shell
    ansible-playbook -i tests/inventory/docker-containers.yml tests/playbooks/docker-containers.yml
    ```

### Molecule

To test using Molecule, run:

```shell
molecule test
```

## License

GNU GPL v3

See: [LICENSE](./LICENSE)

<!-- Named links -->

[license-badge]: https://img.shields.io/badge/license-GPLv3-brightgreen.svg
[license-link]: ./LICENSE
[check-badge]: https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/check.yml?label=Check
[check-link]: https://github.com/EA31337/ansible-role-xvfb/actions/workflows/check.yml
[dev-badge]: https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/devcontainer-ci.yml?label=Dev
[dev-link]: https://github.com/EA31337/ansible-role-xvfb/actions/workflows/devcontainer-ci.yml
[molecule-badge]: https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/molecule.yml?label=Molecule
[molecule-link]: https://github.com/EA31337/ansible-role-xvfb/actions/workflows/molecule.yml
[pr-badge]: https://img.shields.io/github/issues-pr/EA31337/ansible-role-xvfb.svg
[pr-link]: https://github.com/EA31337/ansible-role-xvfb/pulls
[test-badge]: https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/test.yml?label=Test
[test-link]: https://github.com/EA31337/ansible-role-xvfb/actions/workflows/test.yml
[gh-edit-badge]: https://img.shields.io/badge/GitHub-edit-purple.svg?logo=github
[gh-edit-link]: https://github.dev/EA31337/ansible-role-xvfb
[defaults-link]: defaults/main.yml
