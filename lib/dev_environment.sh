#!/bin/bash
#
# Development Environment Setup Library for Linux Setup
# Implements programming language installation, version managers, and development tools
# User Story 1.5: Development Environment Setup
#

# Global variables for development environment setup
DEV_INSTALL_DIR="$HOME/.local"
DEV_CONFIG_DIR="$HOME/.config"
DEV_CHANGES=()
DEV_ERRORS=()
DEV_WARNINGS=()

# Development environment defaults
INSTALL_PYTHON="${INSTALL_PYTHON:-true}"
INSTALL_NODEJS="${INSTALL_NODEJS:-true}"
INSTALL_GO="${INSTALL_GO:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
SETUP_VIM="${SETUP_VIM:-true}"
SETUP_GIT="${SETUP_GIT:-true}"
DEFAULT_SHELL="${DEFAULT_SHELL:-bash}"

# Function to install Python and development tools
install_python_environment() {
    log_function_enter "install_python_environment"
    log_info "Installing Python development environment"
    
    print_status "progress" "Setting up Python development environment..."
    
    # Install Python 3 and pip
    local python_packages=("python3" "python3-pip" "python3-venv" "python3-dev")
    for package in "${python_packages[@]}"; do
        if ! install_package "$package" "Installing $package"; then
            print_status "warning" "Failed to install $package"
            DEV_WARNINGS+=("Failed to install $package")
        else
            DEV_CHANGES+=("Installed $package")
        fi
    done
    
    # Install pyenv for Python version management
    print_status "progress" "Installing pyenv (Python version manager)..."
    if ! command_exists pyenv; then
        # Install pyenv dependencies
        local pyenv_deps=("make" "build-essential" "libssl-dev" "zlib1g-dev" 
                          "libbz2-dev" "libreadline-dev" "libsqlite3-dev" "wget" 
                          "curl" "llvm" "libncurses5-dev" "xz-utils" "tk-dev" 
                          "libxml2-dev" "libxmlsec1-dev" "libffi-dev" "liblzma-dev")
        
        for dep in "${pyenv_deps[@]}"; do
            install_package "$dep" "Installing pyenv dependency: $dep" >/dev/null 2>&1
        done
        
        # Install pyenv
        if curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer 2>/dev/null | bash; then
            print_status "success" "pyenv installed successfully"
            DEV_CHANGES+=("Installed pyenv Python version manager")
            
            # Add pyenv to PATH and shell configuration
            local pyenv_config='
# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi'
            
            # Add to bash profile
            if [[ -f "$HOME/.bashrc" ]]; then
                if ! grep -q "pyenv init" "$HOME/.bashrc"; then
                    echo "$pyenv_config" >> "$HOME/.bashrc"
                    DEV_CHANGES+=("Added pyenv configuration to .bashrc")
                fi
            fi
            
            # Add to zsh profile if zsh is installed
            if command_exists zsh && [[ -f "$HOME/.zshrc" ]]; then
                if ! grep -q "pyenv init" "$HOME/.zshrc"; then
                    echo "$pyenv_config" >> "$HOME/.zshrc"
                    DEV_CHANGES+=("Added pyenv configuration to .zshrc")
                fi
            fi
        else
            print_status "warning" "Failed to install pyenv"
            DEV_WARNINGS+=("Failed to install pyenv")
        fi
    else
        print_status "info" "pyenv already installed"
    fi
    
    # Install common Python development packages
    print_status "progress" "Installing Python development packages..."
    local python_dev_packages=("virtualenv" "pipenv" "poetry" "black" "flake8" "pytest")
    for package in "${python_dev_packages[@]}"; do
        if python3 -m pip install --user "$package" >/dev/null 2>&1; then
            print_status "info" "Installed Python package: $package"
            DEV_CHANGES+=("Installed Python package: $package")
        else
            print_status "warning" "Failed to install Python package: $package"
            DEV_WARNINGS+=("Failed to install Python package: $package")
        fi
    done
    
    print_status "success" "Python development environment setup completed"
    log_function_exit "install_python_environment" 0
    return 0
}

