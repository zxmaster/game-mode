# check-mode.ps1
# Checks current system mode status (Docker, WSL2, LM Studio)

#Requires -Version 5.1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   System Mode Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to display status with color
function Show-Status {
  param(
    [string]$Component,
    [string]$Status,
    [string]$Details = ""
  )

  $statusColor = switch ($Status) {
    "RUNNING" { "Green" }
    "STOPPED" { "Red" }
    "PARTIAL" { "Yellow" }
    "NOT FOUND" { "DarkGray" }
    default { "White" }
  }

  $icon = switch ($Status) {
    "RUNNING" { "[OK]" }
    "STOPPED" { "[X]" }
    "PARTIAL" { "[!]" }
    "NOT FOUND" { "[?]" }
    default { "[i]" }
  }

  Write-Host "  $icon " -NoNewline
  Write-Host ("{0,-20}" -f $Component) -NoNewline -ForegroundColor White
  Write-Host ("[{0,-10}]" -f $Status) -ForegroundColor $statusColor -NoNewline
  if ($Details) {
    Write-Host " $Details" -ForegroundColor Gray
  }
  else {
    Write-Host ""
  }
}

# Check WSL2 Status
Write-Host "Checking WSL2..." -ForegroundColor Cyan
$wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue

if ($null -eq $wslInstalled) {
  Show-Status -Component "WSL2" -Status "NOT FOUND" -Details "Not installed"
  $wslRunning = $false
}
else {
  try {
    $wslDistros = wsl -l --running 2>&1

    if ($LASTEXITCODE -eq 0 -and $wslDistros -and $wslDistros.Count -gt 1) {
      $runningCount = ($wslDistros | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }).Count
      if ($runningCount -gt 0) {
        Show-Status -Component "WSL2" -Status "RUNNING" -Details "$runningCount distribution(s) running"
        $wslRunning = $true
      }
      else {
        Show-Status -Component "WSL2" -Status "STOPPED" -Details "No distributions running"
        $wslRunning = $false
      }
    }
    else {
      Show-Status -Component "WSL2" -Status "STOPPED" -Details "No distributions running"
      $wslRunning = $false
    }
  }
  catch {
    Show-Status -Component "WSL2" -Status "STOPPED" -Details "Unable to query status"
    $wslRunning = $false
  }
}

# Check Docker Desktop Status
Write-Host "Checking Docker Desktop..." -ForegroundColor Cyan
$dockerDesktopProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue

if ($null -eq $dockerDesktopProcess) {
  Show-Status -Component "Docker Desktop" -Status "STOPPED" -Details "Process not running"
  $dockerRunning = $false
}
else {
  Show-Status -Component "Docker Desktop" -Status "RUNNING" -Details "Process active"
  $dockerRunning = $true
}

# Check Docker Engine Status
Write-Host "Checking Docker Engine..." -ForegroundColor Cyan
$dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue

if ($null -eq $dockerInstalled) {
  Show-Status -Component "Docker Engine" -Status "NOT FOUND" -Details "Command not available"
  $dockerEngineRunning = $false
}
else {
  try {
    docker info >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
      Show-Status -Component "Docker Engine" -Status "RUNNING" -Details "Responding to commands"
      $dockerEngineRunning = $true
    }
    else {
      Show-Status -Component "Docker Engine" -Status "STOPPED" -Details "Not responding"
      $dockerEngineRunning = $false
    }
  }
  catch {
    Show-Status -Component "Docker Engine" -Status "STOPPED" -Details "Not responding"
    $dockerEngineRunning = $false
  }
}

# Check Docker Containers
if ($dockerEngineRunning) {
  Write-Host "Checking Docker Containers..." -ForegroundColor Cyan
  try {
    $runningContainers = docker ps -q 2>&1
    $allContainers = docker ps -a -q 2>&1

    if ($LASTEXITCODE -eq 0) {
      $runningCount = if ($runningContainers) { ($runningContainers | Measure-Object).Count } else { 0 }
      $totalCount = if ($allContainers) { ($allContainers | Measure-Object).Count } else { 0 }

      if ($runningCount -gt 0) {
        Show-Status -Component "Docker Containers" -Status "RUNNING" -Details "$runningCount/$totalCount containers active"
      }
      elseif ($totalCount -gt 0) {
        Show-Status -Component "Docker Containers" -Status "STOPPED" -Details "0/$totalCount containers active"
      }
      else {
        Show-Status -Component "Docker Containers" -Status "STOPPED" -Details "No containers found"
      }
    }
    else {
      Show-Status -Component "Docker Containers" -Status "STOPPED" -Details "Unable to query"
    }
  }
  catch {
    Show-Status -Component "Docker Containers" -Status "STOPPED" -Details "Unable to query"
  }

  # Check specific projects
  Write-Host "Checking Docker Projects..." -ForegroundColor Cyan

  # Load projects from config.env file
  $configFile = Join-Path $PSScriptRoot "config.env"
  $projects = @()

  if (Test-Path $configFile) {
    $projects = Get-Content $configFile | Where-Object {
      $_ -notmatch '^\s*#' -and $_ -match '\S'
    } | ForEach-Object { $_.Trim() }
  }

  if ($projects.Count -eq 0) {
    $projects = @("infra-core", "librechat", "qdrant")
  }

  foreach ($project in $projects) {
    try {
      $projectContainers = docker ps --filter "label=com.docker.compose.project=$project" --format "{{.Names}}" 2>&1

      if ($LASTEXITCODE -eq 0 -and $projectContainers) {
        $containerCount = ($projectContainers | Measure-Object).Count
        Show-Status -Component "  +-- $project" -Status "RUNNING" -Details "$containerCount container(s)"
      }
      else {
        $allProjectContainers = docker ps -a --filter "label=com.docker.compose.project=$project" -q 2>&1
        if ($allProjectContainers) {
          Show-Status -Component "  +-- $project" -Status "STOPPED" -Details "Containers exist but stopped"
        }
        else {
          Show-Status -Component "  +-- $project" -Status "NOT FOUND" -Details "No containers found"
        }
      }
    }
    catch {
      Show-Status -Component "  +-- $project" -Status "STOPPED" -Details "Unable to query"
    }
  }
}
else {
  Write-Host "Skipping container checks (Docker Engine not running)..." -ForegroundColor DarkGray
}

