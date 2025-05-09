# Ansible Role: Xvfb

[![CodeRabbit PR Reviews](https://img.shields.io/coderabbit/prs/github/EA31337/ansible-role-xvfb?utm_source=oss&utm_medium=github&utm_campaign=EA31337%2Fansible-role-xvfb&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+PR+Reviews)](https://github.com/EA31337/ansible-role-xvfb/pulls)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

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
    jinja2 requirements-local.yml.j2 -D "pwd=$PWD" -o requirements-local.yml
    ansible-galaxy install -r requirements-local.yml
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
