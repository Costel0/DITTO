[CmdletBinding()]
param(
  [switch]$ValidateOnly,
  [switch]$SkipHosting
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = $PSScriptRoot
$functionsDir = Join-Path $repoRoot 'functions'
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

  foreach ($command in @('git', 'npm', 'flutter', 'firebase')) {
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

  $branch = (& git -C $repoRoot branch --show-current).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not determine the current Git branch.'
  }

  $unmerged = @(& git -C $repoRoot diff --name-only --diff-filter=U)
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not inspect Git merge conflicts.'
  }
  if ($unmerged.Count -gt 0) {
    throw "Unresolved Git conflicts detected: $($unmerged -join ', ')"
  }

  $workingTreeChanges = @(& git -C $repoRoot status --short)
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not inspect Git working tree status.'
  }

  Write-Host "Repository: $repoRoot"
  Write-Host "Branch:     $branch"
  Write-Host "Firebase:   $projectId"
  if ($workingTreeChanges.Count -gt 0) {
    Write-Warning 'The working tree has uncommitted changes. The script will validate and deploy the files exactly as they exist locally.'
  }

  Invoke-NativeStep `
    -Title 'Install exact Functions dependencies (npm ci)' `
    -Command 'npm' `
    -Arguments @('ci') `
    -WorkingDirectory $functionsDir

  # ---- Validation phase: nothing below this comment writes to Firebase. ----
  Invoke-NativeStep `
    -Title 'Validate public item catalog' `
    -Command 'npm' `
    -Arguments @('run', 'sync:items:check') `
    -WorkingDirectory $functionsDir

  Invoke-NativeStep `
    -Title 'Validate private server data' `
    -Command 'npm' `
    -Arguments @('run', 'sync:server-data:check') `
    -WorkingDirectory $functionsDir

  Invoke-NativeStep `
    -Title 'Run Functions tests' `
    -Command 'npm' `
    -Arguments @('test') `
    -WorkingDirectory $functionsDir

  Invoke-NativeStep `
    -Title 'Run Flutter tests' `
    -Command 'flutter' `
    -Arguments @('test') `
    -WorkingDirectory $repoRoot

  # Normal flutter analyze blocks on errors/warnings but does not turn purely
  # stylistic info-level lints into deployment failures.
  Invoke-NativeStep `
    -Title 'Run Flutter analyzer' `
    -Command 'flutter' `
    -Arguments @('analyze') `
    -WorkingDirectory $repoRoot

  if (-not $SkipHosting) {
    Invoke-NativeStep `
      -Title 'Build Flutter web release' `
      -Command 'flutter' `
      -Arguments @('build', 'web', '--release') `
      -WorkingDirectory $repoRoot
  }

  if ($ValidateOnly) {
    Write-Host "`nAll validation steps passed. ValidateOnly was specified, so Firebase was not modified." -ForegroundColor Green
    exit 0
  }

  # ---- Deployment phase. Keep the order intentionally conservative. ----
  # Deploy code/rules before publishing possibly newer server-data schemas.
  Invoke-NativeStep `
    -Title 'Deploy Cloud Functions and Firestore rules' `
    -Command 'firebase' `
    -Arguments @('deploy', '--project', $projectId, '--only', 'functions,firestore:rules') `
    -WorkingDirectory $repoRoot

  Invoke-NativeStep `
    -Title 'Publish public item catalog' `
    -Command 'npm' `
    -Arguments @('run', 'sync:items:exact') `
    -WorkingDirectory $functionsDir

  Invoke-NativeStep `
    -Title 'Publish private server data' `
    -Command 'npm' `
    -Arguments @('run', 'sync:server-data:exact') `
    -WorkingDirectory $functionsDir

  if (-not $SkipHosting) {
    Invoke-NativeStep `
      -Title 'Deploy Firebase Hosting' `
      -Command 'firebase' `
      -Arguments @('deploy', '--project', $projectId, '--only', 'hosting') `
      -WorkingDirectory $repoRoot
  }

  Write-Host "`nValidation and deployment completed successfully." -ForegroundColor Green
}
catch {
  Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'No later deployment steps were executed.' -ForegroundColor Yellow
  exit 1
}