# Check LM Studio Status
Write-Host "Checking LM Studio..." -ForegroundColor Cyan
$lmStudioProcess = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue

if ($null -eq $lmStudioProcess) {
  Show-Status -Component "LM Studio" -Status "STOPPED" -Details "Process not running"
  $lmStudioRunning = $false
}
else {
  $processCount = ($lmStudioProcess | Measure-Object).Count
  Show-Status -Component "LM Studio" -Status "RUNNING" -Details "$processCount process(es) active"
  $lmStudioRunning = $true
}

# Overall Mode Assessment
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

$workModeComponents = 0
$totalComponents = 4

if ($wslRunning) { $workModeComponents++ }
if ($dockerRunning -and $dockerEngineRunning) { $workModeComponents++ }
if ($dockerEngineRunning) {
  $runningContainers = docker ps -q 2>&1
  if ($runningContainers -and ($runningContainers | Measure-Object).Count -gt 0) {
    $workModeComponents++
  }
}
if ($lmStudioRunning) { $workModeComponents++ }

$modePercentage = [math]::Round(($workModeComponents / $totalComponents) * 100)

Write-Host "  Current Mode Assessment:" -ForegroundColor White
Write-Host ""

if ($modePercentage -ge 75) {
  Write-Host "  [WORK MODE ACTIVE]" -ForegroundColor Green
  Write-Host "     Most development services are running ($modePercentage percent active)" -ForegroundColor Gray
}
elseif ($modePercentage -ge 25) {
  Write-Host "  [PARTIAL MODE]" -ForegroundColor Yellow
  Write-Host "     Some development services are running ($modePercentage percent active)" -ForegroundColor Gray
}
else {
  Write-Host "  [GAME MODE ACTIVE]" -ForegroundColor Red
  Write-Host "     Most development services are stopped ($modePercentage percent active)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Suggestions
if ($modePercentage -lt 100 -and $modePercentage -ge 25) {
  Write-Host "Suggestions:" -ForegroundColor Cyan
  if (-not $wslRunning) {
    Write-Host "   - Run work-mode.ps1 to start WSL2" -ForegroundColor Gray
  }
  if (-not $dockerRunning -or -not $dockerEngineRunning) {
    Write-Host "   - Run work-mode.ps1 to start Docker Desktop" -ForegroundColor Gray
  }
  if (-not $lmStudioRunning) {
    Write-Host "   - Run work-mode.ps1 to start LM Studio" -ForegroundColor Gray
  }
  Write-Host ""
}
elseif ($modePercentage -ge 25) {
  Write-Host "Quick Actions:" -ForegroundColor Cyan
  Write-Host "   - Run work-mode.ps1 to start all services" -ForegroundColor Gray
  Write-Host "   - Run game-mode.ps1 to stop all services" -ForegroundColor Gray
  Write-Host ""
}

# Prompt user for action
Write-Host "What would you like to do?" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [1] Start Work Mode  (./work-mode.ps1)" -ForegroundColor Green
Write-Host "  [2] Start Game Mode  (./game-mode.ps1)" -ForegroundColor Red
Write-Host "  [3] Exit" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter your choice (1-3)"

switch ($choice) {
  "1" {
    Write-Host ""
    Write-Host "Starting Work Mode..." -ForegroundColor Green
    Write-Host ""
    & "$PSScriptRoot\work-mode.ps1"
  }
  "2" {
    Write-Host ""
    Write-Host "Starting Game Mode..." -ForegroundColor Red
    Write-Host ""
    & "$PSScriptRoot\game-mode.ps1"
  }
  "3" {
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
