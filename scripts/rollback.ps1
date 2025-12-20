# Rollback Script - Undo the last release
# Usage: .\scripts\rollback.ps1

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "⚠️  ROLLBACK LAST RELEASE" -ForegroundColor Yellow
Write-Host ""

function Get-LastTag {
    $tag = git describe --tags --abbrev=0 2>$null
    if (-not $tag) {
        throw "No tags found in repository"
    }
    return $tag
}

function Get-PreviousTag {
    param([string]$CurrentTag)
    $tags = git tag --sort=-version:refname
    $found = $false
    foreach ($tag in $tags) {
        if ($found) {
            return $tag
        }
        if ($tag -eq $CurrentTag) {
            $found = $true
        }
    }
    return $null
}

try {
    # Get current and previous versions
    $currentTag = Get-LastTag
    $previousTag = Get-PreviousTag -CurrentTag $currentTag
    
    Write-Host "Current version: $currentTag" -ForegroundColor Red
    if ($previousTag) {
        Write-Host "Will rollback to: $previousTag" -ForegroundColor Green
    }
    else {
        Write-Host "Will rollback to: (initial state)" -ForegroundColor Green
    }
    Write-Host ""
    
    if (-not $Force) {
        Write-Warning "This will:"
        Write-Host "  • Delete the tag $currentTag locally and remotely"
        Write-Host "  • Reset your branch to the previous commit"
        Write-Host "  • Force push to remote (destructive operation!)"
        Write-Host ""
        $confirm = Read-Host "Are you sure you want to continue? Type 'ROLLBACK' to confirm"
        if ($confirm -ne "ROLLBACK") {
            Write-Host "Rollback cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host ""
    Write-Host "→ Removing local tag..." -ForegroundColor Cyan
    git tag -d $currentTag
    
    Write-Host "→ Removing remote tag..." -ForegroundColor Cyan
    git push origin --delete $currentTag
    
    Write-Host "→ Resetting to previous commit..." -ForegroundColor Cyan
    git reset --hard HEAD~1
    
    Write-Host "→ Force pushing to remote..." -ForegroundColor Cyan
    git push origin main --force
    
    Write-Host ""
    Write-Host "✅ Rollback completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️  Important notes:" -ForegroundColor Yellow
    Write-Host "  • If the package was already published to pub.dev, you CANNOT unpublish it"
    Write-Host "  • pub.dev versions are permanent once published"
    Write-Host "  • You'll need to publish a new version to fix any issues"
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
