#!/bin/bash
#
# Basic Automated Test Suite for Generic Linux Setup System
# Tests core functionality and basic error conditions
#

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
RESULTS_FILE="$TEST_DIR/test-results-$(date +%Y%m%d-%H%M%S).log"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test framework functions
test_start() {
    local test_name="$1"
    echo -e "${BLUE}🧪 Testing: $test_name${NC}"
    echo "TEST: $test_name" >> "$RESULTS_FILE"
    ((TESTS_RUN++))
}

test_pass() {
    local test_name="$1"
    echo -e "${GREEN}✅ PASS: $test_name${NC}"
    echo "PASS: $test_name" >> "$RESULTS_FILE"
    ((TESTS_PASSED++))
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}❌ FAIL: $test_name${NC}"
    echo -e "${RED}   Reason: $reason${NC}"
    echo "FAIL: $test_name - $reason" >> "$RESULTS_FILE"
    ((TESTS_FAILED++))
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    echo -e "${YELLOW}⏭️  SKIP: $test_name${NC}"
    echo -e "${YELLOW}   Reason: $reason${NC}"
    echo "SKIP: $test_name - $reason" >> "$RESULTS_FILE"
}

# Test functions
test_project_structure() {
    test_start "Project Structure"
    
    local required_dirs=("bin" "lib" "config" "logs" "docs" "tests")
    local required_files=("bin/setup-linux" "lib/common.sh" "lib/distro_detect.sh" "lib/package_manager.sh" "lib/logging.sh")
    
    # Check directories
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            test_fail "Project Structure" "Missing directory: $dir"
            return 1
        fi
    done
    
    # Check files
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            test_fail "Project Structure" "Missing file: $file"
            return 1
        fi
    done
    
    # Check script permissions
    if [[ ! -x "$PROJECT_ROOT/bin/setup-linux" ]]; then
        test_fail "Project Structure" "setup-linux is not executable"
        return 1
    fi
    
    test_pass "Project Structure"
}

test_library_loading() {
    test_start "Library Loading"
    
    # Test loading each library
    cd "$PROJECT_ROOT"
    
    if ! source lib/common.sh 2>/dev/null; then
        test_fail "Library Loading" "Failed to source lib/common.sh"
        return 1
    fi
    
    if ! source lib/logging.sh 2>/dev/null; then
        test_fail "Library Loading" "Failed to source lib/logging.sh"
        return 1
    fi
    
    if ! source lib/distro_detect.sh 2>/dev/null; then
        test_fail "Library Loading" "Failed to source lib/distro_detect.sh"
        return 1
    fi
    
    if ! source lib/package_manager.sh 2>/dev/null; then
        test_fail "Library Loading" "Failed to source lib/package_manager.sh"
        return 1
    fi
    
    test_pass "Library Loading"
}

