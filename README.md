# Safeguard for SUDO 7.4 - Administration Menu

A comprehensive, menu-driven Bash script for managing One Identity Safeguard for SUDO 7.4 deployments.

## Version

**Current Version:** 2.1.3
**Release Date:** 2025-12-05
**Supported Product:** One Identity Safeguard for SUDO 7.4

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Author

Richard Hosgood

## Repository

https://github.com/nyrich/safeguard-sudo-menu

## Features

### Git Policy Management
- View Git integration status
- Enable/disable Git policy management
- Update policy from Git repository
- Configure Git settings
- Export/import policies to/from Git
- Git integration help

### Policy Management
- **Dynamic Multi-Policy Support:** Create and manage unlimited custom policies
- **Checkout Policy:** Checkout policy repository to temporary directory (option 1)
- **Edit Default Policy:** Modify the main sudoers policy
- **Edit Custom Policies:** Select from dynamically discovered policies to edit
- **Create New Custom Policy:** Create policies with custom names and templates
- **List All Policies:** View all available policies in checked-out directory
- **Add Policy to Server:** Add custom policies to repository with validation
- Automatic policy syntax validation before commit
- View policy revision history
- Compare different policy versions
- Check if production matches master
- Sync production policy from master
- Safe cleanup of temporary directories

### Server Management
- View server configuration
- List policy assignments
- Check server status
- View and install licenses
- Generate license usage reports
- Check and fix file permissions
- **Edit pm.settings:** Direct configuration file editing with automatic backup
- **Backup Configuration:** Comprehensive backup of all critical directories
- **Restore Configuration:** Full restore from backup with service management

### Plugin Host Management
- View plugin configuration
- Check server availability
- Join/unjoin plugin hosts to/from policy servers
- View cached policy status
- Run pre-flight installation checks

### Log Management & Search
- View recent event logs
- Search logs by user
- Search logs by date range
- Custom log searches
- List available I/O (keystroke) logs
- Replay keystroke sessions
- View log statistics

### Diagnostics & Troubleshooting
- Verify hostname resolution
- Display system ID
- Test policy syntax
- Simulate command authorization
- Enable/disable debug logging
- View daemon error logs
- Check audit server connectivity

## Requirements

### System Requirements
- **Operating System:** Linux, Unix, or macOS
- **Privileges:** Root/sudo access required
- **Product:** One Identity Safeguard for SUDO 7.4 installed
- **Configuration:** Policy server or plugin host configured

### Dependencies
- Bash 4.0 or later
- Standard Unix utilities (cat, tail, find, etc.)
- Safeguard for SUDO commands in `/opt/quest/sbin/`

## Installation

1. **Download the script:**
   ```bash
   git clone <repository-url>
   cd safeguard-sudo-menu
   ```

2. **Make the script executable:**
   ```bash
   chmod +x sudo-menu.sh
   ```

3. **Verify Safeguard installation:**
   ```bash
   ls -la /opt/quest/sbin/
   ```

## Usage

### Running the Script

```bash
sudo ./sudo-menu.sh
```

The script will:
1. Verify you're running as root
2. Check Safeguard for SUDO installation
3. Display the main menu

### Main Menu Navigation

```
=========================================
  Safeguard for SUDO 7.4
  Administration Menu v2.0.0
=========================================

ADMINISTRATIVE FUNCTIONS:
  1)  Git Policy Management
  2)  Policy Management
  3)  Server Management
  4)  Plugin Host Management
  5)  Log Management & Search
  6)  Diagnostics & Troubleshooting

INFORMATION:
  v)  Version Information
  c)  View Changelog
  a)  About This Script

  q)  Exit
```

### Common Workflows

#### Editing and Committing Policy

1. Select `2) Policy Management`
2. Select `5) Checkout Policy`
3. Select `1) Edit Default Policy` (or other policy)
4. Make your changes in the editor
5. Select `6) Validate Policy Syntax`
6. Select `7) Commit Policy Changes`
7. Select `12) Clean Temp Directory`

#### Searching Logs

1. Select `5) Log Management & Search`
2. Select `2) Search Logs by User`
3. Enter username when prompted
4. Optionally enter date filter
5. Review results

#### Joining a Plugin Host

1. Select `4) Plugin Host Management`
2. Select `3) Join Plugin to Server`
3. Enter policy server hostname/IP
4. Confirm the action
5. Verify with `1) View Plugin Configuration`

## Configuration

### Default Paths

The script uses these default paths (configurable in the script):

```bash
QUEST_BIN="/opt/quest/sbin"              # Safeguard binaries
QUEST_CONFIG="/etc/opt/quest/qpm4u"      # Configuration files
QUEST_VAR="/var/opt/quest/qpm4u"         # Variable data
POLICY_DIR="${QUEST_CONFIG}/policy"      # Policy files
TEMP_POLICY_DIR="/tmp/policydir"         # Temporary policy checkout
LOG_DIR="${QUEST_VAR}"                   # Log files
SCRIPT_LOG="/var/log/sudo-menu.log"      # Script log
```

### Customization

To customize paths or settings:

