
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}
locals {
  username = data.coder_workspace_owner.me.name
}
variable "docker_socket" {
  default     = ""
  description = "(Optional) Docker socket URI"
  type        = string
}
provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  
  startup_script = <<-EOT
    #!/bin/bash
    set -e
    # Prepare user home with default files on first start
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi
    # Install tools on first start (cached after that)
    if [ ! -f ~/.tools_installed ]; then
      echo "🔧 Installing development tools (this runs once)..."
      
      sudo apt-get update -qq
      
      echo "📦 Installing: curl, wget, git, httpie, stow, zsh, build-essential..."
      sudo apt-get install -y -qq \
        curl wget git httpie stow zsh build-essential \
        ca-certificates gnupg lsb-release
      
      # echo "📦 Installing Neovim 0.11.2..."
      # wget -q https://github.com/neovim/neovim/releases/download/v0.11.2/nvim-linux64.tar.gz
      # sudo tar xzf nvim-linux64.tar.gz -C /opt/
      # sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
      # rm nvim-linux64.tar.gz
      
      echo "📦 Installing GitHub CLI..."
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq gh
      
      echo "📦 Installing Node.js 20..."
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y -qq nodejs
      
      # echo "📦 Installing OpenCode..."
      # sudo npm install -g @opencode/cli --silent
      
      echo "🐚 Setting zsh as default shell..."
      sudo chsh -s /bin/zsh coder || true
      
      touch ~/.tools_installed
      echo "✅ Tools installed successfully!"
    else
      echo "✅ Tools already installed, skipping..."
    fi
    # Setup SSH keys (runs every time)
    echo "🔑 Setting up SSH keys..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    ssh-keyscan -t rsa,ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    # Configure git
    echo "⚙️  Configuring git..."
    git config --global user.name "${coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)}"
    git config --global user.email "${data.coder_workspace_owner.me.email}"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.editor nvim
    
    # Clone dotfiles
    DOTFILES_DIR="$HOME/dotfiles"
    if [ ! -d "$DOTFILES_DIR" ]; then
      echo "📦 Cloning dotfiles..."
      git clone git@github.com:KristofferRisa/dotfiles.git "$DOTFILES_DIR" 2>/dev/null || \
      git clone https://github.com/KristofferRisa/dotfiles.git "$DOTFILES_DIR"
      echo "✅ Dotfiles cloned"
    else
      echo "📦 Dotfiles present, pulling latest..."
      cd "$DOTFILES_DIR" && git pull || true
    fi
    
    # Run dotfiles install script
    if [ -f "$DOTFILES_DIR/install.sh" ]; then
      echo "🔧 Running dotfiles install script..."
      cd "$DOTFILES_DIR"
      bash install.sh || echo "⚠️  Dotfiles install had issues, continuing..."
      echo "✅ Dotfiles installed"
    fi
    
    cd "$HOME"
    # Install oh-my-zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
      echo "🎨 Installing oh-my-zsh..."
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
      echo "✅ oh-my-zsh installed"
    fi
    mkdir -p ~/.config/opencode
    echo ""
    echo "✨ Workspace ready!"
    echo "🎯 Tools: opencode, gh, curl, wget, httpie, stow, zsh"
    echo "📁 Dotfiles: ~/dotfiles"
    echo ""
  EOT
  
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }
  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }
}
module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  order    = 1
}
resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  
  lifecycle {
    ignore_changes = all
  }
  
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}
resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = "codercom/enterprise-base:ubuntu"
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name
  
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  
  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = false
  }
  
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
