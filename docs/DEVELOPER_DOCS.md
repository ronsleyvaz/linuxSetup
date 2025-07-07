# Developer Documentation - Generic Linux Setup System

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Code Organization](#code-organization)
- [Core Libraries](#core-libraries)
- [Development Workflow](#development-workflow)
- [Testing Strategy](#testing-strategy)
- [Contributing Guidelines](#contributing-guidelines)
- [Performance Considerations](#performance-considerations)
- [Security Considerations](#security-considerations)

---

## Architecture Overview

### Design Principles

The Generic Linux Setup System follows these core principles:

1. **Distribution Agnostic**: Support multiple Linux distributions through abstraction layers
2. **Modular Design**: Clean separation of concerns with reusable components
3. **Graceful Degradation**: Continue operation when optional features fail
4. **Comprehensive Logging**: Full audit trail for debugging and compliance
5. **Extensible**: Easy to add new distributions, package managers, and features

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Main Script (setup-linux)                │
│                   Orchestration Layer                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │ Common  │ │ Logging │ │ Config  │
    │ Utils   │ │ System  │ │ Manager │
    └─────────┘ └─────────┘ └─────────┘
          │           │           │
          └───────────┼───────────┘
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │ Distro  │ │Package  │ │ Service │
    │ Detect  │ │ Manager │ │ Manager │
    └─────────┘ └─────────┘ └─────────┘
```

### Data Flow

1. **Initialization**: Load common utilities and setup logging
2. **Detection**: Identify distribution, version, and architecture
3. **Abstraction**: Initialize appropriate package manager interface
4. **Execution**: Perform requested operations through unified API
5. **Logging**: Record all operations and results for audit

---

## Code Organization

### Directory Structure

```
linuxSetup/
├── bin/                      # Executable scripts
│   ├── setup-linux          # Main setup script
│   ├── check-linux          # System health checker (planned)
│   └── monitor-linux        # System monitor (planned)
│
├── lib/                      # Core libraries
│   ├── common.sh            # Common utilities and helpers
│   ├── distro_detect.sh     # Distribution detection logic
│   ├── package_manager.sh   # Package manager abstraction
│   ├── logging.sh           # Logging infrastructure
│   ├── service_manager.sh   # Service management (planned)
│   └── config_manager.sh    # Configuration management (planned)
│
├── config/                   # Configuration files
│   ├── distributions.yaml   # Distribution definitions (planned)
│   ├── packages.yaml        # Package mappings (planned)
│   └── profiles/            # Installation profiles (planned)
│
├── logs/                     # Log files (auto-generated)
│   └── *.log                # Timestamped log files
│
├── tests/                    # Test scripts and data
│   ├── unit/                # Unit tests
│   ├── integration/         # Integration tests
│   └── fixtures/            # Test data and mocks
│
└── docs/                     # Documentation
    ├── api/                 # API documentation
    ├── guides/              # User guides
    └── development/         # Development documentation
```

### Naming Conventions

#### Files and Directories
- **Scripts**: lowercase with hyphens (`setup-linux`, `check-linux`)
- **Libraries**: lowercase with underscores (`distro_detect.sh`)
- **Directories**: lowercase (`bin`, `lib`, `config`)
- **Log files**: descriptive with timestamps (`setup-linux-YYYYMMDD-HHMMSS.log`)

#### Functions
- **Public functions**: lowercase with underscores (`detect_distribution`)
- **Private functions**: prefixed with underscore (`_extract_cpuinfo_field`)
- **Utility functions**: descriptive names (`command_exists`, `print_status`)

#### Variables
- **Global variables**: UPPERCASE (`DISTRO_ID`, `PACKAGE_MANAGER`)
- **Local variables**: lowercase (`package_name`, `log_file`)
- **Constants**: UPPERCASE with readonly (`readonly RED='\033[0;31m'`)

---

## Core Libraries

### lib/common.sh

**Purpose**: Provides common utility functions used across all scripts.

#### Key Functions

```bash
# Color output functions
print_status "success|error|warning|info|progress" "message"

# System checks
command_exists "command_name"
is_root
has_sudo
ensure_sudo

# User interaction
ask_yes_no "question" "default"

# System information
get_architecture
get_hostname
get_uptime
get_memory_info
get_disk_info
get_primary_ip

# Network utilities
check_internet
validate_ip "ip_address"
download_file "url" "output_file" [max_attempts]

# File operations
backup_file "file_path" [backup_dir]
create_directory "dir_path" [mode]

# Retry logic
retry_command max_attempts delay "command"
```

#### Usage Example

```bash
source lib/common.sh

# Check if user has sudo access
ensure_sudo

# Print status with colors
print_status "progress" "Installing packages..."

# Retry with backoff
retry_command 3 5 "wget https://example.com/file.tar.gz"

# Get system info
echo "System: $(get_hostname) ($(get_architecture))"
echo "Uptime: $(get_uptime)"
```

### lib/distro_detect.sh

**Purpose**: Detects Linux distribution and sets global variables.

#### Global Variables Set

```bash
DISTRO_ID          # e.g., "ubuntu", "debian", "centos"
DISTRO_NAME        # e.g., "Ubuntu", "Debian GNU/Linux"
DISTRO_VERSION     # e.g., "20.04", "12", "8"
DISTRO_CODENAME    # e.g., "focal", "bookworm"
DISTRO_FAMILY      # e.g., "debian", "redhat", "arch"
DISTRO_ARCHITECTURE # e.g., "x86_64", "arm64"
```

#### Key Functions

```bash
# Main detection function
detect_distribution

# Detection methods (internal)
detect_from_os_release
detect_from_lsb_release
detect_from_release_files

# Support level assessment
get_support_level
is_supported_distribution

# Information display
print_distribution_info
export_distribution_vars
```

#### Detection Logic

1. **Primary**: Read `/etc/os-release` (systemd standard)
2. **Secondary**: Use `lsb_release` command if available
3. **Fallback**: Parse traditional release files (`/etc/redhat-release`, `/etc/debian_version`)
4. **Validation**: Verify detection results and set support level

#### Usage Example

```bash
source lib/distro_detect.sh

if detect_distribution; then
    echo "Detected: $DISTRO_NAME $DISTRO_VERSION"
    echo "Family: $DISTRO_FAMILY"
    echo "Support: $(get_support_level)"
else
    echo "Distribution detection failed"
    exit 1
fi
```

### lib/package_manager.sh

**Purpose**: Provides unified interface for different package managers.

#### Global Variables Set

```bash
PACKAGE_MANAGER           # e.g., "apt", "yum", "pacman"
PACKAGE_MANAGER_CMD       # Base command
PACKAGE_MANAGER_INSTALL_CMD # Install command with flags
PACKAGE_MANAGER_UPDATE_CMD  # Update command
PACKAGE_MANAGER_SEARCH_CMD  # Search command
PACKAGE_MANAGER_REMOVE_CMD  # Remove command
```

#### Key Functions

```bash
# Initialization
init_package_manager
detect_package_manager
set_package_manager_commands

# Package operations
install_package "package_name" [description]
install_packages "package1" "package2" "package3"
install_packages_batch batch_size "package1" "package2" ...
install_generic_packages "generic_name1" "generic_name2"

# Package queries
is_package_installed "package_name"
search_package "search_term"

# Package management
remove_package "package_name" [description]
update_package_lists

# Utilities
get_package_name "generic_name"  # Convert to distro-specific name
test_package_manager             # Test functionality
print_package_manager_info       # Display configuration
```

#### Package Name Translation

The system provides generic package names that are automatically translated:

```bash
# Generic name -> Distribution-specific mapping
"development-tools" -> "build-essential" (Debian/Ubuntu)
                   -> "gcc gcc-c++ make" (CentOS/RHEL)
                   -> "base-devel" (Arch)

"python-dev"       -> "python3-dev" (Debian/Ubuntu)
                   -> "python3-devel" (CentOS/RHEL)
                   -> "python" (Arch)
```

#### Usage Example

```bash
source lib/package_manager.sh

# Initialize package manager
init_package_manager

# Install packages
install_packages "git" "vim" "curl"

# Install using generic names
install_generic_packages "development-tools" "python-dev"

# Batch installation
install_packages_batch 5 "git" "vim" "curl" "wget" "tree" "htop"
```

### lib/logging.sh

**Purpose**: Comprehensive logging infrastructure with multiple levels and audit trails.

#### Configuration

```bash
LOG_FILE=""           # Set by setup_logging()
LOG_LEVEL="INFO"      # DEBUG, INFO, WARN, ERROR
```

#### Key Functions

```bash
# Setup
setup_logging "script_name" [log_level]

# Logging functions
log_debug "message"
log_info "message"
log_warn "message"
log_error "message"

# Command logging
log_command "command" [description]

# System logging
log_system_info
log_function_enter "function_name"
log_function_exit "function_name" [exit_code]

# Log management
archive_logs [max_age_days]
cleanup_logs [max_archive_days]
rotate_log_if_needed [max_size_mb]
get_log_size
```

#### Log Format

```
[YYYY-MM-DD HH:MM:SS] [LEVEL] message
```

#### Log Levels

- **DEBUG**: Detailed diagnostic information
- **INFO**: General operational messages
- **WARN**: Warning conditions that don't prevent operation
- **ERROR**: Error conditions that may affect operation

#### Usage Example

```bash
source lib/logging.sh

# Setup logging
setup_logging "my-script" "DEBUG"

# Log different levels
log_info "Starting operation"
log_debug "Debug information"
log_warn "Warning condition"
log_error "Error occurred"

# Log command execution
log_command "apt update" "Updating package lists"

# Function tracing
log_function_enter "my_function"
# ... function code ...
log_function_exit "my_function" $?
```

---

## Development Workflow

### Setting Up Development Environment

1. **Clone the repository**:
   ```bash
   git clone [repository] /srv/shared/Projects/linuxSetup
   cd /srv/shared/Projects/linuxSetup
   ```

2. **Set up permissions**:
   ```bash
   chmod +x bin/*
   chmod 644 lib/*.sh
   chmod 755 logs tests docs
   ```

3. **Test basic functionality**:
   ```bash
   ./bin/setup-linux
   ```

### Development Best Practices

#### Code Style

1. **Bash Best Practices**:
   ```bash
   # Use strict error handling
   set -euo pipefail
   
   # Quote variables
   echo "Hello $USER"
   
   # Use local variables in functions
   local variable_name="value"
   
   # Check command existence
   if command_exists "git"; then
       # use git
   fi
   ```

2. **Function Design**:
   ```bash
   function_name() {
       local param1="$1"
       local param2="${2:-default_value}"
       
       log_function_enter "function_name"
       
       # Function logic here
       
       log_function_exit "function_name" $?
       return $?
   }
   ```

3. **Error Handling**:
   ```bash
   if some_command; then
       log_info "Command succeeded"
   else
       log_error "Command failed"
       return 1
   fi
   ```

#### Adding New Features

1. **Create feature branch**:
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Follow modular design**:
   - Add new functions to appropriate library files
   - Create new library files for major new functionality
   - Update main scripts to use new functionality

3. **Add comprehensive logging**:
   ```bash
   log_info "Starting new feature"
   log_debug "Debug information"
   ```

4. **Test thoroughly**:
   - Test on multiple distributions
   - Test error conditions
   - Verify logging output

5. **Update documentation**:
   - Update README.md
   - Add to CHANGELOG.md
   - Update this developer documentation

#### Adding New Distribution Support

1. **Update `lib/distro_detect.sh`**:
   ```bash
   # Add detection logic
   elif [[ "$content" =~ "New Distribution" ]]; then
       DISTRO_ID="newdistro"
       DISTRO_NAME="New Distribution"
   ```

2. **Update `lib/package_manager.sh`**:
   ```bash
   # Add package manager mapping
   "newdistro")
       PACKAGE_MANAGER="newpm"
       ;;
   ```

3. **Add package name mappings**:
   ```bash
   case "$generic_name" in
       "development-tools") echo "newdistro-build-tools" ;;
   ```

4. **Test thoroughly** on the new distribution

5. **Update documentation** with new distribution support

### Code Review Guidelines

#### Checklist for Pull Requests

- [ ] **Code Quality**:
  - Follows bash best practices
  - Proper error handling
  - Appropriate use of global vs local variables
  - Consistent naming conventions

- [ ] **Functionality**:
  - Feature works as designed
  - Handles error conditions gracefully
  - Doesn't break existing functionality
  - Appropriate logging added

- [ ] **Testing**:
  - Tested on target distributions
  - Error conditions tested
  - Manual testing documented
  - Automated tests added/updated

- [ ] **Documentation**:
  - README.md updated
  - CHANGELOG.md updated
  - Developer docs updated
  - Code comments added for complex logic

---

## Testing Strategy

### Test Pyramid

```
    ┌─────────────────┐
    │   Manual Tests  │  ← End-to-end testing on real systems
    ├─────────────────┤
    │Integration Tests│  ← Multi-component testing
    ├─────────────────┤
    │   Unit Tests    │  ← Individual function testing
    └─────────────────┘
```

### Testing Levels

#### Unit Tests
- **Purpose**: Test individual functions in isolation
- **Location**: `tests/unit/`
- **Tool**: Custom bash testing framework
- **Coverage**: Core utility functions, parsing logic, validation

#### Integration Tests
- **Purpose**: Test component interaction
- **Location**: `tests/integration/`
- **Coverage**: Distribution detection + package manager initialization
- **Environment**: Containers with different distributions

#### Manual Tests
- **Purpose**: End-to-end validation on real systems
- **Documentation**: `docs/MANUAL_TESTING_GUIDE.md`
- **Coverage**: Complete workflows, user experience, error handling

### Continuous Integration (Planned)

```yaml
# .github/workflows/test.yml (example)
name: Multi-Distribution Testing
on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-20.04, ubuntu-22.04]
        container: [debian:12, centos:8, fedora:latest, archlinux:latest]
    
    runs-on: ${{ matrix.os }}
    container: ${{ matrix.container }}
    
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: ./tests/run_all_tests.sh
```

### Test Data Management

#### Test Fixtures
- **Mock distribution files**: Simulated `/etc/os-release` files
- **Package manager outputs**: Canned responses for testing
- **Error conditions**: Simulated failure scenarios

#### Test Environments
- **Docker containers**: Isolated testing environments
- **Vagrant VMs**: Full system testing
- **Cloud instances**: Real-world testing

---

## Performance Considerations

### Optimization Strategies

1. **Minimize System Calls**:
   ```bash
   # Good: Single call
   distro_info=$(cat /etc/os-release)
   
   # Bad: Multiple calls
   id=$(grep "^ID=" /etc/os-release)
   name=$(grep "^NAME=" /etc/os-release)
   ```

2. **Efficient Package Operations**:
   ```bash
   # Install packages in batches
   install_packages_batch 10 "${all_packages[@]}"
   
   # Rather than individual installs
   for package in "${packages[@]}"; do
       install_package "$package"
   done
   ```

3. **Caching Results**:
   ```bash
   # Cache expensive operations
   if [[ -z "$DISTRO_ID" ]]; then
       detect_distribution
   fi
   ```

### Resource Usage

#### Memory Management
- Use local variables in functions
- Avoid large arrays when possible
- Clean up temporary files

#### Network Efficiency
- Batch download operations
- Implement retry logic with exponential backoff
- Cache downloaded content when appropriate

#### Disk I/O Optimization
- Minimize log file writes during tight loops
- Use buffered logging for high-frequency operations
- Implement log rotation to prevent disk space issues

---

## Security Considerations

### Security Principles

1. **Least Privilege**: Request minimal permissions necessary
2. **Input Validation**: Validate all external input
3. **Secure Defaults**: Use secure configurations by default
4. **Audit Trail**: Log all security-relevant operations

### Implementation Guidelines

#### Input Validation
```bash
# Validate package names
validate_package_name() {
    local package="$1"
    if [[ ! "$package" =~ ^[a-zA-Z0-9._+-]+$ ]]; then
        log_error "Invalid package name: $package"
        return 1
    fi
}
```

#### Command Injection Prevention
```bash
# Use arrays for commands
local cmd=("apt" "install" "-y" "$package")
"${cmd[@]}"

# Rather than string concatenation
local cmd="apt install -y $package"  # Dangerous!
```

#### Sudo Usage
```bash
# Check sudo availability before use
ensure_sudo

# Use specific sudo commands
sudo "$PACKAGE_MANAGER_INSTALL_CMD" "$package"

# Avoid blanket sudo
sudo bash -c "complex command"  # Dangerous!
```

#### File Operations
```bash
# Validate file paths
if [[ ! "$file_path" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
    log_error "Invalid file path: $file_path"
    return 1
fi

# Use temporary files securely
temp_file=$(mktemp)
trap "rm -f $temp_file" EXIT
```

### Security Testing

#### Vulnerability Scanning
- Static analysis of bash scripts
- Dependency vulnerability scanning
- Security-focused code review

#### Penetration Testing
- Test with malicious input
- Verify privilege escalation protection
- Validate secure file operations

---

## Future Architecture Considerations

### Scalability Planning

#### Multi-System Management
- **Agent Architecture**: Lightweight agents on managed systems
- **Central Coordination**: Management server for multiple systems
- **API Design**: RESTful APIs for remote management

#### Configuration Management
- **YAML-based Configuration**: Human-readable configuration files
- **Profile System**: Pre-defined installation profiles
- **Override Mechanisms**: System-specific customizations

#### Plugin Architecture
- **Hook System**: Pre/post execution hooks
- **Custom Modules**: User-defined functionality modules
- **Third-party Integration**: External tool integration points

### Technology Evolution

#### Container Support
- **Docker Integration**: Containerized installations
- **Kubernetes Operators**: Kubernetes-native deployment
- **Cloud-Native Patterns**: Cloud-specific optimizations

#### Modern Language Integration
- **Python Modules**: Advanced system monitoring
- **Go Binaries**: High-performance components
- **API Services**: Web-based management interfaces

---

*This developer documentation is maintained alongside the codebase and should be updated with each significant architectural change or new feature addition.*