# Ansible Role: Xvfb

[![Check](https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/check.yml?label=Check)](https://github.com/EA31337/ansible-role-xvfb/actions/workflows/check.yml)
[![Dev](https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/devcontainer-ci.yml?label=Dev)](https://github.com/EA31337/ansible-role-xvfb/actions/workflows/devcontainer-ci.yml)
[![Molecule](https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/molecule.yml?label=Molecule)](https://github.com/EA31337/ansible-role-xvfb/actions/workflows/molecule.yml)
[![Test](https://img.shields.io/github/actions/workflow/status/EA31337/ansible-role-xvfb/test.yml?label=Test)](https://github.com/EA31337/ansible-role-xvfb/actions/workflows/test.yml)
[![Pull Requests](https://img.shields.io/github/issues-pr/EA31337/ansible-role-xvfb.svg)](https://github.com/EA31337/ansible-role-xvfb/pulls)
[![License](https://img.shields.io/badge/license-GPLv3-brightgreen.svg)](LICENSE)

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
check [`defaults/main.yml`](defaults/main.yml).

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
