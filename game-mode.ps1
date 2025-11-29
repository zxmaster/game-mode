# Stop-DockerContainers-WithLogging.ps1
# Stops all running Docker containers with logging

# Define log file path
$logFile = "docker_stop.log"

# Clear log file if it exists (optional, for fresh start)
if (Test-Path $logFile) {
  Remove-Item $logFile -Force
}

Write-Host "Starting Docker container stop script..." -ForegroundColor Cyan

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
$containers = docker ps -q

if ($null -eq $containers -or $containers.Count -eq 0) {
  Write-Log "No running containers found."
}
else {
  $containerCount = ($containers | Measure-Object).Count
  Write-Log "Found $containerCount running containers. Stopping them all in parallel..."

  # Stop all containers at once
  docker stop $containers -t 10

  if ($LASTEXITCODE -eq 0) {
    Write-Log "✅ All $containerCount containers stopped successfully."
  }
  else {
    Write-Log "⚠️ Some containers may have failed to stop. Exit code: $LASTEXITCODE"
  }
}

Write-Log "All containers have been stopped or checked."
Write-Log "Script completed."

# Optional: Show log file path
Write-Host "Log file created at: $logFile" -ForegroundColor Green

# Optional: Show log file content for quick review
Write-Host "You can view the log file: $logFile" -ForegroundColor Cyan
