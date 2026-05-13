# Dockerfile for ea31337.xvfb Ansible role
FROM ubuntu:noble

LABEL org.opencontainers.image.source=https://github.com/EA31337/ansible-role-xvfb
LABEL org.opencontainers.image.description="Xvfb (X virtual framebuffer) container based on ea31337.xvfb Ansible role"

ENV DISPLAY=:0
ENV XDG_RUNTIME_DIR=/tmp/runtime-root
ENV DEBIAN_FRONTEND=noninteractive

# Install Ansible and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ansible \
    ca-certificates \
    git \
    lsb-release \
    procps \
    python3-apt \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    sudo \
    wget \
    x11-utils && \
    pip3 install --no-cache-dir "ansible-core>=2.14" --break-system-packages || \
    pip3 install --no-cache-dir "ansible-core>=2.14" && \
    rm -rf /var/lib/apt/lists/*

# Copy the role into the container
WORKDIR /etc/ansible/roles/ea31337.xvfb
COPY defaults/ defaults/
COPY handlers/ handlers/
COPY meta/ meta/
COPY tasks/ tasks/
COPY templates/ templates/
COPY vars/ vars/
COPY ansible.cfg .
COPY requirements.yml .

# Create a local playbook to apply the role
RUN ansible-galaxy role install -r requirements.yml --force && \
    ansible-galaxy collection install -r requirements.yml --upgrade && \
    printf -- "---\n- hosts: localhost\n  connection: local\n  roles:\n    - role: /etc/ansible/roles/ea31337.xvfb\n  vars:\n    xvfb_service_manage: false\n" > /tmp/playbook.yml && \
    ANSIBLE_PYTHON_INTERPRETER=auto_silent ansible-playbook /tmp/playbook.yml && \
    rm /tmp/playbook.yml && \
    if [ -f /usr/bin/apt-get ]; then \
        export SUDO_FORCE_REMOVE=yes && \
        apt-get update && \
        apt-get purge -y --auto-remove \
            git \
            python3-pip \
            python3-setuptools \
            python3-wheel && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    fi

# Default Xvfb port
EXPOSE 6000

# Start supervisord to manage Xvfb
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
