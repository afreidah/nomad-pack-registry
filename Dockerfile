# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Docker image for nomad-pack testing and validation. Includes Nomad,
# nomad-pack, checkov, and all required system dependencies.
# -------------------------------------------------------------------------------

FROM debian:bookworm-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    python3-pip \
    git \
    gnupg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Nomad
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y nomad && \
    rm -rf /var/lib/apt/lists/*

# Install nomad-pack
RUN curl -fsSL https://releases.hashicorp.com/nomad-pack/0.2.0/nomad-pack_0.2.0_linux_amd64.zip \
    -o /tmp/nomad-pack.zip && \
    unzip -o /tmp/nomad-pack.zip -d /tmp && \
    mv /tmp/nomad-pack /usr/local/bin/ && \
    rm /tmp/nomad-pack.zip

# Install checkov
RUN pip3 install checkov --break-system-packages

WORKDIR /workspace
