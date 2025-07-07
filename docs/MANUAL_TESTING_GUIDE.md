# Manual Testing Guide - Generic Linux Setup System

## Overview

This guide provides step-by-step instructions for manually testing the Generic Linux Setup System. Follow these procedures to verify functionality on your specific Linux distribution.

## Prerequisites

### System Requirements
- Linux distribution (Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, openSUSE, or Alpine)
- Bash shell (version 4.0 or higher)
- Sudo privileges or root access
- Internet connectivity for package downloads
- At least 1GB free disk space

### Pre-Testing Setup
```bash
# 1. Clone or download the project
cd /srv/shared/Projects/linuxSetup

# 2. Verify project structure
ls -la
# Should show: bin/ lib/ config/ logs/ docs/ tests/

# 3. Check script permissions
ls -la bin/setup-linux
# Should show: -rwxr-xr-x (executable)

# 4. Verify you have sudo access
sudo -l
# Should not error (you may be prompted for password)
```

## Test Suite 1: Basic Functionality

### Test 1.1: Distribution Detection
**Purpose**: Verify the system correctly identifies your Linux distribution

```bash
# Execute the setup script
cd /srv/shared/Projects/linuxSetup
./bin/setup-linux
```

**Expected Results**:
- ✅ Script starts with colored output
- ✅ Displays "Detected: [Your Distribution] [Version]"
- ✅ Shows "Package manager: [apt/yum/dnf/pacman/zypper/apk]"
- ✅ Completes with "Setup Complete!" message
- ✅ Creates log file in logs/ directory

**Validation Steps**:
```bash
# 1. Check the log file was created
ls -la logs/
# Should show: setup-linux-YYYYMMDD-HHMMSS.log

# 2. Review the log content
cat logs/setup-linux-*.log | grep "Distribution detection complete"
# Should show your distribution details

# 3. Verify detection accuracy
cat /etc/os-release
# Compare with detected values in log
```

**Record Your Results**:
```
Distribution ID: _______________
Distribution Name: _______________
Version: _______________
Family: _______________
Architecture: _______________
Package Manager: _______________
Support Level: _______________
```

### Test 1.2: Package Manager Functionality
**Purpose**: Verify package manager abstraction works correctly

```bash
# Test package manager detection manually
source lib/common.sh
source lib/distro_detect.sh
source lib/package_manager.sh
source lib/logging.sh

# Initialize
LOG_DIR="./logs"
setup_logging "manual-test"
detect_distribution
init_package_manager

# Test package manager commands
echo "Package Manager: $PACKAGE_MANAGER"
echo "Install Command: $PACKAGE_MANAGER_INSTALL_CMD"
echo "Update Command: $PACKAGE_MANAGER_UPDATE_CMD"
```

**Expected Results**:
- ✅ Package manager correctly identified
- ✅ Commands properly formatted for your system
- ✅ No error messages

### Test 1.3: Logging System
**Purpose**: Verify comprehensive logging functionality

```bash
# Check log file structure
cat logs/setup-linux-*.log
```

**Expected Log Sections**:
- ✅ Header with system information
- ✅ Timestamped entries with log levels
- ✅ Distribution detection details
- ✅ Package manager initialization
- ✅ Test results and completion

## Test Suite 2: Error Conditions

### Test 2.1: Permission Testing
**Purpose**: Test behavior with different permission levels

```bash
# Test 1: Run without sudo (should work for detection only)
./bin/setup-linux

# Test 2: Simulate sudo failure
# Temporarily remove sudo access if possible
```

### Test 2.2: Network Connectivity
**Purpose**: Test behavior with network issues

```bash
# Test with limited connectivity
# Disconnect network temporarily and run:
./bin/setup-linux
```

### Test 2.3: Disk Space
**Purpose**: Test behavior with limited disk space

```bash
# Check current disk space
df -h /srv/shared/Projects/linuxSetup

# The script should handle low disk space gracefully
```

## Test Suite 3: Cross-Distribution Testing

### Test 3.1: Ubuntu Testing
**If testing on Ubuntu**:

```bash
# Verify Ubuntu-specific detection
./bin/setup-linux

# Check for Ubuntu-specific configurations
cat logs/setup-linux-*.log | grep -i ubuntu
```

**Expected Results**:
- Distribution ID: ubuntu
- Package Manager: apt
- Support Level: full

### Test 3.2: CentOS/RHEL Testing
**If testing on CentOS or RHEL**:

