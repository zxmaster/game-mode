# Game Mode & Work Mode Scripts

PowerShell scripts to quickly switch between gaming and work modes by managing Docker containers and WSL2 on Windows.

## 📋 Overview

This repository contains three PowerShell scripts designed to optimize system resources:

- **`game-mode.ps1`**: Stops all Docker containers, closes LM Studio, and shuts down WSL2 to free up system resources for gaming
- **`work-mode.ps1`**: Starts WSL2, launches LM Studio, and starts specific Docker Compose projects for development work
- **`check-mode.ps1`**: Displays current status of all services and determines which mode is active

## 🎮 game-mode.ps1

### Purpose

Frees up system resources by stopping all running Docker containers and shutting down WSL2. Ideal for when you need maximum performance for gaming or other resource-intensive applications.

### What It Does

1. ✅ Checks if Docker is available
2. 📦 Lists all running Docker containers
3. ⏹️ Stops all running containers (with 10-second graceful timeout)
4. 🤖 Stops LM Studio processes (gracefully, then forced if needed)
5. 🔌 Shuts down WSL2 completely
6. 📝 Logs all operations to `docker_stop.log`

### Usage

```powershell
.\game-mode.ps1
```

### Requirements

- Docker Desktop installed
- WSL2 enabled
- PowerShell 5.1 or later
- Administrator privileges (recommended for WSL shutdown)

### Log File

- Location: `docker_stop.log` (in the same directory)
- Contains timestamped entries for all operations
- Automatically cleared on each run

## 💼 work-mode.ps1

### Purpose

Starts your development environment by ensuring WSL2 is running, Docker Desktop is active, and specific Docker Compose projects are started.

### What It Does

1. ✅ Checks if Docker is available
2. 🔄 Starts WSL2 if not already running
3. 🐋 Checks if Docker Desktop is running
4. 🚀 Starts Docker Desktop if needed (waits up to 90 seconds for readiness)
5. 🤖 Starts LM Studio if not already running
6. 📦 Starts the following Docker Compose projects:
   - `infra-core`
   - `librechat`
   - `qdrant`
7. 📝 Logs all operations to `docker_start.log`

### Usage

```powershell
.\work-mode.ps1
```

### Requirements

- Docker Desktop installed at `C:\Program Files\Docker\Docker\Docker Desktop.exe`
- WSL2 enabled
- PowerShell 5.1 or later
- Docker Compose projects labeled with `com.docker.compose.project` label
- LM Studio installed (optional, script will skip if not found)

### Customization

To modify which projects are started, edit the `$projects` array in the script:

```powershell
$projects = @("infra-core", "librechat", "qdrant")
```

Add or remove project names as needed.

### Log File

- Location: `docker_start.log` (in the same directory)
- Contains timestamped entries for all operations
- Automatically cleared on each run

## 🔍 check-mode.ps1

### Purpose

Provides a comprehensive status check of all system components to determine if you're in "Game Mode" or "Work Mode".

### What It Does

1. ✅ Checks WSL2 status and running distributions
2. 🐋 Checks Docker Desktop process status
3. 🔧 Checks Docker Engine availability and responsiveness
4. 📦 Lists all running Docker containers
5. 🗂️ Checks status of specific Docker Compose projects (infra-core, librechat, qdrant)
6. 🤖 Checks LM Studio process status
7. 📊 Calculates overall mode percentage and displays assessment
8. 💡 Provides suggestions for incomplete setups

### Usage

```powershell
.\check-mode.ps1
```

### Example Output

```
========================================
   System Mode Status Check
========================================

Checking WSL2...
  ✅ WSL2                [RUNNING   ] 1 distribution(s) running
Checking Docker Desktop...
  ✅ Docker Desktop      [RUNNING   ] Process active
Checking Docker Engine...
  ✅ Docker Engine       [RUNNING   ] Responding to commands
Checking Docker Containers...
  ✅ Docker Containers   [RUNNING   ] 5/8 containers active
Checking Docker Projects...
  ✅   └─ infra-core     [RUNNING   ] 2 container(s)
  ✅   └─ librechat      [RUNNING   ] 2 container(s)
  ✅   └─ qdrant         [RUNNING   ] 1 container(s)
Checking LM Studio...
  ✅ LM Studio           [RUNNING   ] 1 process(es) active

========================================
  Current Mode Assessment:

  🟢 WORK MODE ACTIVE
     Most development services are running (100% active)

========================================
```

### Status Indicators

- 🟢 **WORK MODE ACTIVE** (75-100%): Most or all development services running
- 🟡 **PARTIAL MODE** (25-74%): Some development services running
- 🔴 **GAME MODE ACTIVE** (0-24%): Most or all development services stopped

### Requirements

- PowerShell 5.1 or later
- No administrator privileges required

## 🛠️ Installation

1. Clone or download this repository:

   ```powershell
   git clone https://github.com/yourusername/game-mode.git
   cd game-mode
   ```

2. Ensure PowerShell execution policy allows script execution:

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. Make sure Docker Desktop and WSL2 are properly installed on your system.

## 🔧 Configuration

### Docker Desktop Path

The scripts assume Docker Desktop is installed at:

```
C:\Program Files\Docker\Docker\Docker Desktop.exe
```

If your installation is in a different location, edit `work-mode.ps1` and update the `$dockerDesktopPath` variable.

### Docker Projects

The `work-mode.ps1` script starts containers based on Docker Compose project labels. Ensure your Docker Compose files include the project name:

```yaml
# docker-compose.yml example
version: '3.8'
services:
  myservice:
    image: myimage
    # Project name is set via: docker-compose -p infra-core up
```

Or start your projects with:

```bash
docker-compose -p infra-core up -d
```