# Function to install Node.js and development tools
install_nodejs_environment() {
    log_function_enter "install_nodejs_environment"
    log_info "Installing Node.js development environment"
    
    print_status "progress" "Setting up Node.js development environment..."
    
    # Install nvm (Node Version Manager)
    print_status "progress" "Installing nvm (Node.js version manager)..."
    if ! command_exists nvm; then
        # Download and install nvm
        local nvm_version="v0.39.0"
        if curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh" 2>/dev/null | bash; then
            print_status "success" "nvm installed successfully"
            DEV_CHANGES+=("Installed nvm Node.js version manager")
            
            # Source nvm script
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
            
            # Install latest LTS Node.js
            if command_exists nvm; then
                print_status "progress" "Installing Node.js LTS..."
                if nvm install --lts >/dev/null 2>&1; then
                    nvm use --lts >/dev/null 2>&1
                    nvm alias default lts/* >/dev/null 2>&1
                    print_status "success" "Node.js LTS installed and set as default"
                    DEV_CHANGES+=("Installed Node.js LTS via nvm")
                else
                    print_status "warning" "Failed to install Node.js via nvm"
                    DEV_WARNINGS+=("Failed to install Node.js via nvm")
                fi
            fi
        else
            print_status "warning" "Failed to install nvm, trying package manager..."
            DEV_WARNINGS+=("Failed to install nvm")
            
            # Fallback to package manager
            if install_package "nodejs" "Installing Node.js from package manager"; then
                install_package "npm" "Installing npm"
                DEV_CHANGES+=("Installed Node.js and npm from package manager")
            else
                DEV_ERRORS+=("Failed to install Node.js")
            fi
        fi
    else
        print_status "info" "nvm already installed"
    fi
    
    # Install global npm packages
    if command_exists npm; then
        print_status "progress" "Installing Node.js development packages..."
        local npm_packages=("yarn" "typescript" "eslint" "prettier" "nodemon" "@angular/cli" "create-react-app" "vue-cli")
        for package in "${npm_packages[@]}"; do
            if npm install -g "$package" >/dev/null 2>&1; then
                print_status "info" "Installed npm package: $package"
                DEV_CHANGES+=("Installed npm package: $package")
            else
                print_status "warning" "Failed to install npm package: $package"
                DEV_WARNINGS+=("Failed to install npm package: $package")
            fi
        done
    fi
    
    print_status "success" "Node.js development environment setup completed"
    log_function_exit "install_nodejs_environment" 0
    return 0
}

# Function to install Go development environment
install_go_environment() {
    log_function_enter "install_go_environment"
    log_info "Installing Go development environment"
    
    print_status "progress" "Setting up Go development environment..."
    
    # Check if Go is already installed
    if command_exists go; then
        print_status "info" "Go already installed: $(go version)"
        DEV_CHANGES+=("Go already available")
    else
        # Install Go from official source
        print_status "progress" "Installing Go programming language..."
        local go_version="1.21.5"
        local go_arch="arm64"
        
        # Detect architecture
        case "$(uname -m)" in
            x86_64) go_arch="amd64" ;;
            aarch64|arm64) go_arch="arm64" ;;
            armv7l|armhf) go_arch="armv6l" ;;
            i386|i686) go_arch="386" ;;
        esac
        
        local go_tarball="go${go_version}.linux-${go_arch}.tar.gz"
        local go_url="https://golang.org/dl/$go_tarball"
        
        # Download and install Go
        if curl -L -o "/tmp/$go_tarball" "$go_url" 2>/dev/null; then
            # Remove existing Go installation
            sudo rm -rf /usr/local/go
            
            # Extract Go
            if sudo tar -C /usr/local -xzf "/tmp/$go_tarball"; then
                print_status "success" "Go installed successfully"
                DEV_CHANGES+=("Installed Go $go_version")
                
                # Add Go to PATH
                local go_config='
# Go programming language
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH'
                
                # Add to bash profile
                if [[ -f "$HOME/.bashrc" ]]; then
                    if ! grep -q "GOROOT" "$HOME/.bashrc"; then
                        echo "$go_config" >> "$HOME/.bashrc"
                        DEV_CHANGES+=("Added Go configuration to .bashrc")
                    fi
                fi
                
                # Add to zsh profile if zsh is installed
                if command_exists zsh && [[ -f "$HOME/.zshrc" ]]; then
                    if ! grep -q "GOROOT" "$HOME/.zshrc"; then
                        echo "$go_config" >> "$HOME/.zshrc"
                        DEV_CHANGES+=("Added Go configuration to .zshrc")
                    fi
                fi
                
                # Create GOPATH directory
                mkdir -p "$HOME/go/src" "$HOME/go/bin" "$HOME/go/pkg"
                DEV_CHANGES+=("Created Go workspace directories")
                
            else
                print_status "error" "Failed to extract Go"
                DEV_ERRORS+=("Failed to extract Go")
            fi
            
            # Clean up
            rm -f "/tmp/$go_tarball"
        else
            print_status "warning" "Failed to download Go, trying package manager..."
            if install_package "golang-go" "Installing Go from package manager"; then
                DEV_CHANGES+=("Installed Go from package manager")
            else
                DEV_ERRORS+=("Failed to install Go")
            fi
        fi
    fi
    
    print_status "success" "Go development environment setup completed"
    log_function_exit "install_go_environment" 0
    return 0
}

# Function to configure vim for development
configure_vim_development() {
    log_function_enter "configure_vim_development"
    log_info "Configuring vim for development"
    
    print_status "progress" "Configuring vim for development..."
    
    # Ensure vim is installed
    if ! command_exists vim; then
        if ! install_package "vim" "Installing vim"; then
            print_status "error" "Failed to install vim"
            DEV_ERRORS+=("Failed to install vim")
            log_function_exit "configure_vim_development" 1
            return 1
        fi
    fi
    
    # Create vim configuration
    local vimrc="$HOME/.vimrc"
    print_status "progress" "Creating vim configuration..."
    
    cat > "$vimrc" << 'EOF'
" Vim Configuration for Development - Generated by Linux Setup System

" Basic settings
set nocompatible
set number
set relativenumber
set ruler
set showcmd
set showmatch
set hlsearch
set incsearch
set ignorecase
set smartcase
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4
set wrap
set linebreak
set textwidth=80
set colorcolumn=80

" Enable syntax highlighting
syntax enable
filetype plugin indent on

" Color scheme
set background=dark
colorscheme default

" File encoding
set encoding=utf-8
set fileencoding=utf-8

" Backup and swap files
set backup
set backupdir=~/.vim/backup//
set swapfile
set directory=~/.vim/swap//
set undofile
set undodir=~/.vim/undo//

" Create backup directories
silent !mkdir -p ~/.vim/backup ~/.vim/swap ~/.vim/undo

" Status line
set laststatus=2
set statusline=%F%m%r%h%w\ [%Y]\ [%{&ff}]\ [%{&fenc}]\ %=%l,%c\ %p%%

" Key mappings
let mapleader = ","
inoremap jj <Esc>
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :noh<CR>

" Programming language specific settings
autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
autocmd FileType javascript setlocal tabstop=2 shiftwidth=2 expandtab
autocmd FileType html setlocal tabstop=2 shiftwidth=2 expandtab
autocmd FileType css setlocal tabstop=2 shiftwidth=2 expandtab
autocmd FileType go setlocal tabstop=4 shiftwidth=4 noexpandtab

" Enable mouse support
set mouse=a

" Better completion
set wildmenu
set wildmode=list:longest,full

" Performance improvements
set lazyredraw
set regexpengine=1
EOF
    
    if [[ -f "$vimrc" ]]; then
        print_status "success" "Vim configuration created"
        DEV_CHANGES+=("Created vim development configuration")
    else
        print_status "warning" "Failed to create vim configuration"
        DEV_WARNINGS+=("Failed to create vim configuration")
    fi
    
    print_status "success" "Vim development configuration completed"
    log_function_exit "configure_vim_development" 0
    return 0
}

# Function to configure Git
configure_git_development() {
    local git_username="${1:-}"
    local git_email="${2:-}"
    
    log_function_enter "configure_git_development"
    log_info "Configuring Git for development"
    
    print_status "progress" "Configuring Git for development..."
    
    # Ensure git is installed
    if ! command_exists git; then
        if ! install_package "git" "Installing Git"; then
            print_status "error" "Failed to install Git"
            DEV_ERRORS+=("Failed to install Git")
            log_function_exit "configure_git_development" 1
            return 1
        fi
    fi
    
    # Configure Git if user info provided
    if [[ -n "$git_username" && -n "$git_email" ]]; then
        print_status "progress" "Setting up Git user configuration..."
        git config --global user.name "$git_username"
        git config --global user.email "$git_email"
        DEV_CHANGES+=("Configured Git user: $git_username <$git_email>")
    fi
    
    # Set up Git defaults
    print_status "progress" "Configuring Git defaults..."
    git config --global init.defaultBranch main
    git config --global core.editor vim
    git config --global color.ui auto
    git config --global push.default simple
    git config --global pull.rebase false
    git config --global core.autocrlf input
    DEV_CHANGES+=("Configured Git default settings")
    
    # Create global gitignore
    local global_gitignore="$HOME/.gitignore_global"
    cat > "$global_gitignore" << 'EOF'
# Global gitignore - Generated by Linux Setup System

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*~
*.swp
*.swo
.vscode/
.idea/

# Log files
*.log
logs/

# Dependency directories
node_modules/
vendor/
__pycache__/
*.pyc
.venv/
venv/

# Build outputs
dist/
build/
*.o
*.so
*.dylib
*.exe

# Environment files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Temporary files
tmp/
temp/
*.tmp
*.temp
EOF
    
    git config --global core.excludesfile "$global_gitignore"
    DEV_CHANGES+=("Created global gitignore configuration")
    
    # Generate SSH key if requested
    local ssh_key_path="$HOME/.ssh/id_ed25519"
    if [[ ! -f "$ssh_key_path" && -n "$git_email" ]]; then
        print_status "progress" "Generating SSH key for Git..."
        if ssh-keygen -t ed25519 -C "$git_email" -f "$ssh_key_path" -N "" >/dev/null 2>&1; then
            print_status "success" "SSH key generated: $ssh_key_path"
            DEV_CHANGES+=("Generated SSH key for Git: $ssh_key_path")
            
            # Start ssh-agent and add key
            eval "$(ssh-agent -s)" >/dev/null 2>&1
            ssh-add "$ssh_key_path" >/dev/null 2>&1
            
            print_status "info" "SSH public key (add to GitHub/GitLab):"
            echo "$(cat "${ssh_key_path}.pub")"
        else
            print_status "warning" "Failed to generate SSH key"
            DEV_WARNINGS+=("Failed to generate SSH key")
        fi
    fi
    
    print_status "success" "Git development configuration completed"
    log_function_exit "configure_git_development" 0
    return 0
}

# Function to install Docker
install_docker_environment() {
    log_function_enter "install_docker_environment"
    log_info "Installing Docker development environment"
    
    print_status "progress" "Setting up Docker development environment..."
    
    # Check if Docker is already installed
    if command_exists docker; then
        print_status "info" "Docker already installed"
        DEV_CHANGES+=("Docker already available")
    else
        print_status "progress" "Installing Docker..."
        
        # Install Docker using the convenience script
        if curl -fsSL https://get.docker.com -o get-docker.sh 2>/dev/null; then
            if sudo sh get-docker.sh >/dev/null 2>&1; then
                print_status "success" "Docker installed successfully"
                DEV_CHANGES+=("Installed Docker")
                
                # Add current user to docker group
                sudo usermod -aG docker "$USER"
                DEV_CHANGES+=("Added $USER to docker group")
                
                # Enable Docker service
                sudo systemctl enable docker >/dev/null 2>&1
                sudo systemctl start docker >/dev/null 2>&1
                DEV_CHANGES+=("Docker service enabled and started")
                
            else
                print_status "warning" "Docker installation script failed, trying package manager..."
                if install_package "docker.io" "Installing Docker from package manager"; then
                    DEV_CHANGES+=("Installed Docker from package manager")
                else
                    DEV_ERRORS+=("Failed to install Docker")
                fi
            fi
            rm -f get-docker.sh
        else
            print_status "warning" "Failed to download Docker installer, trying package manager..."
            if install_package "docker.io" "Installing Docker from package manager"; then
                DEV_CHANGES+=("Installed Docker from package manager")
            else
                DEV_ERRORS+=("Failed to install Docker")
            fi
        fi
    fi
    
    # Install Docker Compose
    if command_exists docker; then
        print_status "progress" "Installing Docker Compose..."
        if ! command_exists docker-compose; then
            # Try to install via pip first
            if python3 -m pip install --user docker-compose >/dev/null 2>&1; then
                print_status "success" "Docker Compose installed via pip"
                DEV_CHANGES+=("Installed Docker Compose via pip")
            # Fallback to package manager
            elif install_package "docker-compose" "Installing Docker Compose"; then
                DEV_CHANGES+=("Installed Docker Compose from package manager")
            else
                DEV_WARNINGS+=("Failed to install Docker Compose")
            fi
        else
            print_status "info" "Docker Compose already installed"
        fi
    fi
    
    print_status "success" "Docker development environment setup completed"
    log_function_exit "install_docker_environment" 0
    return 0
}

# Function to configure shell environment
configure_shell_environment() {
    local target_shell="${1:-bash}"
    
    log_function_enter "configure_shell_environment"
    log_info "Configuring shell environment: $target_shell"
    
    print_status "progress" "Configuring $target_shell environment..."
    
    # Install zsh if requested and not present
    if [[ "$target_shell" == "zsh" ]]; then
        if ! command_exists zsh; then
            if install_package "zsh" "Installing zsh"; then
                DEV_CHANGES+=("Installed zsh shell")
            else
                print_status "warning" "Failed to install zsh, falling back to bash"
                target_shell="bash"
            fi
        fi
        
        # Install oh-my-zsh if zsh is available
        if command_exists zsh && [[ ! -d "$HOME/.oh-my-zsh" ]]; then
            print_status "progress" "Installing oh-my-zsh..."
            if curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh 2>/dev/null | sh; then
                print_status "success" "oh-my-zsh installed"
                DEV_CHANGES+=("Installed oh-my-zsh")
            else
                print_status "warning" "Failed to install oh-my-zsh"
                DEV_WARNINGS+=("Failed to install oh-my-zsh")
            fi
        fi
    fi
    
    # Create common shell aliases and functions
    local shell_config=""
    if [[ "$target_shell" == "zsh" ]]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.bashrc"
    fi
    
    # Add development-friendly aliases
    local dev_aliases='
# Development aliases - Generated by Linux Setup System
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias tree="tree -C"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Git aliases
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline"
alias gd="git diff"
alias gb="git branch"
alias gco="git checkout"

# Development shortcuts
alias py="python3"
alias pip="python3 -m pip"
alias serve="python3 -m http.server"
alias json="python3 -m json.tool"

# Docker aliases
alias dc="docker-compose"
alias dps="docker ps"
alias dim="docker images"
alias drm="docker rm"
alias drmi="docker rmi"
'
    
    if [[ -f "$shell_config" ]]; then
        if ! grep -q "Development aliases" "$shell_config"; then
            echo "$dev_aliases" >> "$shell_config"
            DEV_CHANGES+=("Added development aliases to $shell_config")
        fi
    fi
    
    print_status "success" "Shell environment configuration completed"
    log_function_exit "configure_shell_environment" 0
    return 0
}

# Function to setup complete development environment
setup_development_environment() {
    local git_username="${1:-}"
    local git_email="${2:-}"
    local target_shell="${3:-bash}"
    
    log_function_enter "setup_development_environment"
    log_info "Starting complete development environment setup"
    
    # Reset counters
    DEV_CHANGES=()
    DEV_ERRORS=()
    DEV_WARNINGS=()
    
    print_status "progress" "Setting up development environment..."
    echo "💻 Development Environment Setup"
    echo "==============================="
    
    local components_configured=0
    local components_failed=0
    
    # Install Python environment
    if [[ "$INSTALL_PYTHON" == "true" ]]; then
        echo ""
        echo "🐍 Python Development Environment"
        if install_python_environment; then
            ((components_configured++))
        else
            ((components_failed++))
        fi
    fi
    
    # Install Node.js environment
    if [[ "$INSTALL_NODEJS" == "true" ]]; then
        echo ""
        echo "📦 Node.js Development Environment"
        if install_nodejs_environment; then
            ((components_configured++))
        else
            ((components_failed++))
        fi
    fi
    
    # Install Go environment
    if [[ "$INSTALL_GO" == "true" ]]; then
        echo ""
        echo "🔷 Go Development Environment"
        if install_go_environment; then
            ((components_configured++))
        else
            ((components_failed++))
        fi
    fi
    
    # Configure vim
    if [[ "$SETUP_VIM" == "true" ]]; then
        echo ""
        echo "📝 Vim Editor Configuration"
        if configure_vim_development; then
            ((components_configured++))
        else
            ((components_failed++))
        fi
    fi
    
    # Configure Git
    if [[ "$SETUP_GIT" == "true" ]]; then
        echo ""
        echo "🔧 Git Configuration"
        if configure_git_development "$git_username" "$git_email"; then
            ((components_configured++))
        else
            ((components_failed++))
        fi
    fi
    
    # Install Docker
    if [[ "$INSTALL_DOCKER" == "true" ]]; then
        echo ""
        echo "🐳 Docker Environment"
        if install_docker_environment; then
            ((components_configured++))
        else
            ((components_failed++))
        fi
    fi
    
    # Configure shell
    echo ""
    echo "🐚 Shell Environment Configuration"
    if configure_shell_environment "$target_shell"; then
        ((components_configured++))
    else
        ((components_failed++))
    fi
    
    # Summary
    echo ""
    echo "📊 Development Environment Setup Summary"
    echo "======================================="
    echo "✅ Components configured: $components_configured"
    echo "❌ Components failed: $components_failed"
    echo "📝 Configuration changes: ${#DEV_CHANGES[@]}"
    echo "⚠️  Warnings: ${#DEV_WARNINGS[@]}"
    echo "❌ Errors: ${#DEV_ERRORS[@]}"
    
    if [[ ${#DEV_CHANGES[@]} -gt 0 ]]; then
        echo ""
        echo "📋 Configuration Changes:"
        for change in "${DEV_CHANGES[@]}"; do
            echo "   ✅ $change"
        done
    fi
    
    if [[ ${#DEV_WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo "⚠️  Warnings:"
        for warning in "${DEV_WARNINGS[@]}"; do
            echo "   ⚠️  $warning"
        done
    fi
    
    if [[ ${#DEV_ERRORS[@]} -gt 0 ]]; then
        echo ""
        echo "❌ Errors:"
        for error in "${DEV_ERRORS[@]}"; do
            echo "   ❌ $error"
        done
    fi
    
    echo ""
    if [[ $components_failed -eq 0 ]]; then
        print_status "success" "Development environment setup completed successfully!"
        echo ""
        echo "🎉 Next Steps:"
        echo "   1. Restart your shell or run: source ~/.bashrc"
        echo "   2. For Docker: log out and back in to use Docker without sudo"
        if [[ -n "$git_email" ]]; then
            echo "   3. Add your SSH public key to GitHub/GitLab"
        fi
    elif [[ $components_configured -gt $components_failed ]]; then
        print_status "warning" "Development environment setup completed with some issues"
    else
        print_status "error" "Development environment setup failed"
    fi
    
    log_info "Development environment setup summary: $components_configured configured, $components_failed failed, ${#DEV_CHANGES[@]} changes, ${#DEV_WARNINGS[@]} warnings, ${#DEV_ERRORS[@]} errors"
    log_function_exit "setup_development_environment" $components_failed
    return $components_failed
}