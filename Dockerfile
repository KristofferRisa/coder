# Dockerfile for Coder Development Environment
# This image includes all dependencies pre-installed for fast workspace startup

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone (optional, adjust as needed)
ENV TZ=UTC

# Set versions (can be overridden at build time)
ARG BUN_VERSION=latest
ARG BITWARDEN_CLI_VERSION=latest

# Install core dependencies
RUN apt-get update && apt-get install -y \
    # Version control
    git \
    # Network tools
    curl \
    wget \
    # Archive tools
    unzip \
    zip \
    # Editors
    neovim \
    # Terminal multiplexer
    tmux \
    # Shell
    zsh \
    # Dotfiles management
    stow \
    # Build essentials (useful for compiling tools)
    build-essential \
    # Additional utilities
    jq \
    ripgrep \
    fd-find \
    fzf \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for development (Coder best practice)
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/zsh \
    # Add user to sudoers (if needed)
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*

# Switch to non-root user for remaining installations
USER $USERNAME
WORKDIR /home/$USERNAME

# Install Oh-My-Zsh (pre-installed for convenience)
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k theme (optional, remove if not needed)
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install Bun.sh
RUN curl -fsSL https://bun.sh/install | bash

# Add Bun to PATH for subsequent layers
ENV BUN_INSTALL="/home/$USERNAME/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Install Bitwarden CLI
RUN BW_VERSION=$(curl -s https://api.github.com/repos/bitwarden/clients/releases/latest | grep '"tag_name":' | sed -E 's/.*"cli-v([^"]+)".*/\1/') \
    && wget -q "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" \
    && unzip -q "bw-linux-${BW_VERSION}.zip" \
    && mkdir -p ~/.local/bin \
    && mv bw ~/.local/bin/ \
    && chmod +x ~/.local/bin/bw \
    && rm "bw-linux-${BW_VERSION}.zip"

# Add local bin to PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Verify installations
RUN git --version \
    && nvim --version \
    && tmux -V \
    && zsh --version \
    && stow --version \
    && bun --version \
    && bw --version

# Set default shell to zsh
SHELL ["/bin/zsh", "-c"]

# Default working directory (Coder will override this)
WORKDIR /home/$USERNAME

# Expose common ports (optional, adjust as needed)
# EXPOSE 3000 8080 8000

# Add labels for metadata
LABEL maintainer="kristofferrisa"
LABEL description="Coder development environment with pre-installed tools"
LABEL version="1.0"

# Note: Dotfiles will be cloned and linked at workspace startup via Coder's startup_script
# This keeps the image generic and allows dotfiles to be updated independently
