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
      sudo apt-get update -qq
      
      echo "📦 Installing base tools..."
      sudo apt-get install -y -qq \
        curl wget git httpie stow zsh build-essential \
        ca-certificates gnupg lsb-release \
        software-properties-common apt-transport-https \
        unzip tar gzip xz-utils \
        python3 python3-pip \
        jq ripgrep fd-find bat fzf tmux
      
      # Setup bat and fd symlinks (Debian uses different names)
      mkdir -p ~/.local/bin
      ln -sf /usr/bin/batcat ~/.local/bin/bat || true
      ln -sf /usr/bin/fdfind ~/.local/bin/fd || true
      
      # echo "📦 Installing Neovim (latest)..."
      # curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      # sudo rm -rf /opt/nvim-linux-x86_64
      # sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
      # sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
      # rm nvim-linux-x86_64.tar.gz
      # echo "✅ Neovim installed"
      
      # echo "📦 Installing LazyGit..."
      # LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
      # curl -sLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_$${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
      # tar xf lazygit.tar.gz lazygit
      # sudo install lazygit /usr/local/bin
      # rm lazygit lazygit.tar.gz
      # echo "✅ LazyGit installed"
      
      # echo "📦 Installing eza (modern ls replacement)..."
      # sudo mkdir -p /etc/apt/keyrings
      # wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
      # echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
      # sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
      # sudo apt-get update -qq
      # sudo apt-get install -y -qq eza
      # echo "✅ eza installed"
      
      # echo "📦 Installing GitHub CLI..."
      # curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
      #   sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      # sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      # echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
      #   sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      # sudo apt-get update -qq
      # sudo apt-get install -y -qq gh
      # echo "✅ GitHub CLI installed"
      
      echo "📦 Installing Node.js 20..."
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y -qq nodejs
      echo "✅ Node.js installed"
      
      # echo "📦 Installing Claude Code..."
      # npm install -g @anthropic-ai/claude-code --silent
      # echo "✅ Claude Code installed"
      #
      # echo "📦 Installing OpenCode..."
      # npm install -g @opencode/cli --silent
      # echo "✅ OpenCode installed"
      
      # echo "📦 Installing zoxide (smarter cd)..."
      # curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
      # echo "✅ zoxide installed"
      
      # echo "🐚 Setting zsh as default shell..."
      # sudo chsh -s /bin/zsh coder || true
      
      touch ~/.tools_installed
      echo "✅ All tools installed successfully!"
    else
      echo "✅ Tools already installed, skipping..."
    fi
    
    # # Configure git
    # echo "⚙️  Configuring git..."
    # git config --global user.name "${coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)}"
    # git config --global user.email "${data.coder_workspace_owner.me.email}"
    # git config --global init.defaultBranch main
    # git config --global pull.rebase false
    # git config --global core.editor nvim
    # git config --global core.pager delta
    # git config --global interactive.diffFilter "delta --color-only"
    # git config --global delta.navigate true
    # git config --global delta.light false
    # git config --global merge.conflictstyle diff3
    # git config --global diff.colorMoved default
    #
    cd "$HOME"
    
    # Install oh-my-zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
      echo "🎨 Installing oh-my-zsh..."
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
      echo "✅ oh-my-zsh installed"
    fi
    
    # Install useful zsh plugins
    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
    
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
      echo "📦 Installing zsh-autosuggestions..."
      git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
    fi
    
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
      echo "📦 Installing zsh-syntax-highlighting..."
      git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
    fi
    
    if [ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]; then
      echo "📦 Installing fzf-tab..."
      git clone https://github.com/Aloxaf/fzf-tab $ZSH_CUSTOM/plugins/fzf-tab
    fi
    
    coder dotfiles https://github.com/KristofferRisa/dotfiles.git
    # Create config directories
    mkdir -p ~/.config/opencode
    mkdir -p ~/.config/nvim
    mkdir -p ~/.config/lazygit
    
    # Setup PATH additions
    echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> ~/.zshrc || true
    
    # Setup zoxide in zsh if not already done
    if ! grep -q "zoxide init" ~/.zshrc 2>/dev/null; then
      echo 'eval "$(zoxide init zsh)"' >> ~/.zshrc
    fi
    
    echo ""
    echo "✨ Workspace ready!"
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

module "filebrowser" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/filebrowser/coder"
  version  = "1.1.3"
  agent_id = coder_agent.main.id
}

module "git-commit-signing" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-commit-signing/coder"
  version  = "1.0.32"
  agent_id = coder_agent.main.id
}

module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/dotfiles/coder"
  version  = "1.2.3"
  agent_id = coder_agent.main.id
  default_dotfiles_uri="https://github.com/KristofferRisa/dotfiles"
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

