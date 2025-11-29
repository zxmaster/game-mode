# work-mode.ps1
# Starts WSL2 and Docker projects: infra-core, librechat, qdrant

#Requires -Version 5.1

# Define log file path
$logFile = "docker_start.log"

# Clear log file if it exists (optional, for fresh start)
if (Test-Path $logFile) {
  Remove-Item $logFile -Force
}

Write-Host "Starting work mode script (WSL2 & Docker projects)..." -ForegroundColor Cyan
Write-Host ""

# Function to check if running as Administrator
function Test-Administrator {
  $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for admin privileges
$isAdmin = Test-Administrator
if (-not $isAdmin) {
  Write-Host "[i] This script is not running with Administrator privileges." -ForegroundColor Cyan
  Write-Host "    Most operations should work, but some may require admin rights." -ForegroundColor Cyan
  Write-Host ""
}
else {
  Write-Host "[OK] Running with Administrator privileges." -ForegroundColor Green
  Write-Host ""
}

# Function to show loading bar
function Show-ProgressBar {
  param(
    [string]$Activity,
    [int]$DurationSeconds,
    [string]$CompletedMessage = "Done"
  )

  $barLength = 40
  $steps = $DurationSeconds * 2  # Update twice per second

  for ($i = 0; $i -le $steps; $i++) {
    $percent = [math]::Round(($i / $steps) * 100)
    $filledLength = [math]::Round(($barLength * $i) / $steps)
    $bar = "#" * $filledLength + "-" * ($barLength - $filledLength)

    Write-Host "`r$Activity [" -NoNewline -ForegroundColor Cyan
    Write-Host $bar -NoNewline -ForegroundColor Green
    Write-Host "] $percent%" -NoNewline -ForegroundColor Cyan

    Start-Sleep -Milliseconds 500
  }

  Write-Host "`r$Activity [" -NoNewline -ForegroundColor Cyan
  Write-Host ("#" * $barLength) -NoNewline -ForegroundColor Green
  Write-Host "] 100% - $CompletedMessage" -ForegroundColor Green
}

# Function to write to log
function Write-Log {
  param(
    [string]$Message
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logMessage = "[$timestamp] $Message"
  Write-Host $logMessage -ForegroundColor Yellow
  Add-Content -Path $logFile -Value $logMessage -Force
}

# Check if docker command exists
Write-Log "Checking if 'docker' command is available..."
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Log "ERROR: 'docker' command not found. Please install Docker and ensure it's in PATH."
  exit 1
}

Write-Log "Found docker command. Proceeding..."

# Start WSL2 if not running
Write-Log "Checking WSL2 status..."

# Check if WSL is installed
$wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue

if ($null -eq $wslInstalled) {
  Write-Log "[!] WSL command not found. WSL may not be installed."
  Write-Log "    Please install WSL2 using: wsl --install"
  $response = Read-Host "Continue without WSL2? (Y/N)"
  if ($response -notmatch '^[Yy]') {
    Write-Log "Script cancelled by user."
    exit 0
  }
}
else {
  try {
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Log "WSL2 is not running. Starting WSL2..."
      # Start WSL by running a simple command
      $wslJob = Start-Job -ScriptBlock {
        $output = wsl --exec echo "WSL2 starting..." 2>&1
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
      }

      Show-ProgressBar -Activity "Starting WSL2" -DurationSeconds 5 -CompletedMessage "WSL2 ready"
      $result = $wslJob | Wait-Job | Receive-Job
      Remove-Job -Job $wslJob

      if ($result.ExitCode -eq 0 -or $null -eq $result.ExitCode) {
        Write-Log "[OK] WSL2 has been started."
      }
      else {
        Write-Log "[!] WSL2 may not have started correctly. Exit code: $($result.ExitCode)"
      }
    }
    else {
      Write-Log "[OK] WSL2 is already running."
    }
  }
  catch {
    Write-Log "[!] Could not determine WSL2 status, attempting to start..."
    try {
      $wslJob = Start-Job -ScriptBlock {
        $output = wsl --exec echo "WSL2 starting..." 2>&1
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
      }

      Show-ProgressBar -Activity "Starting WSL2" -DurationSeconds 5 -CompletedMessage "WSL2 ready"
      $result = $wslJob | Wait-Job | Receive-Job
      Remove-Job -Job $wslJob
      Write-Log "WSL2 start attempt completed."
    }
    catch {
      Write-Log "[!] Error starting WSL2: $_"
    }
  }
}

# Check if Docker Desktop is running
Write-Log "Checking if Docker Desktop is running..."
$dockerDesktopProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue

