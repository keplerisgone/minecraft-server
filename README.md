# Paper Minecraft Server Auto-Installer

🎮 **One-click Paper Minecraft server installation with version selection and auto-shutdown**

## Features

- ✅ **Version Selection**: Choose any Paper version (1.18.2 to latest)
- ✅ **Auto-shutdown**: Server stops after 10 minutes of inactivity  
- ✅ **Auto-start on boot**: Systemd integration
- ✅ **Cross-platform**: Ubuntu, Amazon Linux 2/2023, CentOS
- ✅ **Optimized JVM**: G1GC with performance tuning
- ✅ **Easy management**: Simple control scripts
- ✅ **Log-based player detection**: No console spam

## Quick Start

```bash
# Download and run installer
wget https://raw.githubusercontent.com/YOUR-USERNAME/paper-minecraft-installer/main/install.sh
chmod +x install.sh
sudo ./install.sh

# Or with specific version
sudo ./install.sh 1.21.6
```

## Repository Structure

```
paper-minecraft-installer/
├── install.sh                 # Main installation script (version selectable)
├── quick_install.sh           # Quick installer with popular versions
├── scripts/                   # Server management scripts
│   ├── start.sh              # Java server launcher
│   ├── start_screen.sh       # Screen session wrapper
│   ├── auto_shutdown.sh      # Auto-shutdown monitor
│   ├── autoshutdown_control.sh # Auto-shutdown control
│   └── server_manager.sh     # Main server manager
├── configs/                   # Configuration templates
│   └── server.properties     # Default server settings
├── docs/                     # Documentation
│   ├── installation.md      # Installation guide
│   ├── management.md         # Server management
│   └── troubleshooting.md    # Common issues
└── README.md                 # This file
```

## Supported Versions

- **Minecraft 1.21.x**: Java 21 (Latest)
- **Minecraft 1.20.x**: Java 17  
- **Minecraft 1.19.x**: Java 17
- **Minecraft 1.18.x**: Java 17
- **Minecraft 1.17.x**: Java 16 (Legacy)

## Supported Operating Systems

- ✅ **Ubuntu 20.04/22.04/24.04**
- ✅ **Amazon Linux 2**
- ✅ **Amazon Linux 2023** 
- ✅ **Ubuntu 20.04/22.04/24.04**
- ✅ **Amazon Linux 2**
- ✅ **Amazon Linux 2023** 
- ✅ **CentOS 7/8**
- ✅ **RHEL 7/8/9**

## Management Commands

After installation, use these commands in `/home/ec2-user/minecraft/` (or `/home/ubuntu/minecraft/`):

```bash
# Main server control
./server_manager.sh start      # Start server + auto-shutdown
./server_manager.sh stop       # Stop everything
./server_manager.sh restart    # Restart everything  
./server_manager.sh status     # Show detailed status
./server_manager.sh console    # Access server console (Ctrl+A, D to exit)

# Auto-shutdown control
./autoshutdown_control.sh start    # Start auto-shutdown monitor
./autoshutdown_control.sh stop     # Stop auto-shutdown monitor
./autoshutdown_control.sh status   # Check monitor status
./autoshutdown_control.sh log      # View auto-shutdown logs

# Systemd service control (requires sudo)
sudo systemctl start minecraft     # Start server service
sudo systemctl stop minecraft      # Stop server service  
sudo systemctl status minecraft    # Check service status
sudo systemctl enable minecraft    # Enable auto-start on boot
```

## Installation Options

### Option 1: Interactive Installation
```bash
wget https://raw.githubusercontent.com/YOUR-USERNAME/paper-minecraft-installer/main/install.sh
chmod +x install.sh
sudo ./install.sh
# Follow the interactive prompts to select version
```

### Option 2: Quick Installation with Popular Versions
```bash
wget https://raw.githubusercontent.com/YOUR-USERNAME/paper-minecraft-installer/main/quick_install.sh
chmod +x quick_install.sh
sudo ./quick_install.sh
# Choose from popular versions (1-8) or custom
```

### Option 3: Direct Version Installation
```bash
# Install specific version directly
sudo ./install.sh 1.21.6        # Latest
sudo ./install.sh 1.20.6        # Stable
sudo ./install.sh 1.19.4        # Legacy
```

### Option 4: Version + Build Installation
```bash
# Install specific version and build
sudo ./install.sh 1.21.6 48     # Version 1.21.6, Build 48
```

## Server Configuration

### Default Settings
- **Port**: 25565
- **Max Players**: 10
- **Memory**: 1.8GB-2GB (auto-adjusted by version)
- **Difficulty**: Easy
- **Game Mode**: Survival
- **Auto-shutdown**: 10 minutes idle
- **Backup**: None (manual only)

### Customization
Edit `/home/ec2-user/minecraft/server.properties` after installation:
```properties
max-players=20
difficulty=normal
pvp=false
white-list=true
```

