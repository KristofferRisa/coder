# Dockerfile for Coder Development Environment
# This image includes all dependencies pre-installed for fast workspace startup
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone (optional, adjust as needed)
ENV TZ=UTC

# Set versions (can be overridden at build time)
ARG BUN_VERSION=latest

# Install core dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    zip \
    tmux \
    zsh \
    stow \
    build-essential \
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

# Install Neovim (latest stable release)
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    && sudo rm -rf /opt/nvim-linux-x86_64 \
    && sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz \
    && sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
    && rm nvim-linux-x86_64.tar.gz


# Install Oh-My-Zsh (pre-installed for convenience)
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k theme (optional, remove if not needed)
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install Bun.sh
RUN curl -fsSL https://bun.sh/install | bash

# Add Bun to PATH for subsequent layers
ENV BUN_INSTALL="/home/$USERNAME/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Install Node.js LTS (via NodeSource)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - \
    && sudo apt-get install -y nodejs \
    && sudo rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
# RUN npm install -g @anthropic-ai/claude-code

# Add local bin to PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Verify installations
RUN git --version \
    && nvim --version \
    && tmux -V \
    && zsh --version \
    && stow --version \
    && bun --version \
    && node --version \
    && npm --version 

# Set default shell to zsh
SHELL ["/bin/zsh", "-c"]

# Default working directory (Coder will override this)
WORKDIR /home/$USERNAME

# Expose common ports (optional, adjust as needed)
# EXPOSE 3000 8080 8000


# Note: Dotfiles will be cloned and linked at workspace startup via Coder's startup_script
# This keeps the image generic and allows dotfiles to be updated independently
