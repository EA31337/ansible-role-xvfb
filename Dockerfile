# Dockerfile for ea31337.xvfb Ansible role
FROM ubuntu:noble

LABEL org.opencontainers.image.source=https://github.com/EA31337/ansible-role-xvfb
LABEL org.opencontainers.image.description="Xvfb (X virtual framebuffer) container based on ea31337.xvfb Ansible role"

ENV DEBIAN_FRONTEND=noninteractive

# Install Ansible and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ansible \
    python3-apt \
    python3-pip \
    sudo && \
    rm -rf /var/lib/apt/lists/*

# Copy the role into the container
WORKDIR /etc/ansible/roles/ea31337.xvfb
COPY . .

# Create a local playbook to apply the role
RUN ansible-galaxy collection install -r requirements.yml && \
    printf -- "---\n- hosts: localhost\n  connection: local\n  roles:\n    - ea31337.xvfb\n" > /tmp/playbook.yml && \
    ansible-playbook /tmp/playbook.yml && \
    rm /tmp/playbook.yml

# Default Xvfb port
EXPOSE 6000

# Start supervisord to manage Xvfb
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
