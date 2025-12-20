# Quick Publish Script - Simplified version for rapid releases
# Usage: .\scripts\quick-publish.ps1 -Message "Fix bug in wallet generation"

param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "🚀 QUICK PUBLISH - PATCH VERSION" -ForegroundColor Cyan
Write-Host ""

try {
    # Get current version
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*(\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $patch = [int]$matches[2] + 1
        $newVersion = "$prefix$patch"
    }
    else {
        throw "Could not parse version from pubspec.yaml"
    }
    
    Write-Host "→ New version: $newVersion" -ForegroundColor Yellow
    Write-Host ""
    
    # Quick tests
    Write-Host "→ Running quick validation..." -ForegroundColor Cyan
    dart pub get | Out-Null
    dart test 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Tests failed!"
    }
    
    # Update version
    $content = Get-Content "pubspec.yaml" -Raw
    $content = $content -replace 'version:\s*\d+\.\d+\.\d+', "version: $newVersion"
    Set-Content "pubspec.yaml" $content -NoNewline
    
    # Update changelog
    $date = Get-Date -Format "yyyy-MM-dd"
    $changelogEntry = @"
## [$newVersion] - $date

### Changed
- $Message

"@
    $changelog = Get-Content "CHANGELOG.md" -Raw
    $changelog = $changelog -replace '(## \[Unreleased\].*?\n\n)', "`$1$changelogEntry"
    Set-Content "CHANGELOG.md" $changelog -NoNewline
    
    # Git operations
    Write-Host "→ Committing and pushing..." -ForegroundColor Cyan
    git add pubspec.yaml CHANGELOG.md
    git commit -m "chore: release v$newVersion - $Message"
    git tag -a "v$newVersion" -m "Release v$newVersion"
    git push private main
    git push private "v$newVersion"
    git push public main
    git push public "v$newVersion"
    
    Write-Host ""
    Write-Host "✅ Published v$newVersion successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "GitHub Actions will automatically publish to pub.dev" -ForegroundColor Yellow
    Write-Host "Monitor: https://github.com/ABIdock/abidock_mvx/actions" -ForegroundColor Cyan
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