1. Edit the "Global Variables" section at the top of `sudo-menu.sh`
2. Modify the paths as needed for your environment
3. Save and test the script

## Logging

All script actions are logged to `/var/log/sudo-menu.log` with timestamps:

```
[2025-12-05 10:30:15] === Safeguard Administration Menu Started ===
[2025-12-05 10:30:15] User: root
[2025-12-05 10:30:15] Hostname: server01.example.com
[2025-12-05 10:30:45] Executing: /opt/quest/sbin/pmpolicy log
[2025-12-05 10:30:45] Command completed successfully
```

## Error Handling

The script includes comprehensive error handling:

- **Root Check:** Verifies script is run with root privileges
- **Installation Check:** Confirms Safeguard is installed
- **Command Validation:** Checks if commands exist before execution
- **User Confirmation:** Prompts before destructive operations
- **Policy Validation:** Validates syntax before commits
- **Input Validation:** Ensures required inputs are provided

## Security

### Safety Features

- Root privilege verification
- Confirmation prompts for destructive actions
- Policy syntax validation before applying changes
- Input validation and sanitization
- Detailed logging of all operations
- Temporary directory cleanup

### Best Practices

1. **Always validate** policies before committing
2. **Review changes** using the diff function
3. **Backup** before making major changes
4. **Test** in non-production environments first
5. **Monitor** the script log for issues

## Version Management

### Semantic Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** format
- **MAJOR:** Incompatible changes or rewrites
- **MINOR:** New features, backward compatible
- **PATCH:** Bug fixes, backward compatible

### Updating Version

Use the provided helper script:

```bash
./update-version.sh 2.1.0 "Added batch operations feature"
```

This will:
1. Update the VERSION file
2. Add entry to CHANGELOG.md
3. Prompt for git tagging

### Manual Version Update

1. Edit `VERSION` file with new version number
2. Update `CHANGELOG.md` with changes
3. Commit changes to git
4. Create git tag:
   ```bash
   git tag -a v2.1.0 -m "Release 2.1.0"
   git push origin v2.1.0
   ```

## Troubleshooting

### Script won't run

**Problem:** Permission denied  
**Solution:**
```bash
chmod +x sudo-menu.sh
sudo ./sudo-menu.sh
```

### Commands not found

**Problem:** "Command not found" errors  
**Solution:**
```bash
# Verify Safeguard installation
ls -la /opt/quest/sbin/

# Check if you're on a plugin-only host
/opt/quest/sbin/pmplugininfo
```

### Policy validation fails

**Problem:** Policy syntax errors  
**Solution:**
1. Use menu option to validate policy
2. Review error messages
3. Edit policy to fix errors
4. Validate again before committing

## Support

### Documentation

- **Product Documentation:** [One Identity Product Documentation](https://support.oneidentity.com/safeguard-for-sudo/7.4/technical-documents)
- **Script Changelog:** See `CHANGELOG.md`
- **Script Log:** `/var/log/sudo-menu.log`

### Getting Help

1. Check the script log: `/var/log/sudo-menu.log`
2. Review CHANGELOG.md for known issues
3. Consult Safeguard for SUDO 7.4 documentation
4. Contact One Identity support

## Contributing

### Reporting Issues

When reporting issues, include:

1. Script version (from VERSION file)
2. Safeguard for SUDO version
3. Operating system and version
4. Relevant log entries from `/var/log/sudo-menu.log`
5. Steps to reproduce the issue

### Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Update CHANGELOG.md
5. Test thoroughly
6. Submit a pull request

## License

This script is provided as-is for managing One Identity Safeguard for SUDO deployments.

## Credits

**Author:** Richard Hosgood  
**Product:** One Identity Safeguard for SUDO 7.4  
**Documentation:** Based on Safeguard for SUDO 7.4 Administration Guide

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a complete history of changes.

## Files

```
.
├── sudo-menu.sh          # Main menu script
├── VERSION               # Current version number
├── CHANGELOG.md          # Detailed change history
├── README.md             # This file
├── update-version.sh     # Version management helper
└── .agent/
    └── safeguard-sudo-expert.md  # Expert agent knowledge base
```

## Quick Reference

### Key Commands Used

| Command | Purpose |
|---------|---------|
| `pmsrvconfig` | Configure policy servers |
| `pmsrvinfo` | Display server configuration |
| `pmsrvcheck` | Check server status |
| `pmpolicy` | Manage security policy |
| `pmcheck` | Validate policy syntax |
| `pmgit` | Git integration |
| `pmjoin_plugin` | Join/unjoin plugins |
| `pmplugininfo` | View plugin configuration |
| `pmlicense` | License management |
| `pmlog` | View event logs |
| `pmlogsearch` | Search logs |
| `pmreplay` | Replay keystroke logs |
| `pmcheckperms` | Check/fix permissions |

### Exit Codes

- **0:** Success
- **1:** General error
- **11:** Password prompt (pmcheck)
- **12:** Command rejected (pmcheck)
- **13:** Syntax error (pmcheck)

---

**Last Updated:** 2025-12-05  
**Version:** 2.1.3
