# Initialize Publishing Environment
# Sets up everything needed for publishing

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "[PUBLISHING ENVIRONMENT SETUP]" -ForegroundColor Magenta
Write-Host ""

function Test-GitRepo {
    if (Test-Path ".git") {
        return $true
    }
    return $false
}

function Test-GitRemote {
    $remotes = git remote 2>$null
    if ($remotes) {
        return $remotes
    }
    return $null
}

function Get-GitRemotes {
    $remoteList = @()
    $remotes = git remote -v 2>$null
    if ($remotes) {
        foreach ($line in $remotes) {
            if ($line -match '(\S+)\s+(\S+)\s+\(fetch\)') {
                $remoteList += @{
                    Name = $matches[1]
                    Url  = $matches[2]
                }
            }
        }
    }
    return $remoteList
}

function Initialize-Git {
    Write-Host "-> Initializing Git repository..." -ForegroundColor Cyan
    git init
    Write-Host "[OK] Git repository initialized" -ForegroundColor Green
}

function Add-GitRemote {
    $url = "https://github.com/ABIdock/abidock_mvx.git"
    Write-Host "-> Adding remote repository: $url" -ForegroundColor Cyan
    git remote add origin $url
    Write-Host "[OK] Remote added" -ForegroundColor Green
}

function Set-MainBranch {
    Write-Host "-> Setting main branch..." -ForegroundColor Cyan
    git branch -M main
    Write-Host "[OK] Main branch set" -ForegroundColor Green
}

function Test-DartInstallation {
    if (Get-Command dart -ErrorAction SilentlyContinue) {
        $version = dart --version 2>&1
        Write-Host "[OK] Dart is installed: $version" -ForegroundColor Green
        return $true
    }
    Write-Host "[X] Dart is not installed" -ForegroundColor Red
    return $false
}

function Test-GitInstallation {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $version = git --version
        Write-Host "[OK] Git is installed: $version" -ForegroundColor Green
        return $true
    }
    Write-Host "[X] Git is not installed" -ForegroundColor Red
    return $false
}

function Install-Dependencies {
    Write-Host "-> Installing Dart dependencies..." -ForegroundColor Cyan
    dart pub get | Out-Null
    Write-Host "[OK] Dependencies installed" -ForegroundColor Green
}

function Test-ScriptsDirectory {
    if (Test-Path "scripts") {
        $scripts = Get-ChildItem "scripts" -Filter "*.ps1"
        Write-Host "[OK] Scripts directory exists with $($scripts.Count) scripts" -ForegroundColor Green
        return $true
    }
    Write-Host "[X] Scripts directory not found" -ForegroundColor Red
    return $false
}

