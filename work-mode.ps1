# work-mode.ps1
# Starts WSL2 and Docker projects: infra-core, librechat, qdrant

#Requires -Version 5.1

param(
  [switch]$NoWait,
  [switch]$SkipLMStudio,
  [switch]$Quiet
)

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
    $null = wsl --status 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Log "WSL2 is not running. Starting WSL2..."
      # Start WSL by running a simple command
      $wslJob = Start-Job -ScriptBlock {
        $output = wsl --exec echo 'WSL2 starting...' 2>&1
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
        $output = wsl --exec echo 'WSL2 starting...' 2>&1
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
      Write-Log "Waiting for Docker Desktop to start - 30 seconds..."
      Show-ProgressBar -Activity "Starting Docker Desktop" -DurationSeconds 30 -CompletedMessage "Verifying readiness"

      # Verify Docker is responding
      $retries = 6
      $dockerReady = $false
      for ($i = 1; $i -le $retries; $i++) {
        try {
          $null = docker ps 2>&1
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
if (-not $SkipLMStudio) {
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
        # Use cmd's "start" to launch LM Studio detached so it doesn't tie up
        # the PowerShell console (some apps spawn a console output otherwise).
        $lmDir = Split-Path -Path $lmStudioPath -Parent
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "start", '""', "`"$lmStudioPath`"" -WorkingDirectory $lmDir -ErrorAction Stop
        Write-Log "[OK] LM Studio started (detached) from: $lmStudioPath"
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
}
else {
  Write-Log "[i] LM Studio startup skipped (SkipLMStudio parameter)."
}

# Load projects from config.env file
$configFile = Join-Path $PSScriptRoot "config.env"
$projects = @()

if (Test-Path $configFile) {
  Write-Log "Loading Docker Compose projects from config.env..."
  $projects = Get-Content $configFile | Where-Object {
    $_ -notmatch '^\s*#' -and $_ -match '\S'
  } | ForEach-Object { $_.Trim() }

  if ($projects.Count -eq 0) {
    Write-Log "[!] No projects found in config.env. Using defaults..."
    $projects = @("infra-core", "librechat", "qdrant")
  }
  else {
    Write-Log "[OK] Loaded $($projects.Count) project(s) from config.env"
  }
}
else {
  Write-Log "[!] config.env not found. Using default projects..."
  $projects = @("infra-core", "librechat", "qdrant")
}

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
if (-not $Quiet) {
  Write-Host "Log file created at: $logFile" -ForegroundColor Green
  Write-Host ""
}

# Run status check after completion
if (-not $Quiet) {
  Write-Host "========================================" -ForegroundColor Cyan
  Write-Host "  POST-START STATUS CHECK" -ForegroundColor White
  Write-Host "========================================" -ForegroundColor Cyan
  Write-Host ""

  # Check WSL2
  $wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
  if ($null -ne $wslInstalled) {
    try {
      $wslDistros = wsl -l --running 2>&1
      if ($LASTEXITCODE -eq 0 -and $wslDistros -and $wslDistros.Count -gt 1) {
        $runningCount = ($wslDistros | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }).Count
        if ($runningCount -gt 0) {
          Write-Host "  [OK] WSL2: $runningCount distribution(s) running" -ForegroundColor Green
        }
        else {
          Write-Host "  [!] WSL2: No distributions running" -ForegroundColor Yellow
        }
      }
      else {
        Write-Host "  [!] WSL2: No distributions running" -ForegroundColor Yellow
      }
    }
    catch {
      Write-Host "  [?] WSL2: Unable to query status" -ForegroundColor DarkGray
    }
  }

  # Check Docker Desktop
  $dockerDesktopProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
  if ($null -ne $dockerDesktopProcess) {
    Write-Host "  [OK] Docker Desktop: Running" -ForegroundColor Green
  }
  else {
    Write-Host "  [!] Docker Desktop: Not running" -ForegroundColor Yellow
  }

  # Check Docker Engine
  try {
    docker info >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "  [OK] Docker Engine: Responding" -ForegroundColor Green

      # Check containers
      $runningContainers = docker ps -q 2>&1
      if ($LASTEXITCODE -eq 0) {
        $runningCount = if ($runningContainers) { ($runningContainers | Measure-Object).Count } else { 0 }
        if ($runningCount -gt 0) {
          Write-Host "  [OK] Docker Containers: $runningCount running" -ForegroundColor Green
        }
        else {
          Write-Host "  [!] Docker Containers: None running" -ForegroundColor Yellow
        }
      }
    }
    else {
      Write-Host "  [!] Docker Engine: Not responding" -ForegroundColor Yellow
    }
  }
  catch {
    Write-Host "  [!] Docker Engine: Not responding" -ForegroundColor Yellow
  }

  # Check LM Studio
  $lmStudioProcess = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue
  if ($null -ne $lmStudioProcess) {
    $processCount = ($lmStudioProcess | Measure-Object).Count
    Write-Host "  [OK] LM Studio: Running ($processCount process(es))" -ForegroundColor Green
  }
  else {
    Write-Host "  [!] LM Studio: Not running" -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "========================================" -ForegroundColor Cyan
  Write-Host ""
}

# Interactive menu (unless NoWait is specified)
if (-not $NoWait -and -not $Quiet) {
  Write-Host "What would you like to do next?" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  [1] Check Full Status  (./check-mode.ps1)" -ForegroundColor Cyan
  Write-Host "  [2] Stop Work Mode  (./game-mode.ps1)" -ForegroundColor Red
  Write-Host "  [3] View Log File" -ForegroundColor Yellow
  Write-Host -NoNewline "  [X/0] "
  Write-Host "Exit" -ForegroundColor Gray
  Write-Host ""

  $choice = Read-Host "Enter your choice (1, 2, 3 or X/0)"
  $choice = $choice.Trim()
  $choiceUpper = $choice.ToUpper()

  switch ($choiceUpper) {
    "1" {
      Write-Host ""
      Write-Host "Running full status check..." -ForegroundColor Cyan
      Write-Host ""
      & "$PSScriptRoot\check-mode.ps1"
    }
    "2" {
      Write-Host ""
      Write-Host "Stopping work mode..." -ForegroundColor Red
      Write-Host ""
      & "$PSScriptRoot\game-mode.ps1"
    }
    "3" {
      Write-Host ""
      if (Test-Path $logFile) {
        Get-Content $logFile | Write-Host
      }
      else {
        Write-Host "Log file not found." -ForegroundColor Yellow
      }
      Write-Host ""
      Write-Host "Press any key to continue..." -ForegroundColor Gray
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    "X" {
      Write-Host ""
      Write-Host "Exiting..." -ForegroundColor Gray
      exit 0
    }
    "0" {
      Write-Host ""
      Write-Host "Exiting..." -ForegroundColor Gray
      exit 0
    }
    default {
      Write-Host ""
      Write-Host "Invalid choice. Exiting..." -ForegroundColor Yellow
      exit 0
    }
  }
}
elseif ($Quiet) {
  # Quiet mode - just exit
  exit 0
}
else {
  # NoWait mode - show brief message
  Write-Host "Work mode started. Use './check-mode.ps1' to verify status." -ForegroundColor Green
  exit 0
}
