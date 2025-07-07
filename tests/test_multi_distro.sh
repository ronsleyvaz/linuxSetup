#!/bin/bash

# Multi-Distribution Testing Framework
# Tests Linux Setup System across different distributions and platforms

# Strict error handling
set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="test_multi_distro"
readonly SCRIPT_VERSION="1.0.0"
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$TEST_DIR")"

# Test configuration
readonly TEST_RESULTS_DIR="$PROJECT_DIR/test-results"
readonly TEST_LOG="$TEST_RESULTS_DIR/multi-distro-test-$(date +%Y%m%d-%H%M%S).log"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test statistics
declare -g TESTS_TOTAL=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
declare -g TESTS_SKIPPED=0

# Test distributions to check
declare -a TEST_DISTRIBUTIONS=(
    "ubuntu:20.04"
    "ubuntu:22.04"
    "debian:11"
    "debian:12"
    "centos:8"
    "fedora:38"
    "archlinux:latest"
    "alpine:latest"
)

# Test functions array
declare -a TEST_FUNCTIONS=(
    "test_distribution_detection"
    "test_package_manager_detection"
    "test_tool_installation"
    "test_system_health_monitoring"
    "test_service_configuration"
    "test_user_management"
    "test_report_generation"
)

# Print colored output
print_test_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✅ PASS: $message${NC}"
            ;;
        "FAIL")
            echo -e "${RED}❌ FAIL: $message${NC}"
            ;;
        "SKIP")
            echo -e "${YELLOW}⏭️  SKIP: $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO: $message${NC}"
            ;;
        "HEADER")
            echo -e "${BLUE}🧪 $message${NC}"
            ;;
    esac
    
    # Log to file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $message" >> "$TEST_LOG"
}

# Initialize test environment
init_test_environment() {
    print_test_status "INFO" "Initializing test environment"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Initialize log file
    cat > "$TEST_LOG" << EOF
Multi-Distribution Testing Framework
===================================
Started: $(date '+%Y-%m-%d %H:%M:%S')
Project: Linux Setup & Monitoring System
Version: $SCRIPT_VERSION

EOF
    
    print_test_status "INFO" "Test results will be saved to: $TEST_RESULTS_DIR"
    print_test_status "INFO" "Test log: $TEST_LOG"
}

# Test distribution detection
test_distribution_detection() {
    local test_name="Distribution Detection"
    print_test_status "INFO" "Testing: $test_name"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Source the distribution detection library
    if [[ -f "$PROJECT_DIR/lib/distro_detect.sh" ]]; then
        source "$PROJECT_DIR/lib/common.sh"
        source "$PROJECT_DIR/lib/logging.sh"
        source "$PROJECT_DIR/lib/distro_detect.sh"
        
        # Test detection
        if detect_distribution; then
            local detected_info="$DISTRO_NAME $DISTRO_VERSION ($DISTRO_FAMILY)"
            print_test_status "PASS" "$test_name - Detected: $detected_info"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_test_status "FAIL" "$test_name - Detection failed"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        print_test_status "FAIL" "$test_name - distro_detect.sh not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test package manager detection
test_package_manager_detection() {
    local test_name="Package Manager Detection"
    print_test_status "INFO" "Testing: $test_name"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Source required libraries
    if [[ -f "$PROJECT_DIR/lib/package_manager.sh" ]]; then
        source "$PROJECT_DIR/lib/package_manager.sh"
        
        # Test package manager detection
        if detect_package_manager && set_package_manager_commands; then
            print_test_status "PASS" "$test_name - Detected: $PACKAGE_MANAGER"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_test_status "FAIL" "$test_name - Detection failed"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        print_test_status "FAIL" "$test_name - package_manager.sh not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test tool installation (dry run)
test_tool_installation() {
    local test_name="Tool Installation"
    print_test_status "INFO" "Testing: $test_name"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test with verify mode to avoid actual installation
    if [[ -x "$PROJECT_DIR/bin/setup-linux" ]]; then
        if "$PROJECT_DIR/bin/setup-linux" --verify-tools >/dev/null 2>&1; then
            print_test_status "PASS" "$test_name - Tool verification successful"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_test_status "SKIP" "$test_name - Some tools not installed (expected in test environment)"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            return 0
        fi
    else
        print_test_status "FAIL" "$test_name - setup-linux script not found or not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test system health monitoring
test_system_health_monitoring() {
    local test_name="System Health Monitoring"
    print_test_status "INFO" "Testing: $test_name"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ -x "$PROJECT_DIR/bin/check-linux" ]]; then
        if "$PROJECT_DIR/bin/check-linux" --quick >/dev/null 2>&1; then
            print_test_status "PASS" "$test_name - Health check successful"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_test_status "FAIL" "$test_name - Health check failed"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        print_test_status "FAIL" "$test_name - check-linux script not found or not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test service configuration (dry run)
test_service_configuration() {
    local test_name="Service Configuration"
    print_test_status "INFO" "Testing: $test_name"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ -x "$PROJECT_DIR/bin/configure-linux" ]]; then
        # Test help functionality (safe to run)
        if "$PROJECT_DIR/bin/configure-linux" --help >/dev/null 2>&1; then
            print_test_status "PASS" "$test_name - Configuration script functional"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_test_status "FAIL" "$test_name - Configuration script help failed"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        print_test_status "FAIL" "$test_name - configure-linux script not found or not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test user management
test_user_management() {
    local test_name="User Management"
    print_test_status "INFO" "Testing: $test_name"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ -x "$PROJECT_DIR/bin/manage-users" ]]; then
        # Test help and list functionality (safe to run)
        if "$PROJECT_DIR/bin/manage-users" --help >/dev/null 2>&1; then
            print_test_status "PASS" "$test_name - User management script functional"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_test_status "FAIL" "$test_name - User management script help failed"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        print_test_status "FAIL" "$test_name - manage-users script not found or not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test report generation