```bash
# Verify Red Hat family detection
./bin/setup-linux

# Check for RPM-based package manager
cat logs/setup-linux-*.log | grep -E "(yum|dnf)"
```

**Expected Results**:
- Distribution Family: redhat
- Package Manager: yum or dnf
- Support Level: full or partial

### Test 3.3: Arch Linux Testing
**If testing on Arch Linux**:

```bash
# Verify Arch detection
./bin/setup-linux

# Check for pacman package manager
cat logs/setup-linux-*.log | grep pacman
```

**Expected Results**:
- Distribution ID: arch
- Package Manager: pacman
- Support Level: partial

### Test 3.4: Other Distributions
**For openSUSE, Alpine, etc.**:

Follow similar patterns, checking for:
- Correct distribution identification
- Appropriate package manager detection
- Proper support level assessment

## Test Suite 4: Architecture Testing

### Test 4.1: Architecture Detection
**Purpose**: Verify correct architecture identification

```bash
# Check detected architecture
cat logs/setup-linux-*.log | grep "Architecture:"

# Compare with system architecture
uname -m
```

**Common Architectures**:
- x86_64 (Intel/AMD 64-bit)
- i386 (Intel 32-bit)
- arm64 (ARM 64-bit)
- armhf (ARM hard-float)

## Test Suite 5: Integration Testing

### Test 5.1: Multiple Executions
**Purpose**: Verify script can be run multiple times safely

```bash
# Run script multiple times
./bin/setup-linux
./bin/setup-linux
./bin/setup-linux

# Check that logs are created separately
ls -la logs/
```

### Test 5.2: Log File Management
**Purpose**: Verify log files are managed properly

```bash
# Check log file sizes and timestamps
ls -lah logs/

# Verify log content is not duplicated
wc -l logs/setup-linux-*.log
```

## Troubleshooting Common Issues

### Issue 1: Permission Denied
**Symptoms**: Cannot create log files or execute commands
**Solution**:
```bash
# Check directory permissions
ls -la /srv/shared/Projects/linuxSetup
chmod 755 /srv/shared/Projects/linuxSetup
chmod +x bin/setup-linux
```

### Issue 2: Distribution Not Detected
**Symptoms**: "Failed to detect Linux distribution" error
**Investigation**:
```bash
# Check available detection files
ls -la /etc/*release*
ls -la /etc/*version*

# Check lsb_release availability
which lsb_release
lsb_release -a
```

### Issue 3: Package Manager Not Found
**Symptoms**: Package manager test fails
**Investigation**:
```bash
# Check available package managers
which apt apt-get yum dnf pacman zypper apk

# Check if package databases are accessible
sudo apt list --installed 2>/dev/null | head -5  # For APT
sudo yum list installed 2>/dev/null | head -5    # For YUM
```

### Issue 4: Log Files Not Created
**Symptoms**: No log files in logs/ directory
**Investigation**:
```bash
# Check directory exists and is writable
mkdir -p logs
chmod 755 logs

# Check if user can write to directory
touch logs/test.txt && rm logs/test.txt
```

## Test Results Documentation

### Test Report Template
Create a file `test-results-[YYYYMMDD].md` with:

```markdown
# Test Results - [Date]

## System Information
- OS: 
- Distribution: 
- Version: 
- Architecture: 
- Kernel: 
- Package Manager: 

## Test Results
### Basic Functionality
- [ ] Distribution Detection: PASS/FAIL
- [ ] Package Manager Detection: PASS/FAIL
- [ ] Logging System: PASS/FAIL

### Error Conditions
- [ ] Permission Handling: PASS/FAIL
- [ ] Network Issues: PASS/FAIL
- [ ] Disk Space: PASS/FAIL

### Issues Found
1. 
2. 

### Recommendations
1. 
2. 
```

## Continuous Testing

### Weekly Testing
- Run basic functionality tests
- Check log file rotation
- Verify system still supported

### After System Updates
- Re-run distribution detection
- Verify package manager still works
- Check for new dependencies

### Before Using in Production
- Complete all test suites
- Document any distribution-specific issues
- Verify error handling meets requirements

---

## Getting Help

If you encounter issues during testing:

1. **Check the logs**: `cat logs/setup-linux-*.log`
2. **Review the testing analysis**: `docs/TESTING_ANALYSIS.md`
3. **Check known issues**: `docs/DEVELOPER_DOCS.md`
4. **Report issues**: Include your test results and system information

Remember: This is alpha software. Thorough testing is essential before production use.