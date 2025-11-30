# check-mode.ps1
# Checks current system mode status (Docker, WSL2, LM Studio)

#Requires -Version 5.1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
# Rainbow "GAMING MODE" title
$title = "GAMING MODE"
$titleColors = @("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta")
Write-Host -NoNewline "   "
for ($i = 0; $i -lt $title.Length; $i++) {
  $ch = $title[$i]
  $color = $titleColors[$i % $titleColors.Count]
  Write-Host -NoNewline $ch -ForegroundColor $color
}
Write-Host ""
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

# Check processes and report memory usage
function Check-ProcessMemory {
  param(
    [string[]]$Processes,
    [int]$WarnMB = 1024
  )
  $notFound = @()
  foreach ($p in $Processes) {
    try {
      $procs = Get-Process -Name $p -ErrorAction SilentlyContinue

      if ($null -eq $procs) {
        $notFound += $p
      }
      else {
        $count = ($procs | Measure-Object).Count
        $totalBytes = ($procs | Measure-Object -Property WorkingSet64 -Sum).Sum
        $totalMB = [math]::Round(($totalBytes / 1MB), 2)
        $details = "$totalMB MB across $count process(es)"

        if ($totalMB -ge $WarnMB) {
          Show-Status -Component $p -Status "PARTIAL" -Details "$details - Consider closing manually"
        }
        else {
          Show-Status -Component $p -Status "RUNNING" -Details $details
        }
      }
    }
    catch {
      Show-Status -Component $p -Status "STOPPED" -Details "Unable to query"
    }
  }

  if ($notFound.Count -gt 0) {
    $list = ($notFound -join ", ")
    Show-Status -Component "Not Running" -Status "NOT FOUND" -Details $list
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

# Check common browsers and IDEs for memory usage
Write-Host "Checking Common Browsers/IDEs (memory usage)..." -ForegroundColor Cyan
$commonApps = @(
  "chrome",            # Google Chrome
  "Code",              # VS Code
  "Code - Insiders",   # VS Code Insiders (variant names)
  "code-insiders",     # alternative Insiders process name
  "devenv",            # Visual Studio (devenv.exe)
  "idea64",            # IntelliJ/IDEA
  "pycharm64",         # PyCharm
  "rider64",           # JetBrains Rider
  "cursor",            # Cursor IDE
  "vscodium",          # VSCodium
  "vscodium-insiders", # VSCodium Insiders (fork variant)
  "sublime_text",      # Sublime Text
  "notepad++"          # Notepad++
)

Check-ProcessMemory -Processes $commonApps -WarnMB 1024

# Check VMware processes specifically and advise manual closure (VMs are like IDEs)
Write-Host "Checking VMware..." -ForegroundColor Cyan
$vmProcesses = @()
try {
  $vmProcesses += Get-Process -Name "vmware" -ErrorAction SilentlyContinue
  $vmProcesses += Get-Process -Name "vmware-vmx" -ErrorAction SilentlyContinue
  $vmProcesses += Get-Process -Name "vmplayer" -ErrorAction SilentlyContinue
}
catch {
  # ignore errors
}

if ($vmProcesses -and $vmProcesses.Count -gt 0) {
  $count = ($vmProcesses | Measure-Object).Count
  $totalMB = [math]::Round((($vmProcesses | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB), 2)
  Show-Status -Component "VMware" -Status "PARTIAL" -Details "$totalMB MB across $count process(es) - Manual: close VMs/VMware if you plan to game"
  $vmwareRunning = $true
}
else {
  Show-Status -Component "VMware" -Status "NOT FOUND" -Details "Not running"
  $vmwareRunning = $false
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
# Cooler Game Mode entry with emoji and a short tagline
Write-Host -NoNewline "  [2] "
Write-Host -NoNewline "Start " -ForegroundColor Magenta
Write-Host -NoNewline "GAME " -ForegroundColor Red
Write-Host "MODE  (./game-mode.ps1)" -ForegroundColor Yellow
Write-Host "  [3] Check Again (re-run status)" -ForegroundColor Cyan
Write-Host -NoNewline "  [X/0] "
Write-Host "Exit" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter your choice (1, 2, 3 or X/0)"

# Normalize input for easier handling
$choice = $choice.Trim()
$choiceUpper = $choice.ToUpper()

switch ($choiceUpper) {
  "1" {
    Write-Host ""
    Write-Host "Starting Work Mode..." -ForegroundColor Green
    Write-Host ""
    & "$PSScriptRoot\work-mode.ps1"
  }
  "2" {
    Write-Host ""
    # Fun launch banner: rainbow "LET'S PLAY" with a controller
    $banner = "LET'S PLAY"
    $colors = @('Cyan', 'Green', 'Yellow', 'Magenta', 'Blue', 'Red')
    Write-Host "   [PLAY] " -NoNewline -ForegroundColor Yellow
    for ($i = 0; $i -lt $banner.Length; $i++) {
      $char = $banner[$i]
      $col = $colors[$i % $colors.Count]
      Write-Host -NoNewline $char -ForegroundColor $col
    }
    Write-Host "  - Have fun!" -ForegroundColor Gray
    Write-Host ""
    Start-Sleep -Milliseconds 700
    & "$PSScriptRoot\game-mode.ps1"
  }
  "3" {
    Write-Host ""
    Write-Host "Re-checking status..." -ForegroundColor Cyan
    Write-Host ""
    & "$PSScriptRoot\check-mode.ps1"
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
