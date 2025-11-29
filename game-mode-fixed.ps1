# game-mode.ps1
# Stops all running Docker containers and shuts down WSL2 with logging

#Requires -Version 5.1

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
  Write-Host "вљ пёЏ  This script is not running with Administrator privileges." -ForegroundColor Yellow
  Write-Host "   Some operations (like WSL2 shutdown) may require admin rights." -ForegroundColor Yellow
  Write-Host ""
  $response = Read-Host "Do you want to continue anyway? (Y/N)"
  if ($response -notmatch '^[Yy]') {
    Write-Host "Script cancelled by user." -ForegroundColor Red
    exit 0
  }
  Write-Host ""
}
else {
  Write-Host "вњ… Running with Administrator privileges." -ForegroundColor Green
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
    $bar = "в–€" * $filledLength + "в–‘" * ($barLength - $filledLength)

    Write-Host "`r$Activity [" -NoNewline -ForegroundColor Cyan
    Write-Host $bar -NoNewline -ForegroundColor Green
    Write-Host "] $percent%" -NoNewline -ForegroundColor Cyan

    Start-Sleep -Milliseconds 500
  }

  Write-Host "`r$Activity [" -NoNewline -ForegroundColor Cyan
  Write-Host ("в–€" * $barLength) -NoNewline -ForegroundColor Green
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
  $containers = docker ps -q 2>&1

  if ($LASTEXITCODE -ne 0) {
    Write-Log "вљ пёЏ Failed to query Docker containers. Is Docker running?"
    $containers = $null
  }
}
catch {
  Write-Log "вљ пёЏ Error querying Docker: $_"
  $containers = $null
}

if ($null -eq $containers -or $containers.Count -eq 0 -or $containers -eq "") {
  Write-Log "No running containers found."
}
else {
  $containerCount = ($containers | Measure-Object).Count
  Write-Log "Found $containerCount running containers. Stopping them all in parallel..."

  try {
    # Stop all containers at once with progress bar
    $stopJob = Start-Job -ScriptBlock {
      param($c)
      docker stop $c -t 10 2>&1
    } -ArgumentList (, $containers)

    Show-ProgressBar -Activity "Stopping Docker containers" -DurationSeconds 10 -CompletedMessage "Containers stopped"
    $jobResult = $stopJob | Wait-Job | Receive-Job
    $jobState = $stopJob.State
    Remove-Job -Job $stopJob

    if ($jobState -eq "Completed") {
      Write-Log "вњ… All $containerCount containers stopped successfully."
    }
    else {
      Write-Log "вљ пёЏ Some containers may have failed to stop. Job state: $jobState"
    }
  }
  catch {
    Write-Log "вљ пёЏ Error stopping containers: $_"
  }
}

Write-Log "All containers have been stopped or checked."

# Stop LM Studio
Write-Log "Checking for LM Studio processes..."
$lmStudioProcesses = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue

if ($null -eq $lmStudioProcesses) {
  Write-Log "No LM Studio processes found running."
}
else {
  $processCount = ($lmStudioProcesses | Measure-Object).Count
  Write-Log "Found $processCount LM Studio process(es). Stopping them..."

  try {
    $lmStudioProcesses | ForEach-Object {
      $_.CloseMainWindow() | Out-Null
    }
    Show-ProgressBar -Activity "Stopping LM Studio gracefully" -DurationSeconds 2 -CompletedMessage "Checking status"

    # Force stop if still running
    $remainingProcesses = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue
    if ($null -ne $remainingProcesses) {
      Stop-Process -Name "LM Studio" -Force -ErrorAction SilentlyContinue
      Write-Log "вњ… LM Studio processes stopped (forced)."
    }
    else {
      Write-Log "вњ… LM Studio processes stopped gracefully."
    }
  }
  catch {
    Write-Log "вљ пёЏ Error stopping LM Studio: $_"
  }
}

# Stop WSL2
Write-Log "Shutting down WSL2..."

if (-not $isAdmin) {
  Write-Log "вљ пёЏ WSL2 shutdown may fail without Administrator privileges."
}

try {
  # Check if WSL is installed
  $wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue

  if ($null -eq $wslInstalled) {
    Write-Log "вљ пёЏ WSL command not found. WSL may not be installed."
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
      Write-Log "вњ… WSL2 has been shut down successfully."
    }
    else {
      Write-Log "вљ пёЏ WSL2 shutdown completed with potential issues. Exit code: $($result.ExitCode)"
      if ($result.Output) {
        Write-Log "   Output: $($result.Output)"
      }
    }
  }
}
catch {
  Write-Log "вљ пёЏ Error shutting down WSL2: $_"
}

Write-Log "Script completed."

# Optional: Show log file path
Write-Host "Log file created at: $logFile" -ForegroundColor Green

# Optional: Show log file content for quick review
Write-Host "You can view the log file: $logFile" -ForegroundColor Cyan

