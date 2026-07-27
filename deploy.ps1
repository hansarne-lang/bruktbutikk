param([string]$msg = "")

$git = "C:\Program Files\Git\cmd\git.exe"
$repo = $PSScriptRoot

Set-Location $repo

# Fjern index.lock hvis den finnes
$lock = Join-Path $repo ".git\index.lock"
if (Test-Path $lock) {
    Remove-Item $lock -Force
    Write-Host "Fjernet gammel index.lock" -ForegroundColor Yellow
}

# Vis status
& $git status --short

# Be om commit-melding hvis ikke gitt
if ($msg -eq "") {
    $msg = Read-Host "`nCommit-melding"
}
if ($msg -eq "") { Write-Host "Avbrutt (ingen melding)"; exit 1 }

# Add alle endringer
& $git add -A
& $git commit -m $msg

# Push
& $git push origin main

Write-Host "`n✅ Ferdig! Bygg starter på GitHub Actions." -ForegroundColor Green
pause
