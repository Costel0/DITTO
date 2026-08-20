[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = $PSScriptRoot
$firebaseRcPath = Join-Path $repoRoot '.firebaserc'

function Write-Step([string]$message) {
  Write-Host "`n==> $message" -ForegroundColor Cyan
}

function Invoke-NativeStep {
  param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Command,
    [string[]]$Arguments = @(),
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  Write-Step $Title
  Push-Location $WorkingDirectory
  try {
    & $Command @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
      throw "$Title failed with exit code $exitCode. Deployment stopped."
    }
  }
  finally {
    Pop-Location
  }
}

try {
  Write-Step 'Preflight checks'

  foreach ($command in @('flutter', 'firebase')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
      throw "Required command '$command' was not found in PATH."
    }
  }

  if (-not (Test-Path $firebaseRcPath)) {
    throw '.firebaserc was not found at the repository root.'
  }

  $firebaseRc = Get-Content $firebaseRcPath -Raw | ConvertFrom-Json
  $projectId = $firebaseRc.projects.default
  if ([string]::IsNullOrWhiteSpace($projectId)) {
    throw 'No default Firebase project is configured in .firebaserc.'
  }

  Write-Host "Repository: $repoRoot"
  Write-Host "Firebase:   $projectId"

  Invoke-NativeStep `
    -Title 'Generate Flutter localizations' `
    -Command 'flutter' `
    -Arguments @('gen-l10n') `
    -WorkingDirectory $repoRoot

  Invoke-NativeStep `
    -Title 'Build Flutter web release' `
    -Command 'flutter' `
    -Arguments @('build', 'web', '--release') `
    -WorkingDirectory $repoRoot

  Invoke-NativeStep `
    -Title 'Deploy Firebase Hosting' `
    -Command 'firebase' `
    -Arguments @('deploy', '--project', $projectId, '--only', 'hosting') `
    -WorkingDirectory $repoRoot

  Write-Host "`nHosting deployment completed successfully." -ForegroundColor Green
}
catch {
  Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
