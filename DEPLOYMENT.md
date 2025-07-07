# Deployment Guide - Universal Linux Setup & Monitoring System

## 🚀 Quick Deployment

### One-Line Installation

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash

# Or with custom options
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --auto-setup --dir /opt/linuxSetup
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/user/linuxSetup.git /srv/shared/Projects/linuxSetup
cd /srv/shared/Projects/linuxSetup

# Make scripts executable
chmod +x bin/*
chmod +x tests/*.sh
chmod +x deploy/install.sh

# Run setup
./bin/setup-linux --install-tools
```

## 🖥️ Supported Platforms

### Linux Distributions

| Distribution | Version | Support Level | Package Manager | Tested |
|-------------|---------|---------------|----------------|--------|
| **Ubuntu** | 18.04+ | ✅ Full | APT | ✅ |
| **Debian** | 9+ | ✅ Full | APT | ✅ |
| **CentOS** | 7+ | ✅ Full | YUM/DNF | ⚠️ |
| **RHEL** | 7+ | ✅ Full | YUM/DNF | ⚠️ |
| **Fedora** | 30+ | ✅ Full | DNF | ⚠️ |
| **Arch Linux** | Latest | 🔶 Partial | Pacman | ⚠️ |
| **openSUSE** | 15+ | 🔶 Partial | Zypper | ⚠️ |
| **Alpine** | 3.14+ | 🧪 Experimental | APK | ⚠️ |

### macOS Support

| Version | Support Level | Package Manager | Tested |
|---------|---------------|----------------|--------|
| **macOS 11+** | ✅ Full | Homebrew | ✅ |
| **macOS 10.15+** | ✅ Full | Homebrew | ⚠️ |

### Architecture Support

- ✅ **x86_64** (Intel/AMD 64-bit)
- ✅ **ARM64** (Apple Silicon, ARM 64-bit)
- 🔶 **ARMv7** (ARM 32-bit)
- 🔶 **i386** (Intel 32-bit)

## 📦 Installation Methods

### Method 1: Automated Installation (Recommended)

```bash
# Basic installation
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash

# With automatic setup
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --auto-setup

# Custom directory
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --dir /opt/linuxSetup

# Without dependencies (if already installed)
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --no-deps
```

### Method 2: Git Clone

```bash
# Standard location
sudo git clone https://github.com/user/linuxSetup.git /srv/shared/Projects/linuxSetup
cd /srv/shared/Projects/linuxSetup

# Set permissions
sudo chown -R $(whoami):$(whoami) .
chmod +x bin/*
chmod +x tests/*.sh

# Run initial setup
./bin/setup-linux
```

### Method 3: Tarball Download

```bash
# Download and extract
curl -fsSL https://github.com/user/linuxSetup/archive/main.tar.gz | tar -xz
sudo mv linuxSetup-main /srv/shared/Projects/linuxSetup
cd /srv/shared/Projects/linuxSetup

# Set permissions and run
sudo chown -R $(whoami):$(whoami) .
chmod +x bin/*
./bin/setup-linux
```

## 🔧 Configuration Options

### Environment Variables

```bash
# Set custom installation directory
export LINUX_SETUP_DIR="/opt/linuxSetup"

# Skip automatic updates
export LINUX_SETUP_NO_UPDATE=1

# Custom log level (DEBUG, INFO, WARN, ERROR)
export LINUX_SETUP_LOG_LEVEL="INFO"

# Custom package manager
export LINUX_SETUP_PACKAGE_MANAGER="brew"
```

### Configuration Files

Create `~/.linuxsetup/config.yaml`:

```yaml
installation:
  directory: "/opt/linuxSetup"
  auto_update: true
  log_level: "INFO"

tools:
  install_categories:
    - core_development
    - terminal_tools
    - network_tools
  skip_tools:
    - strace
    - tcpdump

services:
  configure_ssh: true
  configure_firewall: true
  configure_ntp: true
  configure_fail2ban: true

development:
  setup_python: true
  setup_nodejs: true
  setup_go: true
  setup_docker: true
```

## 🏗️ Deployment Scenarios

### 1. Developer Workstation

```bash
# Complete development setup
./deploy/install.sh --auto-setup
./bin/setup-linux --install-tools
./bin/setup-dev --all
./bin/configure-linux --all
```

### 2. Server Deployment

```bash
# Security-focused server setup
./deploy/install.sh --dir /opt/linuxSetup
./bin/setup-linux --install-tools
./bin/configure-linux --all
./bin/manage-users create sysadmin "System Administrator"
```

### 3. CI/CD Pipeline

```bash
# Minimal installation for CI
./deploy/install.sh --no-deps --dir /tmp/linuxSetup
/tmp/linuxSetup/bin/setup-linux --verify-tools
/tmp/linuxSetup/bin/check-linux --json > system-report.json
```

### 4. Docker Container

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y curl bash sudo

# Install Linux Setup System
RUN curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --auto-setup --dir /opt/linuxSetup

# Run setup
RUN /opt/linuxSetup/bin/setup-linux --install-tools

WORKDIR /opt/linuxSetup
CMD ["./bin/check-linux", "--services"]
```

### 5. macOS Development Machine

```bash
# macOS-specific installation
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --auto-setup

# Setup development environment with macOS tools
./bin/setup-dev --all --shell zsh
./bin/setup-linux --install-tools

# Generate system report
./bin/generate-report --all --output-dir ~/Reports
```

## 🌐 Network Deployment

### Ansible Playbook

```yaml
---
- name: Deploy Linux Setup System
  hosts: all
  become: yes
  tasks:
    - name: Download installer
      get_url:
        url: https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh
        dest: /tmp/install-linuxsetup.sh
        mode: '0755'
    
    - name: Run installer
      shell: /tmp/install-linuxsetup.sh --auto-setup --dir /opt/linuxSetup
    
    - name: Install tools
      shell: /opt/linuxSetup/bin/setup-linux --install-tools
    
    - name: Configure services
      shell: /opt/linuxSetup/bin/configure-linux --all
```

### Terraform Configuration

```hcl
resource "null_resource" "install_linux_setup" {
  count = length(var.server_ips)
  
  connection {
    type        = "ssh"
    host        = var.server_ips[count.index]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
  }
  
  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --auto-setup",
      "/srv/shared/Projects/linuxSetup/bin/setup-linux --install-tools",
      "/srv/shared/Projects/linuxSetup/bin/configure-linux --all"
    ]
  }
}
```

## 🧪 Testing Deployment

### Local Testing

```bash
# Run comprehensive tests
./tests/test_multi_distro.sh

# Test specific functionality
./tests/run_basic_tests.sh

# Performance testing
./tests/test_multi_distro.sh --performance
```

### Docker Testing

```bash
# Test across multiple distributions
./tests/test_multi_distro.sh --docker-only

# Test specific distribution
docker run --rm -v $(pwd):/app ubuntu:22.04 /app/tests/run_basic_tests.sh
```

### Validation Checklist

- [ ] Distribution detection working
- [ ] Package manager detection successful
- [ ] Essential tools installation (90%+ success rate)
- [ ] System health monitoring functional
- [ ] Service configuration working
- [ ] User management operational
- [ ] Report generation successful
- [ ] All scripts executable and functional

## 🔐 Security Considerations

### Pre-Installation Security

```bash
# Verify installer integrity (when available)
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh.sha256 | sha256sum -c

# Review installer script before running
curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | less
```

### Post-Installation Security

```bash
# Run security audit
./bin/manage-users audit

# Check service security
./bin/generate-report --security --format html --output security-audit.html

# Verify SSH configuration
./bin/check-linux --services | grep SSH
```

## 📊 Monitoring Deployment

### Health Checks

```bash
# Quick system status
./bin/check-linux --quick

# Comprehensive health check
./bin/check-linux --services --report

# JSON output for monitoring systems
./bin/check-linux --json > /var/log/system-health.json
```

### Automated Monitoring

```bash
# Add to crontab for regular monitoring
echo "0 * * * * /srv/shared/Projects/linuxSetup/bin/check-linux --json > /var/log/hourly-health.json" | crontab -

# Setup alerting (example with webhook)
./bin/check-linux --json | curl -X POST -H "Content-Type: application/json" -d @- https://monitoring.example.com/webhook
```

## 🚨 Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   chmod +x bin/*
   sudo chown -R $(whoami):$(whoami) /srv/shared/Projects/linuxSetup
   ```

2. **Package Manager Not Found**
   ```bash
   # Manually install package manager
   # For CentOS 8+: dnf install epel-release
   # For Alpine: apk update
   ```

3. **Homebrew Installation Fails (macOS)**
   ```bash
   # Install Xcode Command Line Tools first
   xcode-select --install
   ```

4. **Network Issues**
   ```bash
   # Test connectivity
   curl -I https://github.com
   # Use alternative installation method
   ./deploy/install.sh --method tarball
   ```

### Log Analysis

```bash
# Check recent logs
tail -f logs/setup-linux-*.log

# Find errors
grep ERROR logs/*.log

# Generate diagnostic report
./bin/generate-report --all --output diagnostic-$(date +%Y%m%d).html
```

## 📈 Scaling Deployment

### Mass Deployment Script

```bash
#!/bin/bash
# deploy-to-servers.sh

SERVERS=(
    "server1.example.com"
    "server2.example.com"
    "server3.example.com"
)

SSH_USER="admin"
SSH_KEY="~/.ssh/id_rsa"

for server in "${SERVERS[@]}"; do
    echo "Deploying to $server..."
    
    ssh -i "$SSH_KEY" "$SSH_USER@$server" << 'EOF'
        curl -fsSL https://raw.githubusercontent.com/user/linuxSetup/main/deploy/install.sh | bash -s -- --auto-setup
        /srv/shared/Projects/linuxSetup/bin/setup-linux --install-tools
        /srv/shared/Projects/linuxSetup/bin/configure-linux --all
EOF
    
    echo "✅ Deployment to $server completed"
done
```

### Integration with Configuration Management

- **Puppet**: Create custom modules for Linux Setup System
- **Chef**: Develop cookbooks for automated deployment
- **SaltStack**: Write Salt states for configuration
- **Ansible**: Use provided playbook or create custom roles

## 🎯 Best Practices

1. **Always test in non-production first**
2. **Backup system configuration before deployment**
3. **Use version control for custom configurations**
4. **Monitor deployment with health checks**
5. **Keep installer and tools updated**
6. **Document environment-specific customizations**
7. **Implement proper access controls**
8. **Regular security audits and updates**

## 📚 Additional Resources

- [Installation Guide](INSTALL.md)
- [Configuration Reference](docs/CONFIG.md)
- [API Documentation](docs/API.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Contributing Guidelines](CONTRIBUTING.md)

---

**Ready to deploy across your infrastructure!** 🚀

For support and questions, please check the documentation or create an issue in the repository.