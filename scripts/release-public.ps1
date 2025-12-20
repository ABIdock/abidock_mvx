# Release to Public - Full Publishing Workflow
# Usage: .\scripts\release-public.ps1 -VersionType patch -Message "Bug fixes"
# This creates a release on the public repo (ABIdock/abidock_mvx) and publishes to pub.dev

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$VersionType,
    
    [Parameter(Mandatory = $false)]
    [string]$Message = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warn { Write-Host $args -ForegroundColor Yellow }

Write-Host ""
Write-Host "[PUBLIC RELEASE]" -ForegroundColor Green
Write-Host "   Repository: github.com/ABIdock/abidock_mvx" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Warn "DRY RUN MODE - No changes will be made"
    Write-Host ""
}

try {
    # Check for uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Host "[ERROR] Working directory is not clean!" -ForegroundColor Red
        git status --short
        exit 1
    }

    # Ensure on main branch
    $branch = git branch --show-current
    if ($branch -ne "main") {
        Write-Host "[ERROR] Not on main branch (current: $branch)" -ForegroundColor Red
        exit 1
    }

    # Get versions
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
        $currentVersion = "$major.$minor.$patch"
    }
    else {
        throw "Could not parse version from pubspec.yaml"
    }

    switch ($VersionType) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
    }
    $newVersion = "$major.$minor.$patch"

    Write-Info "Current version: $currentVersion"
    Write-Info "New version:     $newVersion"
    Write-Host ""

    # Run tests
    if (-not $SkipTests) {
        Write-Info ">> Running tests..."
        dart test 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Tests failed!" -ForegroundColor Red
            exit 1
        }
        Write-Success "   [OK] Tests passed"
    }

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
        exit 0
    }

    # Confirmation
    Write-Host ""
    Write-Warn "[WARNING] This will:"
    Write-Host "   1. Update version to $newVersion" -ForegroundColor DarkGray
    Write-Host "   2. Push to PUBLIC repository" -ForegroundColor DarkGray
    Write-Host "   3. Create release tag v$newVersion" -ForegroundColor DarkGray
    Write-Host "   4. Trigger pub.dev publish via GitHub Actions" -ForegroundColor DarkGray
    Write-Host ""
    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Gray
        exit 0
    }

    # Update pubspec.yaml
    Write-Info ">> Updating version..."
    $content = Get-Content "pubspec.yaml" -Raw
    $content = $content -replace 'version:\s*\d+\.\d+\.\d+', "version: $newVersion"
    Set-Content "pubspec.yaml" $content -NoNewline

    # Update CHANGELOG.md
    Write-Info ">> Updating CHANGELOG..."
    $date = Get-Date -Format "yyyy-MM-dd"
    $changelogMessage = if ($Message) { $Message } else { "$VersionType version bump" }
    $changelogEntry = @"
## [$newVersion] - $date

### Changed
- $changelogMessage

"@
    $changelog = Get-Content "CHANGELOG.md" -Raw
    $changelog = $changelog -replace '(## \[Unreleased\].*?\n\n)', "`$1$changelogEntry"
    Set-Content "CHANGELOG.md" $changelog -NoNewline

    # Commit and tag
    Write-Info ">> Committing changes..."
    git add pubspec.yaml CHANGELOG.md
    $commitMsg = if ($Message) { "chore: release v$newVersion - $Message" } else { "chore: release v$newVersion" }
    git commit -m $commitMsg
    git tag -a "v$newVersion" -m "Release v$newVersion"

    # Push to private first
    Write-Info ">> Pushing to private repository..."
    git push private main
    git push private "v$newVersion"

    # Push to public
    Write-Info ">> Pushing to public repository..."
    git push public main
    git push public "v$newVersion"

    Write-Host ""
    Write-Success "[SUCCESS] Released v$newVersion successfully!"
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
