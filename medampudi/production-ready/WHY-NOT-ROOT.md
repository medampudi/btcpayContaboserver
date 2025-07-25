# Why We Don't Run Everything as Root

## The Problem with the Original Approach

The original script required running everything as root (`sudo su -`), which has several issues:

### Security Risks
1. **Principle of Least Privilege Violated**: Running everything as root gives unnecessary privileges
2. **Accidental Damage**: One wrong command can destroy the system
3. **Security Vulnerabilities**: If any service is compromised, attacker gets root access
4. **Audit Trail Lost**: All actions appear as "root" in logs

### Practical Issues
1. **File Ownership Problems**: Files created as root need sudo to modify
2. **Docker Permission Issues**: Docker socket owned by root causes problems
3. **SSH Key Management**: SSH keys in root's home directory
4. **Backup Complications**: Backing up root-owned files requires sudo

## The Better Approach: Ubuntu User

### Why Ubuntu User?
- **Standard Practice**: Ubuntu 22.04 comes with 'ubuntu' user by default
- **Cloud Ready**: AWS, Azure, GCP all use 'ubuntu' as default user
- **Proper Permissions**: User has sudo access when needed
- **Docker Integration**: Can be added to docker group for container management

### What Changes?

#### Old Way (Root):
```bash
sudo su -
cd /opt/bitcoin
./setup.sh
# Everything runs as root
# Files owned by root
# Services managed by root
```

#### New Way (Ubuntu User):
```bash
# As ubuntu user
cd ~
./bitcoin-node-setup-ubuntu.sh
# Script uses sudo only when needed
# Files owned by ubuntu user
# Services managed by ubuntu user
```

### Security Improvements

1. **Selective Privileges**: Only system changes use sudo
2. **User Isolation**: Bitcoin data in user's home directory
3. **Service Management**: Systemd runs services as ubuntu user
4. **Docker Security**: User in docker group, not running as root
5. **SSH Security**: Disabled root login entirely

### File Locations

#### Old (Root-based):
```
/opt/bitcoin/           # Root owned
/root/setup-config.env  # Root's home
/var/lib/docker/        # Root only
```

#### New (User-based):
```
~/bitcoin-node/         # User owned
~/bitcoin-node/setup-config.env
~/.bitcoin/             # User config
Docker volumes managed by Docker daemon
```

## Migration Benefits

1. **Easier Management**: No sudo needed for routine tasks
2. **Better Security**: Following Linux best practices
3. **Cloud Compatible**: Works on any Ubuntu 22.04 system
4. **User Friendly**: Can manage via SSH without root
5. **Backup Friendly**: User can backup their own data

## Common Operations Comparison

### Checking Status
```bash
# Old way
sudo su -
cd /opt/bitcoin
./status.sh

# New way
~/bitcoin-node/scripts/status.sh
```

### Viewing Logs
```bash
# Old way
sudo docker logs bitcoind

# New way (after docker group membership)
docker logs bitcoind
```

### Configuration Changes
```bash
# Old way
sudo nano /opt/bitcoin/setup-config.env

# New way
nano ~/bitcoin-node/setup-config.env
```

## Summary

Running as a standard user with selective sudo access is:
- ✅ More secure
- ✅ Industry standard
- ✅ Easier to manage
- ✅ Cloud-friendly
- ✅ Following Linux best practices

The new script handles all the complexity of permissions while maintaining security!