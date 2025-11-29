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
5. 🔌 Shuts down WSL2 completely (optional)
6. 📝 Logs all operations to `docker_stop.log`

### Usage

**Interactive Mode:**

```powershell
.\game-mode.ps1
```

**Skip All Prompts:**

```powershell
.\game-mode.ps1 -Force
```

**Skip WSL2 Shutdown:**

```powershell
.\game-mode.ps1 -SkipWSL
```

**Combined (No Prompts, Skip WSL2):**

```powershell
.\game-mode.ps1 -Force -SkipWSL
```

### Parameters

- `-Force`: Skips all confirmation prompts (continues even without admin privileges)
- `-SkipWSL`: Completely skips WSL2 shutdown step

### Requirements

- Docker Desktop installed
- WSL2 enabled (optional if using `-SkipWSL`)
- PowerShell 5.1 or later
- Administrator privileges recommended for WSL2 shutdown (can be skipped with `-Force` or `-SkipWSL`)

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

To modify which projects are started, edit the `config.env` file:

```env
# Docker Compose Project Configuration
# List the Docker Compose project names to manage (one per line)
# These projects will be started by work-mode.ps1

infra-core
librechat
qdrant
```

Add or remove project names as needed. Lines starting with `#` are treated as comments.

If `config.env` is not found, the script will use default projects: `infra-core`, `librechat`, `qdrant`.

### Log File

- Location: `docker_start.log` (in the same directory)
- Contains timestamped entries for all operations
- Automatically cleared on each run

## 🔍 check-mode.ps1

### Purpose

Provides a comprehensive status check of all system components to determine if you're in "Game Mode" or "Work Mode", with interactive options to switch modes.

### What It Does

1. ✅ Checks WSL2 status and running distributions
2. 🐋 Checks Docker Desktop process status
3. 🔧 Checks Docker Engine availability and responsiveness
4. 📦 Lists all running Docker containers
5. 🗂️ Checks status of specific Docker Compose projects (infra-core, librechat, qdrant)
6. 🤖 Checks LM Studio process status
7. 📊 Calculates overall mode percentage and displays assessment
8. 🎯 Provides interactive options to start Work Mode, Game Mode, or Exit

### Usage

```powershell
.\check-mode.ps1
```

After viewing the status, you'll be prompted to choose:

- **[1] Start Work Mode** - Runs `work-mode.ps1` to start all services
- **[2] Start Game Mode** - Runs `game-mode.ps1` to stop all services
- **[3] Exit** - Closes the script

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

What would you like to do?

  [1] Start Work Mode  (./work-mode.ps1)
  [2] Start Game Mode  (./game-mode.ps1)
  [3] Exit

Enter your choice (1-3):
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

The scripts manage Docker Compose projects listed in `config.env`.

**To configure your projects:**

1. Create or edit `config.env` in the script directory
2. List one project name per line (matching your Docker Compose project labels)
3. Lines starting with `#` are treated as comments

**Example `config.env`:**

```env
# My Docker Projects
infra-core
librechat
qdrant
# my-custom-project
```

**How Docker Compose projects are identified:**

The scripts use Docker Compose project labels to find containers. Ensure your projects are started with a project name:

```bash
# Using docker-compose
docker-compose -p infra-core up -d

# Using docker compose (v2)
docker compose -p infra-core up -d
```

Or set the project name in your `docker-compose.yml`:

```yaml
# docker-compose.yml
name: infra-core
services:
  myservice:
    image: myimage
```

### LM Studio Path

The `work-mode.ps1` script automatically searches for LM Studio in common installation locations:

- `%LOCALAPPDATA%\Programs\LM Studio\LM Studio.exe`
- `%LOCALAPPDATA%\LMStudio\LM Studio.exe`
- `C:\Program Files\LM Studio\LM Studio.exe`
- `C:\Program Files (x86)\LM Studio\LM Studio.exe`

If LM Studio is installed in a different location, you can add the path to the `$lmStudioPaths` array in the script.

## 📊 Example Output

### game-mode.ps1 (with -Force -SkipWSL)

```
Starting game mode script (stopping Docker & WSL2)...

[!] This script is not running with Administrator privileges.
    Some operations (like WSL2 shutdown) may require admin rights.

[i] Force mode enabled, continuing without prompts.

[2025-11-30 14:30:00] Checking if 'docker' command is available...
[2025-11-30 14:30:00] Found docker command. Proceeding...
[2025-11-30 14:30:01] Getting list of running containers...
[2025-11-30 14:30:01] Found 5 running containers. Stopping them all in parallel...
Stopping Docker containers [########################################] 100% - Containers stopped
[2025-11-30 14:30:12] ✅ All 5 containers stopped successfully.
[2025-11-30 14:30:12] All containers have been stopped or checked.
[2025-11-30 14:30:12] Checking for LM Studio processes...
[2025-11-30 14:30:12] Found 1 LM Studio process(es). Stopping them...
Stopping LM Studio gracefully [########################################] 100% - Checking status
[2025-11-30 14:30:14] ✅ LM Studio processes stopped gracefully.
[2025-11-30 14:30:14] Shutting down WSL2...
[2025-11-30 14:30:14] [i] WSL2 shutdown skipped (SkipWSL parameter).
[2025-11-30 14:30:14] Script completed.
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

### Running without Administrator privileges

**For WSL2 shutdown issues:**

- Use `.\game-mode.ps1 -SkipWSL` to skip WSL2 shutdown entirely
- Use `.\game-mode.ps1 -Force` to skip prompts (WSL2 shutdown may still fail)
- WSL2 will remain running but Docker containers and LM Studio will be stopped

**Alternative:** Right-click PowerShell and select "Run as Administrator" before running the script.

### "LM Studio executable not found"

- Verify LM Studio is installed on your system
- Check if it's in one of the default locations listed in the Configuration section
- If installed elsewhere, add the path to `$lmStudioPaths` array in `work-mode.ps1`
- The script will continue without LM Studio if not found

## 🎯 Use Cases

### Gaming Session

1. Run `.\check-mode.ps1` to see current status
2. Select option [2] to run Game Mode, or run `.\game-mode.ps1 -Force -SkipWSL` directly
3. Frees up RAM and CPU resources used by Docker and WSL2
4. Improves gaming performance

### Development Work

1. Run `.\check-mode.ps1` to see current status
2. Select option [1] to run Work Mode, or run `.\work-mode.ps1` directly
3. Automatically starts all necessary development containers
4. Ready to code in seconds

### Quick Switching

- Use `check-mode.ps1` as your main launcher for quick status check and mode switching
- Keep scripts in an easily accessible location
- Create desktop shortcuts for one-click execution:
  - **Game Mode**: `powershell.exe -File "C:\path\to\game-mode.ps1" -Force -SkipWSL`
  - **Work Mode**: `powershell.exe -File "C:\path\to\work-mode.ps1"`
  - **Check Mode**: `powershell.exe -File "C:\path\to\check-mode.ps1"`
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