test_function_availability() {
    test_start "Function Availability"
    
    cd "$PROJECT_ROOT"
    source lib/common.sh
    source lib/logging.sh
    source lib/distro_detect.sh
    source lib/package_manager.sh
    
    # Test critical functions exist
    local required_functions=(
        "command_exists"
        "print_status"
        "setup_logging"
        "log_info"
        "detect_distribution"
        "init_package_manager"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" >/dev/null; then
            test_fail "Function Availability" "Function not found: $func"
            return 1
        fi
    done
    
    test_pass "Function Availability"
}

test_distribution_detection() {
    test_start "Distribution Detection"
    
    cd "$PROJECT_ROOT"
    source lib/common.sh
    source lib/logging.sh
    source lib/distro_detect.sh
    
    # Setup minimal logging for test
    LOG_DIR="$PROJECT_ROOT/logs"
    mkdir -p "$LOG_DIR"
    setup_logging "test-distro-detect" >/dev/null 2>&1
    
    if detect_distribution; then
        # Check that global variables are set
        if [[ -z "$DISTRO_ID" ]]; then
            test_fail "Distribution Detection" "DISTRO_ID not set"
            return 1
        fi
        
        if [[ -z "$DISTRO_FAMILY" ]]; then
            test_fail "Distribution Detection" "DISTRO_FAMILY not set"
            return 1
        fi
        
        if [[ -z "$DISTRO_ARCHITECTURE" ]]; then
            test_fail "Distribution Detection" "DISTRO_ARCHITECTURE not set"
            return 1
        fi
        
        test_pass "Distribution Detection"
        echo "   Detected: $DISTRO_NAME $DISTRO_VERSION ($DISTRO_FAMILY, $DISTRO_ARCHITECTURE)"
    else
        test_fail "Distribution Detection" "detect_distribution() returned false"
        return 1
    fi
}

test_package_manager_init() {
    test_start "Package Manager Initialization"
    
    cd "$PROJECT_ROOT"
    source lib/common.sh
    source lib/logging.sh
    source lib/distro_detect.sh
    source lib/package_manager.sh
    
    # Setup minimal logging for test
    LOG_DIR="$PROJECT_ROOT/logs"
    mkdir -p "$LOG_DIR"
    setup_logging "test-package-manager" >/dev/null 2>&1
    
    # First detect distribution
    if ! detect_distribution; then
        test_fail "Package Manager Initialization" "Distribution detection failed"
        return 1
    fi
    
    if init_package_manager; then
        # Check that package manager variables are set
        if [[ -z "$PACKAGE_MANAGER" ]]; then
            test_fail "Package Manager Initialization" "PACKAGE_MANAGER not set"
            return 1
        fi
        
        if [[ -z "$PACKAGE_MANAGER_INSTALL_CMD" ]]; then
            test_fail "Package Manager Initialization" "PACKAGE_MANAGER_INSTALL_CMD not set"
            return 1
        fi
        
        test_pass "Package Manager Initialization"
        echo "   Package Manager: $PACKAGE_MANAGER"
    else
        test_fail "Package Manager Initialization" "init_package_manager() returned false"
        return 1
    fi
}

test_logging_system() {
    test_start "Logging System"
    
    cd "$PROJECT_ROOT"
    source lib/common.sh
    source lib/logging.sh
    
    # Setup logging
    LOG_DIR="$PROJECT_ROOT/logs"
    mkdir -p "$LOG_DIR"
    setup_logging "test-logging"
    
    # Test that log file was created
    if [[ ! -f "$LOG_FILE" ]]; then
        test_fail "Logging System" "Log file not created"
        return 1
    fi
    
    # Test logging functions
    log_info "Test info message"
    log_warn "Test warning message"
    log_error "Test error message"
    
    # Check that messages were written
    if ! grep -q "Test info message" "$LOG_FILE"; then
        test_fail "Logging System" "Info message not written to log"
        return 1
    fi
    
    if ! grep -q "Test warning message" "$LOG_FILE"; then
        test_fail "Logging System" "Warning message not written to log"
        return 1
    fi
    
    if ! grep -q "Test error message" "$LOG_FILE"; then
        test_fail "Logging System" "Error message not written to log"
        return 1
    fi
    
    test_pass "Logging System"
    echo "   Log file: $LOG_FILE"
}

test_main_script_execution() {
    test_start "Main Script Execution"
    
    cd "$PROJECT_ROOT"
    
    # Run the main script and capture output
    if ./bin/setup-linux >/dev/null 2>&1; then
        # Check that a log file was created
        local latest_log=$(ls -t logs/setup-linux-*.log 2>/dev/null | head -1)
        if [[ -z "$latest_log" ]]; then
            test_fail "Main Script Execution" "No log file created"
            return 1
        fi
        
        # Check that log contains expected content
        if ! grep -q "Distribution detection complete" "$latest_log"; then
            test_fail "Main Script Execution" "Distribution detection not found in log"
            return 1
        fi
        
        if ! grep -q "Package manager initialized" "$latest_log"; then
            test_fail "Main Script Execution" "Package manager initialization not found in log"
            return 1
        fi
        
        test_pass "Main Script Execution"
        echo "   Log file: $latest_log"
    else
        test_fail "Main Script Execution" "Script execution failed"
        return 1
    fi
}

test_error_handling() {
    test_start "Error Handling"
    
    cd "$PROJECT_ROOT"
    source lib/common.sh
    source lib/logging.sh
    
    # Test that functions handle missing dependencies gracefully
    LOG_DIR="$PROJECT_ROOT/logs"
    mkdir -p "$LOG_DIR"
    setup_logging "test-error-handling" >/dev/null 2>&1
    
    # Test command_exists with non-existent command
    if command_exists "nonexistent_command_12345"; then
        test_fail "Error Handling" "command_exists should return false for non-existent commands"
        return 1
    fi
    
    # Test print_status function
    if ! print_status "success" "Test message" >/dev/null 2>&1; then
        test_fail "Error Handling" "print_status failed"
        return 1
    fi
    
    test_pass "Error Handling"
}

test_documentation_presence() {
    test_start "Documentation Presence"
    
    local required_docs=(
        "README.md"
        "CHANGELOG.md"
        "docs/MANUAL_TESTING_GUIDE.md"
        "docs/DEVELOPER_DOCS.md"
        "docs/TESTING_ANALYSIS.md"
    )
    
    for doc in "${required_docs[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$doc" ]]; then
            test_fail "Documentation Presence" "Missing documentation: $doc"
            return 1
        fi
        
        # Check that file is not empty
        if [[ ! -s "$PROJECT_ROOT/$doc" ]]; then
            test_fail "Documentation Presence" "Empty documentation file: $doc"
            return 1
        fi
    done
    
    test_pass "Documentation Presence"
}

# Main test execution
main() {
    echo "🧪 Generic Linux Setup System - Basic Test Suite"
    echo "=================================================="
    echo "📝 Results will be logged to: $RESULTS_FILE"
    echo ""
    
    # Initialize results file
    cat > "$RESULTS_FILE" << EOF
Generic Linux Setup System - Test Results
==========================================
Date: $(date)
System: $(uname -a)
Tester: $(whoami)
==========================================

EOF
    
    # Run tests
    test_project_structure
    test_library_loading
    test_function_availability
    test_distribution_detection
    test_package_manager_init
    test_logging_system
    test_main_script_execution
    test_error_handling
    test_documentation_presence
    
    # Results summary
    echo ""
    echo "🏁 Test Summary"
    echo "=============="
    echo -e "Total Tests: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    # Write summary to results file
    cat >> "$RESULTS_FILE" << EOF

==========================================
Test Summary
==========================================
Total Tests: $TESTS_RUN
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Success Rate: $(( TESTS_PASSED * 100 / TESTS_RUN ))%
EOF
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        echo "✅ The system is ready for the next development phase."
        exit 0
    else
        echo -e "${RED}💥 Some tests failed!${NC}"
        echo "❌ Please review the failures and fix issues before proceeding."
        exit 1
    fi
}

# Run main function
main "$@"