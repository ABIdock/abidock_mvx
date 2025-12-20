# Release Status Checker
# Check current package status, latest versions, and health

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host ""
}

function Get-LocalVersion {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*([\d\.\-\+\w]+)') {
        return $matches[1]
    }
    return "Unknown"
}

function Get-GitStatus {
    $status = git status --porcelain
    if ($status) {
        return @{
            Clean   = $false
            Changes = $status
        }
    }
    return @{
        Clean   = $true
        Changes = $null
    }
}

function Get-LatestTag {
    $tag = git describe --tags --abbrev=0 2>$null
    if ($tag) {
        return $tag
    }
    return "No tags"
}

function Get-PublishedVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://pub.dev/api/packages/abidock_mvx" -ErrorAction SilentlyContinue
        return $response.latest.version
    }
    catch {
        return "Not published or error fetching"
    }
}

function Test-PackageHealth {
    $errors = @()
    
    # Check if dart is available
    if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
        $errors += "Dart is not installed or not in PATH"
    }
    
    # Check if pubspec.yaml exists
    if (-not (Test-Path "pubspec.yaml")) {
        $errors += "pubspec.yaml not found"
    }
    
    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $errors += "Git is not installed or not in PATH"
    }
    
    # Check if on main branch
    $branch = git branch --show-current 2>$null
    if ($branch -and $branch -ne "main" -and $branch -ne "master") {
        $errors += "Not on main/master branch (current: $branch)"
    }
    
    return $errors
}

function Get-TestStatus {
    Write-Host "  Running tests..." -ForegroundColor Gray
    $output = dart test 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Count passed tests
        if ($output -match 'All tests passed') {
            return @{
                Status  = "Passing"
                Color   = "Green"
                Details = "All tests passed"
            }
        }
        elseif ($output -match '(\d+)\s+tests?\s+passed') {
            return @{
                Status  = "Passing"
                Color   = "Green"
                Details = "$($matches[1]) tests passed"
            }
        }
        return @{
            Status  = "Passing"
            Color   = "Green"
            Details = "Tests completed successfully"
        }
    }
    return @{
        Status  = "Failing"
        Color   = "Red"
        Details = "Some tests failed"
    }
}

function Get-AnalysisStatus {
    Write-Host "  Running analysis..." -ForegroundColor Gray
    $output = dart analyze 2>&1
    if ($LASTEXITCODE -eq 0) {
        return @{
            Status  = "Clean"
            Color   = "Green"
            Details = "No issues found"
        }
    }
    
    # Check for errors vs warnings
    if ($output -match 'error') {
        return @{
            Status  = "Errors"
            Color   = "Red"
            Details = "Analysis found errors"
        }
    }
    return @{
        Status  = "Warnings"
        Color   = "Yellow"
        Details = "Analysis found warnings"
    }
}

