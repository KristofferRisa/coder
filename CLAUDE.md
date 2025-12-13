# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Coder workspace templates for Docker-based development environments. The main components are:

- **Dockerfile**: Pre-built development container image with common tools (git, zsh, tmux, neovim, bun, etc.)
- **template/main.tf**: Terraform configuration that provisions Coder workspaces using Docker containers

## Architecture

### Docker Image Strategy

The Dockerfile (`/Dockerfile`) creates a base image that pre-installs development tools to minimize workspace startup time. Key aspects:

- Base: Ubuntu 22.04
- Non-root user: `coder` (UID/GID 1000)
- Pre-installed: git, neovim, tmux, zsh, stow, bun, ripgrep, fd-find, fzf
- Shell: zsh with oh-my-zsh and powerlevel10k theme
- Philosophy: Heavy tools are baked into the image; user-specific config (dotfiles) is cloned at workspace startup

### Terraform Template Architecture

The `template/main.tf` file defines the Coder workspace template with these key resources:

1. **coder_agent**: Runs inside the Docker container, handles IDE connections and workspace management
   - Startup script installs additional tools on first run (cached via `~/.tools_installed` flag)
   - Clones dotfiles from `https://github.com/KristofferRisa/dotfiles.git`
   - Configures zsh plugins (autosuggestions, syntax-highlighting, fzf-tab)

2. **docker_volume**: Named volume `coder-{workspace_id}-home` persists the `/home/coder` directory across workspace rebuilds

3. **docker_container**: The actual workspace container
   - Uses `codercom/enterprise-base:ubuntu` image (note: Dockerfile builds `kristofferdev/coder`, but template uses different base)
   - Mounts home volume to `/home/coder`
   - Mounts Docker socket to `/var/run/docker.sock` for Docker-in-Docker support
   - Hostname mapped via `host.docker.internal`

4. **Modules**: Code-server (VS Code in browser), filebrowser, git-commit-signing, dotfiles

## Building and Deploying

### Build Docker Image

```bash
docker build -t kristofferdev/coder:latest .
```

The Dockerfile build process:
- Installs system dependencies via apt
- Creates non-root `coder` user with sudo privileges
- Pre-installs oh-my-zsh and powerlevel10k
- Installs bun.sh

### Deploy Template to Coder

The template is deployed via Terraform when creating/updating Coder workspaces. The Coder server applies this template.

**Important**: The template currently references `codercom/enterprise-base:ubuntu` (line 281 in main.tf), NOT the custom-built `kristofferdev/coder` image from the Dockerfile. To use the custom image, update:

```terraform
image = "kristofferdev/coder:latest"
```

## Development Notes

### Startup Script Caching

The startup script uses flag files to prevent re-running expensive operations:
- `~/.init_done`: Initial home directory setup completed
- `~/.tools_installed`: Additional tools (Node.js, zsh plugins) installed

These persist in the Docker volume across workspace restarts.

### Commented-out Tools

Several tool installations are commented out in both Dockerfile and main.tf:
- Bitwarden CLI
- LazyGit
- eza
- GitHub CLI
- Claude Code CLI
- OpenCode CLI
- Neovim (template installs it, but Dockerfile has it uncommented)

Uncomment these sections as needed.

### Docker Socket Access

Workspaces have access to the host's Docker socket, enabling Docker-in-Docker workflows. This allows running Docker commands inside the workspace.

## File Structure

```
.
├── Dockerfile              # Custom development image definition
├── template/
│   ├── main.tf            # Coder workspace template (Terraform)
│   └── dev.tf             # (appears empty or minimal)
└── README.md              # (minimal, just says "coder")
```
