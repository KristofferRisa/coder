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
    sudo apt-get update -qq

    # Prepare user home with default files on first start
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi
      
    echo "📦 Installing Neovim (latest)..."
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm nvim-linux-x86_64.tar.gz
    echo "✅ Neovim installed"
    
    echo "📦 Installing LazyGit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -sLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_$${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit /usr/local/bin
    rm lazygit lazygit.tar.gz
    echo "✅ LazyGit installed"
    
    echo "📦 Installing zoxide (smarter cd)..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    echo "✅ zoxide installed"
    
    echo "🐚 Setting zsh as default shell..."
    sudo chsh -s /bin/zsh coder || true
  
    echo "Installing hugo"
    LATEST="$(curl -fsSL https://api.github.com/repos/gohugoio/hugo/releases/latest | grep -Po '"tag_name":\s*"\Kv[^"]+')"
    URL="$(curl -fsSL https://api.github.com/repos/gohugoio/hugo/releases/latest \
  | grep -Po '"browser_download_url":\s*"\K[^"]+' \
  | grep -E 'hugo_extended_.*linux-amd64\.tar\.gz|hugo_extended_.*Linux-64bit\.tar\.gz' \
  | head -n 1)"

    echo "Installing Hugo $LATEST from $URL"
    curl -fsSL "$URL" -o /tmp/hugo.tar.gz
    sudo tar -C /usr/local/bin -xzf /tmp/hugo.tar.gz hugo
    rm -f /tmp/hugo.tar.gz
    echo "✅ Installed hugo"
    
    # Configure git
    echo "⚙️  Configuring git..."
    git config --global user.name "${data.coder_workspace_owner.me.full_name}"
    git config --global user.email "${data.coder_workspace_owner.me.email}"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.editor nvim
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.light false
    git config --global merge.conflictstyle diff3
    git config --global diff.colorMoved default
    
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
    
    if [ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]; then
      echo "📦 Installing fzf-tab..."
      git clone https://github.com/Aloxaf/fzf-tab $ZSH_CUSTOM/plugins/fzf-tab
    fi
    
    # Setup PATH additions
    echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> ~/.zshrc || true
    
    # Setup zoxide in zsh if not already done
    if ! grep -q "zoxide init" ~/.zshrc 2>/dev/null; then
      echo 'eval "$(zoxide init zsh)"' >> ~/.zshrc
    fi
    
    #source .config/zsh/.zshrc

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

module "nodejs" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/thezoker/nodejs/coder"
  version  = "1.0.13"
  agent_id = coder_agent.main.id
}

module "git-commit-signing" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-commit-signing/coder"
  version  = "1.0.32"
  agent_id = coder_agent.main.id
}

module "claude-code" {
  source         = "registry.coder.com/coder/claude-code/coder"
  version        = "4.3.0"
  agent_id       = coder_agent.main.id
  workdir        = "/home/coder/ai"
  #claude_api_key = "xxxx-xxxxx-xxxx"
}

module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/dotfiles/coder"
  version  = "1.2.3"
  agent_id = coder_agent.main.id
  default_dotfiles_uri="https://github.com/KristofferRisa/dotfiles.git"
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
  image    = "ghcr.io/kristofferrisa/coder:latest"
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