function Get-PubStatus {
    Write-Host "  Running pub check..." -ForegroundColor Gray
    $output = dart pub publish --dry-run 2>&1 | Out-String
    if ($output -match 'Package has (\d+) warning') {
        $warningCount = $matches[1]
        return @{
            Status  = "Warnings"
            Color   = "Yellow"
            Details = "$warningCount warning(s)"
        }
    }
    elseif ($output -match 'Package has 0 warnings') {
        return @{
            Status  = "Ready"
            Color   = "Green"
            Details = "0 warnings"
        }
    }
    elseif ($LASTEXITCODE -eq 0) {
        return @{
            Status  = "Ready"
            Color   = "Green"
            Details = "Package validated"
        }
    }
    return @{
        Status  = "Issues"
        Color   = "Red"
        Details = "Package validation failed"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host " ABIDOCK_MVX RELEASE STATUS CHECKER" -ForegroundColor Magenta
Write-Host ""

try {
    # Section 1: Version Information
    Write-Section "VERSION INFORMATION"
    
    $localVersion = Get-LocalVersion
    $latestTag = Get-LatestTag
    $publishedVersion = Get-PublishedVersion
    
    Write-Host "  Local Version (pubspec.yaml):  " -NoNewline
    Write-Host $localVersion -ForegroundColor Yellow
    
    Write-Host "  Latest Git Tag:                " -NoNewline
    Write-Host $latestTag -ForegroundColor Cyan
    
    Write-Host "  Published on pub.dev:          " -NoNewline
    Write-Host $publishedVersion -ForegroundColor $(if ($publishedVersion -match '^\d+') { "Green" } else { "Red" })
    
    # Check version sync
    if ($localVersion -eq $latestTag.TrimStart('v') -and $localVersion -eq $publishedVersion) {
        Write-Host ""
        Write-Host "   All versions in sync!" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "    Versions out of sync!" -ForegroundColor Yellow
    }
    
    # Section 2: Git Status
    Write-Section "GIT STATUS"
    
    $gitStatus = Get-GitStatus
    $branch = git branch --show-current
    
    Write-Host "  Current Branch:     " -NoNewline
    Write-Host $branch -ForegroundColor Cyan
    
    Write-Host "  Working Directory:  " -NoNewline
    if ($gitStatus.Clean) {
        Write-Host "Clean " -ForegroundColor Green
    }
    else {
        Write-Host "Uncommitted changes " -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Modified files:" -ForegroundColor Gray
        $gitStatus.Changes | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
    }
    
    # Section 3: Package Health
    Write-Section "PACKAGE HEALTH"
    
    $healthErrors = Test-PackageHealth
    if ($healthErrors.Count -eq 0) {
        Write-Host "   All prerequisites met" -ForegroundColor Green
    }
    else {
        Write-Host "    Issues found:" -ForegroundColor Yellow
        $healthErrors | ForEach-Object {
            Write-Host "     $_" -ForegroundColor Red
        }
    }
    
    # Section 4: Test & Analysis Status
    Write-Section "QUALITY CHECKS"
    
    $testStatus = Get-TestStatus
    Write-Host "  Tests:      " -NoNewline
    Write-Host "$($testStatus.Status) - $($testStatus.Details)" -ForegroundColor $testStatus.Color
    
    $analysisStatus = Get-AnalysisStatus
    Write-Host "  Analysis:   " -NoNewline
    Write-Host "$($analysisStatus.Status) - $($analysisStatus.Details)" -ForegroundColor $analysisStatus.Color
    
    $pubStatus = Get-PubStatus
    Write-Host "  Pub Check:  " -NoNewline
    Write-Host "$($pubStatus.Status) - $($pubStatus.Details)" -ForegroundColor $pubStatus.Color
    
    # Section 5: Quick Stats
    Write-Section "PACKAGE STATISTICS"
    
    # Count files
    $dartFiles = (Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse -File).Count
    $testFiles = (Get-ChildItem -Path "test" -Filter "*.dart" -Recurse -File -ErrorAction SilentlyContinue).Count
    
    Write-Host "  Dart files in lib/:   $dartFiles"
    Write-Host "  Test files:           $testFiles"
    
    # Recent commits
    Write-Host ""
    Write-Host "  Recent commits:" -ForegroundColor Gray
    git log --oneline -5 | ForEach-Object {
        Write-Host "    $_" -ForegroundColor Gray
    }
    
    # Section 6: Recommendations
    Write-Section "RECOMMENDATIONS"
    
    $canPublish = $gitStatus.Clean -and 
    $testStatus.Status -eq "Passing" -and 
    $analysisStatus.Status -eq "Clean" -and 
    $pubStatus.Status -eq "Ready"
    
    if ($canPublish) {
        Write-Host "   Package is ready for publishing!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  To publish a patch version:" -ForegroundColor Cyan
        Write-Host "    .\scripts\publish.ps1 -VersionType patch -Message 'Your message'" -ForegroundColor White
        Write-Host ""
        Write-Host "  For quick publish:" -ForegroundColor Cyan
        Write-Host "    .\scripts\quick-publish.ps1 -Message 'Your message'" -ForegroundColor White
    }
    else {
        Write-Host "    Package needs attention before publishing:" -ForegroundColor Yellow
        Write-Host ""
        
        if (-not $gitStatus.Clean) {
            Write-Host "     Commit or stash uncommitted changes" -ForegroundColor Yellow
        }
        if ($testStatus.Status -ne "Passing") {
            Write-Host "     Fix failing tests" -ForegroundColor Yellow
        }
        if ($analysisStatus.Status -ne "Clean") {
            Write-Host "     Resolve analysis issues" -ForegroundColor Yellow
        }
        if ($pubStatus.Status -ne "Ready") {
            Write-Host "     Fix package validation warnings" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Section "USEFUL LINKS"
    
    Write-Host "   pub.dev package:   https://pub.dev/packages/abidock_mvx"
    Write-Host "   GitHub repo:       https://github.com/ABIdock/abidock_mvx"
    Write-Host "   GitHub Actions:    https://github.com/ABIdock/abidock_mvx/actions"
    Write-Host "   pub.dev score:     https://pub.dev/packages/abidock_mvx/score"
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host " Error: $_" -ForegroundColor Red
    exit 1
}
