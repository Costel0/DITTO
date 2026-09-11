$ErrorActionPreference = "Stop"
Push-Location (Join-Path $PSScriptRoot "functions")
try {
  & node "scripts/user_admin.js" @args
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
