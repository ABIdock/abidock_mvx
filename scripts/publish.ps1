# Enterprise-level Publishing Script for abidock_mvx
# This script handles version bumping, changelog updates, git operations, and publishing

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

# Color functions
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

function Write-Header {
    Write-Host ""
    Write-Host "" -ForegroundColor Magenta
    Write-Host "  ABIDOCK_MVX PUBLISHING SCRIPT" -ForegroundColor Magenta
    Write-Host "" -ForegroundColor Magenta
    Write-Host ""
}

function Get-CurrentVersion {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*(\d+\.\d+\.\d+)') {
        return $matches[1]
    }
    throw "Could not find version in pubspec.yaml"
}

function Get-NextVersion {
    param([string]$CurrentVersion, [string]$BumpType)
    
    $parts = $CurrentVersion.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($BumpType) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
    }
    
    return "$major.$minor.$patch"
}

function Update-PubspecVersion {
    param([string]$NewVersion)
    
    $content = Get-Content "pubspec.yaml" -Raw
    $content = $content -replace 'version:\s*\d+\.\d+\.\d+', "version: $NewVersion"
    Set-Content "pubspec.yaml" $content -NoNewline
}

function Update-Changelog {
    param([string]$Version, [string]$Message)
    
    $date = Get-Date -Format "yyyy-MM-dd"
    $content = Get-Content "CHANGELOG.md" -Raw
    
    $newEntry = @"
## [$Version] - $date

### Changed
- $Message

"@
    
    # Insert after [Unreleased] section
    $content = $content -replace '(## \[Unreleased\].*?\n\n)', "`$1$newEntry"
    Set-Content "CHANGELOG.md" $content -NoNewline
}

function Test-GitStatus {
    $status = git status --porcelain
    if ($status) {
        Write-Error "Working directory is not clean. Please commit or stash changes first."
        Write-Host $status
        exit 1
    }
}

function Test-Prerequisites {
    Write-Info " Checking prerequisites..."
    
    # Check if git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or not in PATH"
    }
    
    # Check if dart is installed
    if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
        throw "Dart is not installed or not in PATH"
    }
    
    # Check if we're in the correct directory
    if (-not (Test-Path "pubspec.yaml")) {
        throw "pubspec.yaml not found. Are you in the correct directory?"
    }
    
    # Check if we're on main branch
    $branch = git branch --show-current
    if ($branch -ne "main" -and $branch -ne "master") {
        Write-Warning "Warning: You are not on main/master branch (current: $branch)"
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne "y") {
            exit 0
        }
    }
    
    Write-Success " Prerequisites check passed"
}

function Invoke-Tests {
    Write-Info " Running tests..."
    
    dart pub get | Out-Null
    
    $result = dart test 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Tests failed!"
        Write-Host $result
        exit 1
    }
    
    Write-Success " All tests passed"
}

function Invoke-Analysis {
    Write-Info " Running static analysis..."
    
    $result = dart analyze --fatal-infos 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Check if it's just warnings
        if ($result -match 'error') {
            Write-Error "Analysis found errors!"
            Write-Host $result
            exit 1
        }
        Write-Warning "Analysis found warnings (continuing anyway)"
    }
    
    Write-Success " Analysis passed"
}

function Invoke-Format {
    Write-Info " Formatting code..."
    
    dart format . | Out-Null
    
    Write-Success " Code formatted"
}

function Test-PublishDryRun {
    Write-Info " Running publish dry-run..."
    
    $result = dart pub publish --dry-run 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Publish dry-run failed!"
        Write-Host $result
        exit 1
    }
    
    # Check for warnings
    if ($result -match '(\d+)\s+warning') {
        $warningCount = $matches[1]
        Write-Warning "Package has $warningCount warning(s)"
        Write-Host $result | Select-String "warning"
    }
    else {
        Write-Success " Publish dry-run passed with 0 warnings"
    }
}

function Invoke-GitOperations {
    param([string]$Version, [string]$Message)
    
    Write-Info " Committing changes..."
    
    git add pubspec.yaml CHANGELOG.md
    
    $commitMessage = if ($Message) {
        "chore: release v$Version - $Message"
    }
    else {
        "chore: release v$Version"
    }
    
    git commit -m $commitMessage
    Write-Success " Changes committed"
    
    Write-Info " Creating git tag..."
    git tag -a "v$Version" -m "Release v$Version"
    Write-Success " Tag v$Version created"
    
    Write-Info " Pushing to private repository..."
    git push private main
    git push private "v$Version"
    Write-Success " Pushed to private repository"
    
    Write-Info " Pushing to public repository..."
    git push public main
    git push public "v$Version"
    Write-Success " Pushed to public repository"
}