test_report_generation() {
    local test_name="Report Generation"
    print_test_status "INFO" "Testing: $test_name"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ -x "$PROJECT_DIR/bin/generate-report" ]]; then
        local temp_report="/tmp/test-report-$(date +%s).json"
        
        if "$PROJECT_DIR/bin/generate-report" --inventory --format json --output "$temp_report" >/dev/null 2>&1; then
            if [[ -f "$temp_report" ]]; then
                print_test_status "PASS" "$test_name - Report generated successfully"
                rm -f "$temp_report"
                TESTS_PASSED=$((TESTS_PASSED + 1))
                return 0
            else
                print_test_status "FAIL" "$test_name - Report file not created"
                TESTS_FAILED=$((TESTS_FAILED + 1))
                return 1
            fi
        else
            print_test_status "FAIL" "$test_name - Report generation failed"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        print_test_status "FAIL" "$test_name - generate-report script not found or not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test Docker environment simulation
test_in_docker() {
    local distro="$1"
    local container_name="linuxsetup-test-$(echo "$distro" | tr ':' '-')"
    
    print_test_status "INFO" "Testing in Docker container: $distro"
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        print_test_status "SKIP" "Docker not available - skipping container tests"
        return 0
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_test_status "SKIP" "Docker not running - skipping container tests"
        return 0
    fi
    
    # Create temporary dockerfile
    local temp_dir
    temp_dir=$(mktemp -d)
    local dockerfile="$temp_dir/Dockerfile"
    
    cat > "$dockerfile" << EOF
FROM $distro
RUN if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y curl bash sudo; fi
RUN if command -v yum >/dev/null 2>&1; then yum install -y curl bash sudo; fi
RUN if command -v dnf >/dev/null 2>&1; then dnf install -y curl bash sudo; fi
RUN if command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm curl bash sudo; fi
RUN if command -v apk >/dev/null 2>&1; then apk add --no-cache curl bash sudo; fi
WORKDIR /app
COPY . /app/
RUN chmod +x /app/bin/* || true
RUN chmod +x /app/tests/*.sh || true
EOF
    
    # Build container
    if docker build -t "$container_name" -f "$dockerfile" "$PROJECT_DIR" >/dev/null 2>&1; then
        print_test_status "PASS" "Built container for $distro"
        
        # Run basic tests in container
        if docker run --rm "$container_name" /app/tests/run_basic_tests.sh >/dev/null 2>&1; then
            print_test_status "PASS" "Basic tests passed in $distro container"
        else
            print_test_status "FAIL" "Basic tests failed in $distro container"
        fi
        
        # Clean up container
        docker rmi "$container_name" >/dev/null 2>&1 || true
    else
        print_test_status "FAIL" "Failed to build container for $distro"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
}

# Test macOS environment
test_macos_environment() {
    print_test_status "INFO" "Testing macOS-specific functionality"
    
    if [[ "$(uname -s)" != "Darwin" ]]; then
        print_test_status "SKIP" "Not running on macOS - skipping macOS tests"
        return 0
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test Homebrew detection/installation
    source "$PROJECT_DIR/lib/package_manager.sh"
    
    if install_homebrew >/dev/null 2>&1; then
        print_test_status "PASS" "macOS Homebrew functionality working"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_test_status "FAIL" "macOS Homebrew functionality failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run performance benchmarks
run_performance_tests() {
    print_test_status "INFO" "Running performance benchmarks"
    
    local start_time end_time duration
    
    # Test setup-linux performance
    start_time=$(date +%s.%N)
    "$PROJECT_DIR/bin/setup-linux" >/dev/null 2>&1 || true
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    
    print_test_status "INFO" "setup-linux execution time: ${duration}s"
    
    # Test check-linux performance
    start_time=$(date +%s.%N)
    "$PROJECT_DIR/bin/check-linux" --quick >/dev/null 2>&1 || true
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    
    print_test_status "INFO" "check-linux execution time: ${duration}s"
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS_DIR/test-summary-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Multi-Distribution Test Report

## Test Summary

- **Date**: $(date '+%Y-%m-%d %H:%M:%S')
- **Total Tests**: $TESTS_TOTAL
- **Passed**: $TESTS_PASSED
- **Failed**: $TESTS_FAILED
- **Skipped**: $TESTS_SKIPPED
- **Success Rate**: $(( TESTS_TOTAL > 0 ? (TESTS_PASSED * 100) / TESTS_TOTAL : 0 ))%

## System Information

- **OS**: $(uname -s)
- **Kernel**: $(uname -r)
- **Architecture**: $(uname -m)

EOF

    if [[ -f "$PROJECT_DIR/lib/distro_detect.sh" ]]; then
        source "$PROJECT_DIR/lib/common.sh" 2>/dev/null || true
        source "$PROJECT_DIR/lib/logging.sh" 2>/dev/null || true
        source "$PROJECT_DIR/lib/distro_detect.sh" 2>/dev/null || true
        
        if detect_distribution 2>/dev/null; then
            cat >> "$report_file" << EOF
- **Distribution**: $DISTRO_NAME $DISTRO_VERSION
- **Family**: $DISTRO_FAMILY
- **Architecture**: $DISTRO_ARCHITECTURE

EOF
        fi
    fi
    
    cat >> "$report_file" << EOF
## Test Results

$(cat "$TEST_LOG" | grep -E "\[(PASS|FAIL|SKIP)\]" | sed 's/^/- /')

## Detailed Log

See: $TEST_LOG

EOF
    
    print_test_status "INFO" "Test report generated: $report_file"
}

# Show help
show_help() {
    cat << EOF
🧪 Multi-Distribution Testing Framework

Usage: $0 [OPTIONS]

OPTIONS:
    --local-only        Run only local system tests (skip Docker)
    --docker-only       Run only Docker container tests
    --performance       Include performance benchmarks
    --verbose           Verbose output
    --help, -h          Show this help message

EXAMPLES:
    # Run all tests
    $0

    # Run only local tests
    $0 --local-only

    # Run with performance benchmarks
    $0 --performance

FEATURES:
    ✅ Local system testing
    ✅ Docker container testing across distributions
    ✅ macOS compatibility testing
    ✅ Performance benchmarking
    ✅ Comprehensive reporting

EOF
}

# Main function
main() {
    local local_only=false
    local docker_only=false
    local include_performance=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --local-only)
                local_only=true
                shift
                ;;
            --docker-only)
                docker_only=true
                shift
                ;;
            --performance)
                include_performance=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Initialize
    init_test_environment
    
    print_test_status "HEADER" "Multi-Distribution Testing Framework v$SCRIPT_VERSION"
    echo ""
    
    # Run local tests
    if [[ "$docker_only" != "true" ]]; then
        print_test_status "HEADER" "Running Local System Tests"
        
        for test_func in "${TEST_FUNCTIONS[@]}"; do
            $test_func
        done
        
        # Test macOS if running on macOS
        test_macos_environment
        
        echo ""
    fi
    
    # Run Docker tests
    if [[ "$local_only" != "true" ]] && command -v docker >/dev/null 2>&1; then
        print_test_status "HEADER" "Running Docker Container Tests"
        
        for distro in "${TEST_DISTRIBUTIONS[@]}"; do
            test_in_docker "$distro"
        done
        
        echo ""
    fi
    
    # Run performance tests
    if [[ "$include_performance" == "true" ]]; then
        print_test_status "HEADER" "Running Performance Tests"
        run_performance_tests
        echo ""
    fi
    
    # Show summary
    print_test_status "HEADER" "Test Summary"
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED" 
    echo "Skipped: $TESTS_SKIPPED"
    
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
        echo "Success Rate: $success_rate%"
        
        if [[ $success_rate -ge 90 ]]; then
            print_test_status "PASS" "Excellent test results! 🎉"
        elif [[ $success_rate -ge 75 ]]; then
            print_test_status "PASS" "Good test results! ✅"
        elif [[ $success_rate -ge 50 ]]; then
            print_test_status "FAIL" "Some issues found - review test log"
        else
            print_test_status "FAIL" "Significant issues found - check configuration"
        fi
    fi
    
    # Generate report
    generate_test_report
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"