# Changelog - Safeguard for SUDO Administration Menu

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.3] - 2024-12-05

### Changed
- **Deploy Script Improvements**:
  - Interactive prompts for default user and hostname when no arguments provided
  - Automatically opens SSH session after deployment for immediate testing
  - User stays connected to remote host in script directory
  - More intuitive deployment workflow
  - Added `-t` flag to SSH for proper terminal allocation
- **Script Metadata Updates**:
  - Author updated to Richard Hosgood
  - Repository URL updated to https://github.com/nyrich/safeguard-sudo-menu

## [2.1.2] - 2024-12-05

### Fixed
- **Policy List Filtering**: Hidden directories (like `.svn`) are now excluded from policy lists
  - `list_all_policies()` - Filters out hidden directories starting with `.`
  - `edit_custom_policies()` - Only shows valid custom policies
  - `add_policy_to_server()` - Excludes `.svn` and other hidden directories from selection
  - Prevents confusion when Subversion or other version control metadata appears in policy lists

## [2.1.1] - 2024-12-05

### Fixed
- **User Input Cancellation**: Added ability to cancel operations that require user input
  - Enhanced `get_user_input()` function with optional cancel parameter
  - Users can now enter '0' to cancel when prompted for input in these functions:
    - `install_license()` - Cancel license installation
    - `backup_configuration()` - Cancel backup operation
    - `restore_configuration()` - Cancel restore operation
    - `join_plugin_to_server()` - Cancel plugin join
    - `run_preflight_check()` - Cancel preflight check
    - `view_event_logs()` - Cancel log viewing
    - `search_logs_by_user()` - Cancel log search
    - `search_logs_by_date()` - Cancel date range search
    - `search_logs_custom()` - Cancel custom search
    - `replay_keystroke_log()` - Cancel log replay
    - `verify_hostname_resolution()` - Cancel hostname verification
    - `test_policy_syntax()` - Cancel syntax test
    - `test_command_authorization()` - Cancel authorization test
    - `compare_policy_versions()` - Cancel version comparison
  - Prevents users from being forced to close the script when they enter a menu by mistake
  - Displays "(or '0' to cancel)" in prompts where cancellation is available

### Changed
- `get_user_input()` function signature now accepts fourth parameter for cancel support:
  - `$4` - Optional: allow cancel (yes/no, default: no)
  - Returns 1 if cancelled, 0 if input provided

## [2.1.0] - 2024-12-05

### Added
- **Dynamic Multi-Policy Support**: Policy Management menu now supports unlimited custom policies
  - `list_all_policies()` - Automatically discovers all policies from checked-out directory
  - `edit_custom_policies()` - Dynamic menu to select and edit any custom policy
  - `create_new_custom_policy()` - Create new policies with user-specified names and templates
  - `add_policy_to_server()` - Add custom policies to repository with validation
  - No more hardcoded policy names (webservers, dbservers, appservers removed)
- **Configuration Management**:
  - `edit_pm_settings()` - Direct editor for pm.settings with automatic backup
  - Service restart prompt after settings changes
- **Backup & Restore**:
  - `backup_configuration()` - Complete backup of critical Safeguard directories
  - `restore_configuration()` - Restore from backup with service management
  - Automatic backup manifest generation with restore instructions
  - Backs up /var/opt/quest/qpm4u, /etc/opt/quest/qpm4u, and licenses

### Changed
- **Policy Management Menu Reorganization**:
  - "Checkout Policy" moved to FIRST position (was option 5, now option 1)
  - Menu flow improved: checkout → edit → validate → add → commit
  - Better logical order for policy management workflow
- **Server Management Menu Enhanced**:
  - Added options 9-11 for settings editor, backup, and restore
  - Expanded from 8 to 11 menu options

### Improved
- Policy workflow now follows actual Safeguard best practices:
  1. Checkout to /tmp/policydir
  2. Create/edit custom policies dynamically
  3. Validate with pmcheck
  4. Add to repository with pmpolicy add
  5. Commit changes
- Custom policy creation includes template generation with metadata
- Policy validation integrated into add_policy_to_server function
- Better error messages for missing checkout directory

## [2.0.0] - 2024-12-05

### Added
- Complete script rewrite with comprehensive Safeguard for SUDO 7.4 support
- Prerequisite validation (root user, Safeguard installation check)
- Modular menu system with six main categories:
  - Git Policy Management
  - Policy Management
  - Server Management
  - Plugin Host Management
  - Log Management & Search
  - Diagnostics & Troubleshooting
- Error handling and validation for all operations
- User confirmation prompts for destructive operations
- Logging system with timestamps (writes to /var/log/sudo-menu.log)
- Color-coded output (errors in red, success in green, warnings in yellow)
- Dynamic user input instead of hardcoded values
- Policy validation before commit (automatic pmcheck)
- Interactive log search with multiple filter options
- Dynamic I/O log selection and replay
- Comprehensive help text for all menu options
- Server status checking and reporting
- License management (install, view, usage reports)
- File permission checking and repair
- Plugin join/unjoin functionality
- Pre-flight readiness checks
- Hostname resolution verification
- Command authorization testing
- Debug logging enable/disable
- Audit server connectivity checks
- Error log viewing for all daemons

### Changed
- Replaced hardcoded values with dynamic user input prompts
- Replaced hardcoded dates with user input
- Replaced hardcoded log paths with dynamic selection
- Improved menu organization with logical grouping
- Enhanced policy editing workflow with validation
- Better error messages and user feedback

### Fixed
- Removed syntax error on line 1 (`p '' 2`)
- Fixed missing error handling throughout script
- Fixed unsafe deletion of /tmp/policydir without confirmation
- Fixed lack of policy validation before commits
- Fixed hardcoded values preventing script reusability

### Security
- Added root privilege verification
- Added confirmation prompts for destructive actions
- Added policy syntax validation before applying changes
- Improved input validation and sanitization

## [1.0.0] - Original Release

### Features
- Basic pmgit utility menu (status, enable, disable, update, set, help, import, export)
- Basic policy server functions (license, log search, server info, policy log)
- Policy editing (checkout, edit, commit workflow)
- Multiple policy support (default, webservers, dbservers, appservers)
- Basic log search by user and date
- Hardcoded log replay functionality

### Known Issues
- Syntax error on line 1
- Hardcoded usernames and dates
- No error handling
- No validation checks
- No confirmation prompts
- Missing critical Safeguard features
- Limited to Git and policy management only

---

## Version History Summary

- **2.0.0** - Complete rewrite with comprehensive features, error handling, and proper validation
- **1.0.0** - Original basic menu script with limited functionality

---

## Future Enhancements (Roadmap)

### Completed in 2.1.0
- ✅ Automated backup functionality
- ✅ Configuration file editor (pm.settings)
- ✅ Dynamic multi-policy support

### Planned for 2.2.0
- Batch operations for multiple hosts
- Export/import configuration settings
- Email notifications for critical events
- Advanced reporting and analytics
- Integration with monitoring systems
- Policy templates library

### Planned for 3.0.0
- Web-based interface option
- REST API integration
- Multi-server management
- Centralized logging dashboard
- Compliance reporting
- Automated health checks and remediation

---

## Notes

### Semantic Versioning Format
- **MAJOR.MINOR.PATCH**
  - MAJOR: Incompatible API changes or complete rewrites
  - MINOR: New features, backward compatible
  - PATCH: Bug fixes, backward compatible

### Change Categories
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security-related changes
