$ErrorActionPreference = "Stop"
Push-Location (Join-Path $PSScriptRoot "functions")
try {
  $script = if ($args.Count -gt 0 -and @("set-sector", "set-zone") -contains $args[0]) {
    "scripts/map_edit.js"
  }
  else {
    "scripts/map_admin.js"
  }
  & node $script @args
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
