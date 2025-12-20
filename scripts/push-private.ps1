# Push to Private Repository
# Usage: .\scripts\push-private.ps1 -Message "Your commit message"
# This pushes to the private repo (ReneDuris/abidock_mvx) for internal testing

param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "PUSH TO PRIVATE REPOSITORY" -ForegroundColor Magenta
Write-Host "   Repository: github.com/ReneDuris/abidock_mvx" -ForegroundColor DarkGray
Write-Host ""

try {
    # Check for uncommitted changes
    $status = git status --porcelain
    if (-not $status) {
        Write-Host "No changes to commit" -ForegroundColor Yellow
        exit 0
    }

    # Run quick validation
    Write-Host "> Running validation..." -ForegroundColor Cyan
    dart pub get | Out-Null
    dart analyze 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Analysis warnings detected (continuing anyway)" -ForegroundColor Yellow
    }

    # Stage all changes
    Write-Host "> Staging changes..." -ForegroundColor Cyan
    git add -A

    # Commit
    Write-Host "> Committing: $Message" -ForegroundColor Cyan
    git commit -m $Message

    # Push to private remote
    Write-Host "> Pushing to private repository..." -ForegroundColor Cyan
    git push private main

    Write-Host ""
    Write-Host "Successfully pushed to private repository!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Test changes in private repo" -ForegroundColor DarkGray
    Write-Host "  2. When ready, run: .\scripts\sync-to-public.ps1" -ForegroundColor DarkGray
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
