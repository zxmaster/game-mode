# game-mode.ps1
# Stops all running Docker containers and shuts down WSL2 with logging

#Requires -Version 5.1

param(
  [switch]$SkipWSL,
  [switch]$Force
)

# Define log file path
$logFile = "docker_stop.log"

# Clear log file if it exists (optional, for fresh start)
if (Test-Path $logFile) {
  Remove-Item $logFile -Force
}
Write-Host "Starting game mode script (stopping Docker & WSL2)..." -ForegroundColor Cyan
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
  Write-Host "[!] This script is not running with Administrator privileges." -ForegroundColor Yellow
  Write-Host "    Some operations (like WSL2 shutdown) may require admin rights." -ForegroundColor Yellow
  Write-Host ""
  if (-not $Force) {
    $response = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($response -notmatch '^[Yy]') {
      Write-Host "Script cancelled by user." -ForegroundColor Red
      exit 0
    }
  }
  else {
    Write-Host "[i] Force mode enabled, continuing without prompts." -ForegroundColor Cyan
  }
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

# Get running containers
Write-Log "Getting list of running containers..."
try {
  $raw = docker ps -q 2>&1
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
    Write-Log "No running containers found or Docker not responding."
    $containerList = @()
  }
  else {
    $containerList = $raw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  }
}
catch {
  Write-Log "[!] Error querying Docker: $_"
  $containerList = @()
}

if ($containerList.Count -eq 0) {
  Write-Log "No running containers found."
}
else {
  $containerCount = $containerList.Count
  Write-Log "Found $containerCount running containers. Stopping them..."

  try {
    # Stop all containers at once (docker stop accepts multiple IDs)
    $stopOutput = docker stop $containerList -t 10 2>&1
    $stopOutput | ForEach-Object { Write-Log "docker: $_" }
    Show-ProgressBar -Activity "Stopping Docker containers" -DurationSeconds 10 -CompletedMessage "Containers stopped"
    Write-Log "[OK] Stop command issued for $containerCount container(s)."
  }
  catch {
    Write-Log "[!] Error stopping containers: $_"
  }
}

Write-Log "All containers have been stopped or checked."

# Stop LM Studio
Write-Log "Checking for LM Studio processes..."
$lmStudioProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object {
  ($_.ProcessName -match 'LM.?Studio') -or ($_.MainWindowTitle -and $_.MainWindowTitle -match 'LM Studio')
}

if (-not $lmStudioProcesses) {
  Write-Log "No LM Studio processes found running."
}
else {
  $processCount = $lmStudioProcesses.Count
  Write-Log "Found $processCount LM Studio process(es). Stopping them..."

  try {
    $lmStudioProcesses | ForEach-Object {
      try { $_.CloseMainWindow() | Out-Null } catch {}
    }
    Show-ProgressBar -Activity "Stopping LM Studio gracefully" -DurationSeconds 2 -CompletedMessage "Checking status"

    # Force stop if still running
    $remainingProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object {
      ($_.ProcessName -match 'LM.?Studio') -or ($_.MainWindowTitle -and $_.MainWindowTitle -match 'LM Studio')
    }
    if ($remainingProcesses) {
      $ids = $remainingProcesses | Select-Object -ExpandProperty Id
      Stop-Process -Id $ids -Force -ErrorAction SilentlyContinue
      Write-Log "[OK] LM Studio processes stopped (forced)."
    }
    else {
      Write-Log "[OK] LM Studio processes stopped gracefully."
    }
  }
  catch {
    Write-Log "[!] Error stopping LM Studio: $_"
  }
}