if ($null -eq $dockerDesktopProcess) {
  Write-Log "Docker Desktop is not running. Starting Docker Desktop..."

  # Try multiple common Docker Desktop installation paths
  $dockerDesktopPaths = @(
    "C:\Program Files\Docker\Docker\Docker Desktop.exe",
    "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
    "$env:LOCALAPPDATA\Programs\Docker\Docker Desktop.exe"
  )

  $dockerDesktopPath = $null
  foreach ($path in $dockerDesktopPaths) {
    if (Test-Path $path) {
      $dockerDesktopPath = $path
      break
    }
  }

  if ($null -ne $dockerDesktopPath) {
    try {
      Start-Process $dockerDesktopPath -ErrorAction Stop
      Write-Log "Docker Desktop starting from: $dockerDesktopPath"
      Write-Log "Waiting for Docker Desktop to start (30 seconds)..."
      Show-ProgressBar -Activity "Starting Docker Desktop" -DurationSeconds 30 -CompletedMessage "Verifying readiness"

      # Verify Docker is responding
      $retries = 6
      $dockerReady = $false
      for ($i = 1; $i -le $retries; $i++) {
        try {
          $testResult = docker ps 2>&1
          if ($LASTEXITCODE -eq 0) {
            $dockerReady = $true
            Write-Log "[OK] Docker Desktop is ready."
            break
          }
        }
        catch {
          # Silently continue
        }

        if ($i -lt $retries) {
          Write-Log "Waiting for Docker to be ready... (attempt $i/$retries)"
          Start-Sleep -Seconds 10
        }
      }

      if (-not $dockerReady) {
        Write-Log "[!] Docker Desktop may not be fully ready yet."
        $response = Read-Host "Continue anyway? (Y/N)"
        if ($response -notmatch '^[Yy]') {
          Write-Log "Script cancelled by user."
          exit 0
        }
      }
    }
    catch {
      Write-Log "[!] Error starting Docker Desktop: $_"
      $response = Read-Host "Continue without Docker Desktop? (Y/N)"
      if ($response -notmatch '^[Yy]') {
        Write-Log "Script cancelled by user."
        exit 0
      }
    }
  }
  else {
    Write-Log "[!] Docker Desktop executable not found in any common location."
    Write-Log "    Checked paths:"
    foreach ($path in $dockerDesktopPaths) {
      Write-Log "    - $path"
    }
    $response = Read-Host "Continue without Docker Desktop? (Y/N)"
    if ($response -notmatch '^[Yy]') {
      Write-Log "Script cancelled by user."
      exit 0
    }
  }
}
else {
  Write-Log "[OK] Docker Desktop is already running."
}

# Start LM Studio
Write-Log "Checking if LM Studio is running..."
$lmStudioProcess = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue

if ($null -eq $lmStudioProcess) {
  Write-Log "LM Studio is not running. Starting LM Studio..."

  # Common LM Studio installation paths
  $lmStudioPaths = @(
    "$env:LOCALAPPDATA\Programs\LM Studio\LM Studio.exe",
    "$env:LOCALAPPDATA\LMStudio\LM Studio.exe",
    "C:\Program Files\LM Studio\LM Studio.exe",
    "C:\Program Files (x86)\LM Studio\LM Studio.exe"
  )

  $lmStudioPath = $null
  foreach ($path in $lmStudioPaths) {
    if (Test-Path $path) {
      $lmStudioPath = $path
      break
    }
  }

  if ($null -ne $lmStudioPath) {
    try {
      Start-Process $lmStudioPath
      Write-Log "[OK] LM Studio started from: $lmStudioPath"
      Show-ProgressBar -Activity "Initializing LM Studio" -DurationSeconds 3 -CompletedMessage "LM Studio ready"
    }
    catch {
      Write-Log "[!] Error starting LM Studio: $_"
    }
  }
  else {
    Write-Log "[!] LM Studio executable not found in common installation locations."
    Write-Log "    Checked locations:"
    foreach ($path in $lmStudioPaths) {
      Write-Log "    - $path"
    }
  }
}
else {
  Write-Log "[OK] LM Studio is already running."
}

# Define projects to start (by Docker Compose project name)
$projects = @("infra-core", "librechat", "qdrant")

# Start each project
foreach ($project in $projects) {
  Write-Log "Starting Docker Compose project: $project..."

  try {
    # Get containers for this project
    $projectContainers = docker ps -a --filter "label=com.docker.compose.project=$project" -q 2>&1

    if ($LASTEXITCODE -ne 0) {
      Write-Log "[!] Failed to query containers for project '$project'."
      continue
    }

    if ($null -eq $projectContainers -or $projectContainers -eq "") {
      Write-Log "[i] No containers found for project '$project'. Skipping..."
      continue
    }

    # Start all containers for the project
    $startResult = docker start $projectContainers 2>&1

    if ($LASTEXITCODE -eq 0) {
      $containerCount = ($projectContainers | Measure-Object).Count
      Write-Log "[OK] Project '$project' started successfully ($containerCount container(s))."
    }
    else {
      Write-Log "[!] Some containers in project '$project' may have failed to start."
      if ($startResult) {
        Write-Log "    Error: $startResult"
      }
    }
  }
  catch {
    Write-Log "[!] Error starting project '$project': $_"
  }
}

Write-Log "All projects have been processed."
Write-Log "Script completed."

# Optional: Show log file path
Write-Host "Log file created at: $logFile" -ForegroundColor Green

# Optional: Show log file content for quick review
Write-Host "You can view the log file: $logFile" -ForegroundColor Cyan