### LM Studio Path

The `work-mode.ps1` script automatically searches for LM Studio in common installation locations:

- `%LOCALAPPDATA%\Programs\LM Studio\LM Studio.exe`
- `%LOCALAPPDATA%\LMStudio\LM Studio.exe`
- `C:\Program Files\LM Studio\LM Studio.exe`
- `C:\Program Files (x86)\LM Studio\LM Studio.exe`

If LM Studio is installed in a different location, you can add the path to the `$lmStudioPaths` array in the script.

## 📊 Example Output

### game-mode.ps1

```
Starting game mode script (stopping Docker & WSL2)...
[2025-11-30 14:30:00] Checking if 'docker' command is available...
[2025-11-30 14:30:00] Found docker command. Proceeding...
[2025-11-30 14:30:01] Getting list of running containers...
[2025-11-30 14:30:01] Found 5 running containers. Stopping them all in parallel...
[2025-11-30 14:30:12] ✅ All 5 containers stopped successfully.
[2025-11-30 14:30:12] All containers have been stopped or checked.
[2025-11-30 14:30:12] Checking for LM Studio processes...
[2025-11-30 14:30:12] Found 1 LM Studio process(es). Stopping them...
[2025-11-30 14:30:14] ✅ LM Studio processes stopped gracefully.
[2025-11-30 14:30:14] Shutting down WSL2...
[2025-11-30 14:30:17] ✅ WSL2 has been shut down successfully.
[2025-11-30 14:30:17] Script completed.
Log file created at: docker_stop.log
```

### work-mode.ps1

```
Starting work mode script (WSL2 & Docker projects)...
[2025-11-30 09:00:00] Checking if 'docker' command is available...
[2025-11-30 09:00:00] Found docker command. Proceeding...
[2025-11-30 09:00:01] Checking WSL2 status...
[2025-11-30 09:00:02] ✅ WSL2 is already running.
[2025-11-30 09:00:02] Checking if Docker Desktop is running...
[2025-11-30 09:00:02] ✅ Docker Desktop is already running.
[2025-11-30 09:00:02] Checking if LM Studio is running...
[2025-11-30 09:00:02] LM Studio is not running. Starting LM Studio...
[2025-11-30 09:00:02] ✅ LM Studio started from: C:\Users\Admin\AppData\Local\Programs\LM Studio\LM Studio.exe
[2025-11-30 09:00:05] Starting Docker Compose project: infra-core...
[2025-11-30 09:00:07] ✅ Project 'infra-core' started successfully.
[2025-11-30 09:00:07] Starting Docker Compose project: librechat...
[2025-11-30 09:00:09] ✅ Project 'librechat' started successfully.
[2025-11-30 09:00:09] Starting Docker Compose project: qdrant...
[2025-11-30 09:00:11] ✅ Project 'qdrant' started successfully.
[2025-11-30 09:00:11] All projects have been processed.
[2025-11-30 09:00:11] Script completed.
Log file created at: docker_start.log
```

## ⚠️ Troubleshooting

### "docker: command not found"

- Ensure Docker Desktop is installed
- Verify Docker is in your system PATH
- Restart PowerShell after installing Docker

### "Docker Desktop executable not found"

- Check if Docker Desktop is installed at the expected path
- Update the `$dockerDesktopPath` variable in `work-mode.ps1`

### WSL2 doesn't start

- Ensure WSL2 is properly installed: `wsl --install`
- Check Windows version (WSL2 requires Windows 10 version 1903+ or Windows 11)
- Run `wsl --update` to update WSL

### Containers don't start in work-mode

- Verify containers exist: `docker ps -a`
- Check if containers have the correct project label: `docker inspect <container_id>`
- Manually start containers to check for errors: `docker start <container_id>`

### Script execution is disabled

Run this command in PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### "LM Studio executable not found"

- Verify LM Studio is installed on your system
- Check if it's in one of the default locations listed in the Configuration section
- If installed elsewhere, add the path to `$lmStudioPaths` array in `work-mode.ps1`
- The script will continue without LM Studio if not found

## 🎯 Use Cases

### Gaming Session

1. Run `.\game-mode.ps1` before starting your game
2. Frees up RAM and CPU resources used by Docker and WSL2
3. Improves gaming performance

### Development Work

1. Run `.\work-mode.ps1` when starting your workday
2. Automatically starts all necessary development containers
3. Ready to code in seconds

### Quick Switching

- Keep both scripts in an easily accessible location
- Create desktop shortcuts for one-click execution
- Use Task Scheduler to automate execution at specific times

## 📝 Log Files

Both scripts generate detailed log files:

- **`docker_stop.log`**: Created by `game-mode.ps1`
- **`docker_start.log`**: Created by `work-mode.ps1`

Logs include:

- Timestamps for all operations
- Success/failure status
- Error messages and exit codes
- Container counts and project names

## 🔐 Permissions

### Running as Administrator

Some operations (especially WSL shutdown) may require administrator privileges. To run as admin:

1. Right-click the script
2. Select "Run with PowerShell as Administrator"

Or create a shortcut with admin privileges:

1. Right-click → Create shortcut
2. Right-click shortcut → Properties → Advanced
3. Check "Run as administrator"

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

## 📄 License

This project is licensed under the MIT License. See LICENSE file for details.

## 🙏 Acknowledgments

- Built for Windows 10/11 with Docker Desktop and WSL2
- Designed to optimize resource usage for gaming and development
- Inspired by the need to quickly switch between work and play

## 📞 Support

If you encounter issues:

1. Check the log files for detailed error messages
2. Review the Troubleshooting section
3. Open an issue on GitHub with log file contents

---

**Made with ❤️ for developers who game**