function Show-PostSetupInfo {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[Next Steps]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Review the setup guide:" -ForegroundColor Yellow
    Write-Host "   code scripts\SETUP_GUIDE.md" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Check package status:" -ForegroundColor Yellow
    Write-Host "   .\scripts\status.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Check versions:" -ForegroundColor Yellow
    Write-Host "   .\scripts\version-check.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "4. Make your first commit:" -ForegroundColor Yellow
    Write-Host "   git add ." -ForegroundColor White
    Write-Host "   git commit -m 'Initial commit'" -ForegroundColor White
    Write-Host "   git push -u origin main" -ForegroundColor White
    Write-Host ""
    Write-Host "5. Publish your first release:" -ForegroundColor Yellow
    Write-Host "   .\scripts\publish.ps1 -VersionType patch -Message 'Initial release'" -ForegroundColor White
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[Documentation]" -ForegroundColor Cyan
    Write-Host "   * Setup Guide:  scripts\SETUP_GUIDE.md" -ForegroundColor White
    Write-Host "   * Script Docs:  scripts\README.md" -ForegroundColor White
    Write-Host ""
    Write-Host "[Available Scripts]" -ForegroundColor Cyan
    Write-Host "   * status.ps1        - Check release status" -ForegroundColor White
    Write-Host "   * version-check.ps1 - Compare versions" -ForegroundColor White
    Write-Host "   * publish.ps1       - Full release workflow" -ForegroundColor White
    Write-Host "   * quick-publish.ps1 - Fast patch releases" -ForegroundColor White
    Write-Host "   * pre-release.ps1   - Alpha/Beta/RC versions" -ForegroundColor White
    Write-Host "   * rollback.ps1      - Emergency rollback" -ForegroundColor White
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Host "Checking environment..." -ForegroundColor Cyan
    Write-Host ""
    
    # Check prerequisites
    $dartOk = Test-DartInstallation
    $gitOk = Test-GitInstallation
    $scriptsOk = Test-ScriptsDirectory
    
    if (-not $dartOk -or -not $gitOk) {
        Write-Host ""
        Write-Host "[X] Missing prerequisites!" -ForegroundColor Red
        Write-Host ""
        if (-not $dartOk) {
            Write-Host "Install Dart from: https://dart.dev/get-dart" -ForegroundColor Yellow
        }
        if (-not $gitOk) {
            Write-Host "Install Git from: https://git-scm.com/downloads" -ForegroundColor Yellow
        }
        exit 1
    }
    
    if (-not $scriptsOk) {
        Write-Host ""
        Write-Host "[!] Scripts directory not found!" -ForegroundColor Yellow
        Write-Host "This script should be run from the project root directory." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    
    # Git setup
    if (-not (Test-GitRepo)) {
        Write-Host "Git repository not initialized" -ForegroundColor Yellow
        $init = Read-Host "Initialize Git repository? (y/n)"
        if ($init -eq "y") {
            Initialize-Git
            Write-Host ""
        }
    }
    else {
        Write-Host "[OK] Git repository exists" -ForegroundColor Green
    }
    
    # Git remote
    $remotes = Test-GitRemote
    if (-not $remotes) {
        Write-Host "Git remote not configured" -ForegroundColor Yellow
        $addRemote = Read-Host "Add remote repository? (y/n)"
        if ($addRemote -eq "y") {
            Add-GitRemote
            Set-MainBranch
            Write-Host ""
        }
    }
    else {
        $remoteDetails = Get-GitRemotes
        Write-Host "[OK] Git remotes configured:" -ForegroundColor Green
        foreach ($r in $remoteDetails) {
            Write-Host "     $($r.Name): $($r.Url)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    
    # Install dependencies
    if (Test-Path "pubspec.yaml") {
        $deps = Read-Host "Install Dart dependencies? (y/n)"
        if ($deps -eq "y") {
            Install-Dependencies
        }
    }
    
    # Check .gitignore
    Write-Host ""
    Write-Host "-> Checking .gitignore..." -ForegroundColor Cyan
    if (Test-Path ".gitignore") {
        $gitignore = Get-Content ".gitignore" -Raw
        if ($gitignore -match 'scripts/') {
            Write-Host "[OK] scripts/ is in .gitignore (will not be committed)" -ForegroundColor Green
        }
        else {
            Write-Host "[!] scripts/ is NOT in .gitignore!" -ForegroundColor Yellow
            Write-Host "   Your publishing scripts may be committed to the repository" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[!] .gitignore not found" -ForegroundColor Yellow
    }
    
    # Test execution policy
    Write-Host ""
    Write-Host "-> Checking PowerShell execution policy..." -ForegroundColor Cyan
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq "Restricted") {
        Write-Host "[!] Execution policy is Restricted" -ForegroundColor Yellow
        Write-Host "   Scripts may not run properly" -ForegroundColor Yellow
        Write-Host ""
        $change = Read-Host "Change to RemoteSigned? (y/n)"
        if ($change -eq "y") {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
            Write-Host "[OK] Execution policy updated" -ForegroundColor Green
        }
    }
    else {
        Write-Host "[OK] Execution policy is OK: $policy" -ForegroundColor Green
    }
    
    # Show completion
    Show-PostSetupInfo
    
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}