function Invoke-Publish {
    Write-Info " Publishing to pub.dev..."
    
    Write-Warning "This will publish the package to pub.dev!"
    Write-Host "Press any key to continue or Ctrl+C to cancel..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    
    dart pub publish
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success " Successfully published to pub.dev!"
    }
    else {
        Write-Error "Publishing failed!"
        exit 1
    }
}

function Show-Summary {
    param([string]$OldVersion, [string]$NewVersion, [string]$Message)
    
    Write-Host ""
    Write-Host "" -ForegroundColor Green
    Write-Host "  RELEASE SUMMARY" -ForegroundColor Green
    Write-Host "" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Old Version:  " -NoNewline; Write-Host $OldVersion -ForegroundColor Yellow
    Write-Host "  New Version:  " -NoNewline; Write-Host $NewVersion -ForegroundColor Green
    Write-Host "  Version Type: " -NoNewline; Write-Host $VersionType -ForegroundColor Cyan
    if ($Message) {
        Write-Host "  Message:      " -NoNewline; Write-Host $Message -ForegroundColor White
    }
    Write-Host ""
    Write-Host "" -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Header
    
    if ($DryRun) {
        Write-Warning "DRY RUN MODE - No changes will be made"
        Write-Host ""
    }
    
    # Step 1: Prerequisites
    Test-Prerequisites
    
    # Step 2: Check git status
    if (-not $DryRun) {
        Test-GitStatus
    }
    
    # Step 3: Get current version
    $currentVersion = Get-CurrentVersion
    $newVersion = Get-NextVersion -CurrentVersion $currentVersion -BumpType $VersionType
    
    Write-Info "Current version: $currentVersion"
    Write-Info "New version: $newVersion"
    Write-Host ""
    
    # Step 4: Tests (unless skipped)
    if (-not $SkipTests) {
        Invoke-Tests
    }
    else {
        Write-Warning " Skipping tests"
    }
    
    # Step 5: Analysis
    Invoke-Analysis
    
    # Step 6: Format
    Invoke-Format
    
    # Step 7: Update version in pubspec.yaml
    if (-not $DryRun) {
        Write-Info " Updating pubspec.yaml to version $newVersion..."
        Update-PubspecVersion -NewVersion $newVersion
        Write-Success " pubspec.yaml updated"
    }
    else {
        Write-Info " Would update pubspec.yaml to version $newVersion"
    }
    
    # Step 8: Update CHANGELOG.md
    if ($Message -and -not $DryRun) {
        Write-Info " Updating CHANGELOG.md..."
        Update-Changelog -Version $newVersion -Message $Message
        Write-Success " CHANGELOG.md updated"
    }
    elseif ($Message) {
        Write-Info " Would update CHANGELOG.md with message: $Message"
    }
    else {
        Write-Warning " No changelog message provided. Please update CHANGELOG.md manually."
    }
    
    # Step 9: Test publish
    Test-PublishDryRun
    
    # Step 10: Git operations
    if (-not $DryRun) {
        Invoke-GitOperations -Version $newVersion -Message $Message
    }
    else {
        Write-Info " Would commit changes and create tag v$newVersion"
    }
    
    # Step 11: Publish to pub.dev
    if (-not $DryRun) {
        Write-Host ""
        Write-Warning "Ready to publish to pub.dev!"
        $confirm = Read-Host "Do you want to publish now? (yes/no)"
        if ($confirm -eq "yes") {
            Invoke-Publish
        }
        else {
            Write-Info "Publishing skipped. You can publish manually later with: dart pub publish"
        }
    }
    else {
        Write-Info " Would publish to pub.dev"
    }
    
    # Final summary
    Show-Summary -OldVersion $currentVersion -NewVersion $newVersion -Message $Message
    
    if (-not $DryRun) {
        Write-Success " Release completed successfully!"
        Write-Host ""
        Write-Info "Next steps:"
        Write-Info "   Check the package on pub.dev: https://pub.dev/packages/abidock_mvx"
        Write-Info "   Verify the GitHub release: https://github.com/ABIdock/abidock_mvx/releases"
        Write-Info "   Update documentation if needed"
    }
    else {
        Write-Info "Dry run completed. No changes were made."
    }
    
}
catch {
    Write-Host ""
    Write-Error " Error: $_"
    Write-Host $_.ScriptStackTrace
    exit 1
}
