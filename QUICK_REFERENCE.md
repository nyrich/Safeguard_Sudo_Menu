# Quick Reference - Safeguard for SUDO Administration Menu

## Starting the Script
```bash
sudo ./sudo-menu.sh
```

## Main Menu (Quick Keys)

| Key | Function |
|-----|----------|
| 1 | Git Policy Management |
| 2 | Policy Management |
| 3 | Server Management |
| 4 | Plugin Host Management |
| 5 | Log Management & Search |
| 6 | Diagnostics & Troubleshooting |
| v | Version Information |
| c | View Changelog |
| a | About This Script |
| q | Exit |

## Common Tasks

### Edit Policy
```
Main Menu → 2 → 5 (checkout) → 1 (edit) → 6 (validate) → 7 (commit) → 12 (cleanup)
```

### Search Logs for User
```
Main Menu → 5 → 2 (search by user) → enter username
```

### Check Server Status
```
Main Menu → 3 → 3 (check status)
```

### View License Usage
```
Main Menu → 3 → 6 (usage report)
```

### Join Plugin Host
```
Main Menu → 4 → 3 (join) → enter server hostname
```

### Enable Debug Logging
```
Main Menu → 6 → 5 (enable debug)
```

## File Locations

### Script Files
- Main Script: `./sudo-menu.sh`
- Version: `./VERSION`
- Changelog: `./CHANGELOG.md`
- Documentation: `./README.md`

### Safeguard Paths
- Commands: `/opt/quest/sbin/`
- Config: `/etc/opt/quest/qpm4u/`
- Policies: `/etc/opt/quest/qpm4u/policy/`
- Logs: `/var/opt/quest/qpm4u/`
- Script Log: `/var/log/sudo-menu.log`

## Version Management

### Check Version
```bash
cat VERSION
# or within script: press 'v'
```

### Update Version
```bash
./update-version.sh 2.1.0 "Description of changes"
```

## Troubleshooting

### View Script Log
```bash
tail -f /var/log/sudo-menu.log
```

### Check Safeguard Installation
```bash
ls -la /opt/quest/sbin/
```

### Verify as Root
```bash
sudo -i
./sudo-menu.sh
```

### Test Single Command
```bash
sudo /opt/quest/sbin/pmsrvinfo  # Example
```

## Emergency Commands

### Unjoin Plugin (if needed)
```bash
sudo /opt/quest/sbin/pmjoin_plugin -u
```

### Check Policy Syntax
```bash
sudo /opt/quest/sbin/pmcheck -f /etc/opt/quest/qpm4u/policy/sudoers -o sudo
```

### View Current License
```bash
sudo /opt/quest/sbin/pmlicense
```

## Support

- Script Log: `/var/log/sudo-menu.log`
- Documentation: `./README.md`
- Changelog: `./CHANGELOG.md`
- Product Docs: https://support.oneidentity.com

---
**Version:** 2.0.0 | **Date:** 2024-12-05
