# Initial Release Script - Publish current version without bumping
# Usage: .\scripts\initial-release.ps1 -Message "Initial public release"
# Use this ONLY for the first release of the package

param(
    [Parameter(Mandatory = $false)]
    [string]$Message = "Initial public release",
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warn { Write-Host $args -ForegroundColor Yellow }

Write-Host ""
Write-Host "[INITIAL RELEASE]" -ForegroundColor Magenta
Write-Host "   Private: github.com/ReneDuris/abidock_mvx" -ForegroundColor DarkGray
Write-Host "   Public:  github.com/ABIdock/abidock_mvx" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Warn "DRY RUN MODE - No changes will be made"
    Write-Host ""
}

try {
    # Get current version from pubspec
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*(\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?)') {
        $version = $matches[1]
    }
    else {
        throw "Could not parse version from pubspec.yaml"
    }

    Write-Info "Version: $version"
    Write-Host ""

    # Run tests
    Write-Info ">> Running tests..."
    dart test 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Tests failed!" -ForegroundColor Red
        exit 1
    }
    Write-Success "   [OK] Tests passed"

    # Run analysis
    Write-Info ">> Running analysis..."
    $analysisResult = dart analyze 2>&1
    if ($analysisResult -match 'error') {
        Write-Host "[ERROR] Analysis errors!" -ForegroundColor Red
        exit 1
    }
    Write-Success "   [OK] Analysis passed"

    # Dry-run pub publish
    Write-Info ">> Checking pub.dev requirements..."
    dart pub publish --dry-run 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Publish dry-run failed!" -ForegroundColor Red
        exit 1
    }
    Write-Success "   [OK] Package ready for pub.dev"

    if ($DryRun) {
        Write-Host ""
        Write-Warn "DRY RUN COMPLETE - No changes made"
        Write-Host ""
        Write-Host "To perform the actual release, run:" -ForegroundColor DarkGray
        Write-Host "   .\scripts\initial-release.ps1 -Message `"$Message`"" -ForegroundColor White
        exit 0
    }

    # Confirmation
    Write-Host ""
    Write-Warn "[WARNING] This will:"
    Write-Host "   1. Commit any pending changes" -ForegroundColor DarkGray
    Write-Host "   2. Create tag v$version" -ForegroundColor DarkGray
    Write-Host "   3. Push to PRIVATE repository" -ForegroundColor DarkGray
    Write-Host "   4. Push to PUBLIC repository" -ForegroundColor DarkGray
    Write-Host "   5. Trigger pub.dev publish via GitHub Actions" -ForegroundColor DarkGray
    Write-Host ""
    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Gray
        exit 0
    }

    # Stage and commit any pending changes
    $status = git status --porcelain
    if ($status) {
        Write-Info ">> Committing pending changes..."
        git add -A
        git commit -m "chore: prepare v$version - $Message"
    }

    # Create tag
    Write-Info ">> Creating tag v$version..."
    git tag -a "v$version" -m "$Message"

    # Push to private
    Write-Info ">> Pushing to private repository..."
    git push private main
    git push private "v$version"

    # Push to public
    Write-Info ">> Pushing to public repository..."
    git push public main
    git push public "v$version"

    Write-Host ""
    Write-Success "[SUCCESS] Initial release v$version complete!"
    Write-Host ""
    Write-Host "GitHub Actions will publish to pub.dev automatically." -ForegroundColor Yellow
    Write-Host "Monitor: https://github.com/ABIdock/abidock_mvx/actions" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}
