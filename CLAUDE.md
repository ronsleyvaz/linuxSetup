# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Generic Linux Setup & Monitoring System.

## Project Context

This is a generic Linux setup and monitoring system based on the successful piSetup toolkit architecture, extended for multi-distribution support. The project follows agile methodology with user story-driven development.

## User Preferences and Requirements

### Development Approach
- **Step-by-step implementation**: Complete each step absolutely before proceeding to the next
- **MVP approach**: Get working features before adding complexity
- **User story focus**: Implement specific user stories completely
- **Act in user's best interests**: Make decisions that benefit the project's success
- **Agile methodology**: Working features over comprehensive planning

### Quality Standards
- **DO NOT say something is working without making sure it is**: Always verify functionality
- **Do not inflate functionality and deceive**: Be honest about what works and what doesn't
- **Always execute step by step**: Never skip steps or assume things work
- **Always update documentation as you go**: Keep all docs current with development
- **Always store logs and use for debugging**: Comprehensive logging and audit trails
- **Keep track of everything**: Errors, logs, progress must be tracked and used immediately

### Testing Requirements
- **Verify functionality**: Test everything before marking as complete
- **Document testing methodology**: Explain how things were tested
- **Create comprehensive testing procedures**: Both automated and manual testing
- **Test on actual systems**: Don't just assume compatibility
- **Provide detailed testing instructions**: Users need to know how to test themselves

### Documentation Standards
- **Complete documentation suite**: README, CHANGELOG, developer docs, user guides
- **Professional-grade documentation**: Comprehensive and well-structured
- **Update all documentation**: Changelogs, readme, developer guides, user stories, unit tests
- **Testing analysis**: Document what's tested, what isn't, and confidence levels
- **Manual testing guides**: Step-by-step procedures for users

### Architecture Preferences
- **Modular design**: Clean separation of concerns
- **Extensible architecture**: Easy to add new features and distributions
- **Comprehensive error handling**: Graceful degradation and informative messages
- **Detailed logging**: Full audit trails with timestamps and log levels
- **Multi-distribution support**: Abstract away distribution differences

## System Environment
- **Primary system**: Debian 12 (bookworm) ARM64
- **Available systems**: Ubuntu install, Proxmox server, Pi5, macOS
- **Target distributions**: Ubuntu (focus first), then CentOS, Fedora, Arch
- **Package managers**: APT (primary), then YUM/DNF, Pacman, Zypper, APK

## Current Project Status

### Completed (v0.1.0-alpha)
- ✅ Multi-distribution detection system
- ✅ Package manager abstraction layer  
- ✅ Comprehensive logging infrastructure
- ✅ Modular project architecture
- ✅ Complete documentation suite
- ✅ Automated test framework (9 tests, 100% pass rate)
- ✅ Manual testing procedures

### Next Priority (v0.2.0)
- 🔄 Essential tools installation (User Story 1.2)
- 🔄 Package manager-specific tool mapping
- 🔄 Batch installation with error recovery
- 🔄 Multi-distribution testing

### Implementation Principles
1. **User Story 1.1 Complete**: Multi-distribution setup foundation ✅
2. **User Story 1.2 Next**: Essential tools installation (24+ tools)
3. **User Story 2.1 Following**: Real-time system status monitoring
4. **Always complete current story before starting next**

## Development Workflow

### Before Starting New Features
1. Read current user stories and PRD
2. Update todo list with specific tasks
3. Mark tasks in progress/completed as work proceeds
4. Test functionality thoroughly before marking complete
5. Update all documentation (README, CHANGELOG, developer docs)

### Testing Requirements
1. **Run automated test suite**: `./tests/run_basic_tests.sh`
2. **Test main functionality**: `./bin/setup-linux`
3. **Verify log output**: Check all operations logged correctly
4. **Document what was tested**: Update testing analysis
5. **Provide manual testing steps**: Clear instructions for users

### Documentation Updates Required
- README.md: Current functionality and status
- CHANGELOG.md: All changes with version numbers
- docs/DEVELOPER_DOCS.md: Architecture and development info
- docs/MANUAL_TESTING_GUIDE.md: Testing procedures
- docs/TESTING_ANALYSIS.md: What's tested and confidence levels

## Code Quality Standards

### Bash Best Practices
- Use strict error handling: `set -euo pipefail`
- Quote all variables: `"$variable"`
- Use local variables in functions
- Comprehensive error handling with graceful degradation
- Consistent naming conventions (see DEVELOPER_DOCS.md)

### Logging Requirements
- Log all operations with appropriate levels (DEBUG, INFO, WARN, ERROR)
- Include command execution logging
- Timestamp all entries
- Create audit trails for debugging
- Store logs and use for immediate issue resolution

### Testing Standards
- Test each component thoroughly before integration
- Create both automated and manual tests
- Document testing methodology and limitations
- Provide clear testing instructions for users
- Maintain testing confidence levels and gap analysis

## Specific Implementation Guidance

### Distribution Support Priority
1. **Debian/Ubuntu** (APT): Primary focus, already working
2. **CentOS/RHEL** (YUM/DNF): High priority
3. **Fedora** (DNF): High priority  
4. **Arch Linux** (Pacman): Medium priority
5. **openSUSE** (Zypper): Medium priority
6. **Alpine** (APK): Low priority

### Essential Tools for User Story 1.2
Based on piSetup success, implement these 24+ tools:
- **Core Development**: git, vim, curl, wget, build-essential
- **Terminal Tools**: screen, tmux, tree, htop, iotop, iftop
- **Network Tools**: nmap, tcpdump, rsync, nc, avahi-utils
- **Archive Tools**: zip, unzip, tar
- **Productivity**: fzf, bat, jq
- **System Tools**: lsof, ss, iostat, vmstat

### Error Handling Philosophy
- Never fail silently
- Provide informative error messages
- Log all failures with context
- Offer recovery suggestions when possible
- Continue operation when non-critical components fail

## Success Criteria

### For Each Development Step
- ✅ All functionality verified working
- ✅ Automated tests passing
- ✅ Manual testing procedures documented
- ✅ All documentation updated
- ✅ Confidence level assessed and documented
- ✅ Clear next steps identified

### For User Story Completion  
- ✅ User story acceptance criteria met
- ✅ Multi-distribution testing completed where possible
- ✅ Error conditions tested and handled
- ✅ Performance acceptable
- ✅ Security considerations addressed
- ✅ User can follow documented procedures successfully

## Communication Style
- Be direct and honest about functionality status
- Explain testing methodology and limitations
- Provide clear next steps and requirements
- Document everything thoroughly
- Ask for confirmation before proceeding to next major step

Remember: The goal is a robust, well-tested, multi-distribution Linux setup system that users can rely on. Quality and thoroughness over speed.