## Auto-shutdown Feature

The server automatically shuts down after **10 minutes** of no players to save resources:

- ⏰ **Warning at 5 minutes**: "Server will shutdown in 5 minutes"
- ⚠️ **Warning at 1 minute**: "Server will shutdown in 1 minute!"  
- 🛑 **Shutdown**: Server stops and EC2 instance powers off

### Disable Auto-shutdown
```bash
./autoshutdown_control.sh stop
sudo systemctl disable minecraft-autoshutdown  # Permanently disable
```

## Firewall & Security

### AWS Security Group
Ensure your EC2 Security Group allows:
- **Inbound**: TCP 25565 from 0.0.0.0/0 (or your IP range)
- **Outbound**: All traffic (default)

### Local Firewall
The installer automatically configures:
- **Ubuntu**: UFW rule for port 25565
- **Amazon Linux**: firewall-cmd rule for port 25565

## File Structure After Installation

```
/home/ec2-user/minecraft/          # Main server directory
├── start.sh                       # Core server launcher
├── start_screen.sh                # Screen session wrapper
├── auto_shutdown.sh               # Auto-shutdown monitor  
├── autoshutdown_control.sh        # Auto-shutdown control
├── server_manager.sh              # Main management script
├── paper.jar                      # Paper server jar
├── server.properties              # Server configuration
├── eula.txt                       # EULA agreement
├── world/                         # Main world data
├── world_nether/                  # Nether dimension
├── world_the_end/                 # End dimension
├── plugins/                       # Plugin directory
├── logs/                          # Server logs
│   ├── latest.log                # Current server log
│   └── auto_shutdown.log         # Auto-shutdown log
├── backups/                       # Backup directory (manual)
└── installation_info.txt         # Installation details
```

## Performance Optimization

### JVM Arguments (Automatically Applied)
- **G1 Garbage Collector**: Optimized for server workloads
- **Memory Management**: Tuned for Paper servers
- **Modern Java Features**: Vector API support for 1.21+

### Memory Allocation by Version
- **1.21.x**: 2GB RAM (Java 21 optimizations)
- **1.20.x**: 1.8GB RAM  
- **1.19.x**: 1.8GB RAM
- **1.18.x**: 1.5GB RAM

## Troubleshooting

### Server Won't Start
```bash
# Check service status
sudo systemctl status minecraft

# View logs
tail -f /home/ec2-user/minecraft/logs/latest.log

# Check Java installation  
java -version

# Manual start for debugging
cd /home/ec2-user/minecraft
./start.sh
```

### Can't Connect to Server
1. **Check EC2 Public IP**: `curl ifconfig.me`
2. **Verify Security Group**: Port 25565 TCP open
3. **Check server status**: `./server_manager.sh status`
4. **Test port**: `sudo ss -tlpn | grep 25565`

### Auto-shutdown Not Working
```bash
# Check auto-shutdown status
./autoshutdown_control.sh status

# View auto-shutdown logs
./autoshutdown_control.sh log

# Restart auto-shutdown
./autoshutdown_control.sh restart
```

### Memory Issues
```bash
# Check available memory
free -h

# Adjust memory in start.sh
nano start.sh
# Change -Xms1800M -Xmx1800M to lower values
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on multiple OS distributions  
4. Submit a pull request

## License

MIT License - Feel free to use and modify

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/YOUR-USERNAME/paper-minecraft-installer/issues)
- 📖 **Wiki**: [Documentation](https://github.com/YOUR-USERNAME/paper-minecraft-installer/wiki)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/YOUR-USERNAME/paper-minecraft-installer/discussions)

---

### Example Installation Log

```bash
ubuntu@ip-172-31-0-123:~$ sudo ./install.sh
=== Paper Minecraft Server Installation ===
🎮 Available Minecraft versions for Paper:

Recent versions:
1) 1.21.6
2) 1.21.5
3) 1.21.4
4) 1.21.3
5) 1.20.6

Enter version number (1-5) or type version directly (e.g., 1.21.6):
Choice: 1
Selected version: 1.21.6

🔨 Fetching available builds for 1.21.6...
Available builds (showing last 5):
1) Build 44
2) Build 45  
3) Build 46
4) Build 47
5) Build 48
6) Latest build (48) [Recommended]

Choose build (1-6, or press Enter for latest): 
Selected build: 48

=== System Update ===
✅ System updated

=== Installing Java 21 ===  
✅ Java 21 installed

=== Downloading Paper 1.21.6 Build 48 ===
✅ Paper 1.21.6 Build 48 downloaded successfully

🎉 Installation completed successfully!
📋 Server: Paper 1.21.6 Build 48
☕ Java: 21
📁 Location: /home/ubuntu/minecraft

🚀 Start server: cd /home/ubuntu/minecraft && ./server_manager.sh start
```