# Stop Docker Desktop
Write-Log "Checking for Docker Desktop process..."
$dockerDesktopProcess = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'Docker' -or $_.ProcessName -match 'DockerDesktop' }
if (-not $dockerDesktopProcess) {
  Write-Log "No Docker Desktop process found running."
}
else {
  Write-Log "Docker Desktop is running. Attempting graceful shutdown..."
  $dockerDesktopPaths = @(
    "C:\Program Files\Docker\Docker\Docker Desktop.exe",
    "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
    "$env:LOCALAPPDATA\Programs\Docker\Docker Desktop.exe"
  )
  $dockerDesktopExe = $null
  foreach ($path in $dockerDesktopPaths) {
    if (Test-Path $path) {
      $dockerDesktopExe = $path
      break
    }
  }
  if ($null -ne $dockerDesktopExe) {
    try {
      Write-Log "Running: '$dockerDesktopExe --shutdown'"
      Start-Process -FilePath $dockerDesktopExe -ArgumentList '--shutdown' -ErrorAction Stop
      Show-ProgressBar -Activity "Gracefully shutting down Docker Desktop" -DurationSeconds 5 -CompletedMessage "Shutdown command sent"
      Write-Log "[OK] Docker Desktop shutdown command sent."
    }
    catch {
      Write-Log "[!] Error sending shutdown command to Docker Desktop: $_"
    }
  }
  else {
    Write-Log "[!] Docker Desktop executable not found in common locations."
  }
}

# Stop WSL2
Write-Log "Shutting down WSL2..."
if ($SkipWSL) {
  Write-Log "[i] WSL2 shutdown skipped (SkipWSL parameter)."
}
elseif (-not $isAdmin) {
  Write-Log "[!] WSL2 shutdown requires Administrator privileges."
  if ($Force) {
    Write-Log "[i] WSL2 shutdown skipped (Force mode without admin)."
  }
  else {
    $response = Read-Host "Skip WSL2 shutdown? (Y/N)"
    if ($response -match '^[Yy]') {
      Write-Log "[i] WSL2 shutdown skipped by user."
    }
    else {
      try {
        # Check if WSL is installed
        $wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
        if ($null -eq $wslInstalled) {
          Write-Log "[!] WSL command not found. WSL may not be installed."
        }
        else {
          $wslJob = Start-Job -ScriptBlock {
            $output = wsl --shutdown 2>&1
            return @{ Output = $output; ExitCode = $LASTEXITCODE }
          }
          Show-ProgressBar -Activity "Shutting down WSL2" -DurationSeconds 3 -CompletedMessage "WSL2 shutdown complete"
          $result = $wslJob | Wait-Job | Receive-Job
          $jobState = $wslJob.State
          Remove-Job -Job $wslJob
          if ($jobState -eq "Completed" -and ($result.ExitCode -eq 0 -or $null -eq $result.ExitCode)) {
            Write-Log "[OK] WSL2 has been shut down successfully."
          }
          else {
            Write-Log "[!] WSL2 shutdown completed with potential issues. Exit code: $($result.ExitCode)"
            if ($result.Output) {
              Write-Log "    Output: $($result.Output)"
            }
          }
        }
      }
      catch {
        Write-Log "[!] Error shutting down WSL2: $_"
      }
    }
  }
}
else {
  try {
    # Check if WSL is installed
    $wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
    if ($null -eq $wslInstalled) {
      Write-Log "[!] WSL command not found. WSL may not be installed."
    }
    else {
      $wslJob = Start-Job -ScriptBlock {
        $output = wsl --shutdown 2>&1
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
      }
      Show-ProgressBar -Activity "Shutting down WSL2" -DurationSeconds 3 -CompletedMessage "WSL2 shutdown complete"
      $result = $wslJob | Wait-Job | Receive-Job
      $jobState = $wslJob.State
      Remove-Job -Job $wslJob
      if ($jobState -eq "Completed" -and ($result.ExitCode -eq 0 -or $null -eq $result.ExitCode)) {
        Write-Log "[OK] WSL2 has been shut down successfully."
      }
      else {
        Write-Log "[!] WSL2 shutdown completed with potential issues. Exit code: $($result.ExitCode)"
        if ($result.Output) {
          Write-Log "    Output: $($result.Output)"
        }
      }
    }
  }
  catch {
    Write-Log "[!] Error shutting down WSL2: $_"
  }
}
Write-Log "Script completed."

# Optional: Show log file path
Write-Host "Log file created at: $logFile" -ForegroundColor Green

# Optional: Show log file content for quick review
Write-Host "You can view the log file: $logFile" -ForegroundColor Cyan
