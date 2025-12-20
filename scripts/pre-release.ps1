# Pre-release Script - Create beta/alpha versions
# Usage: .\scripts\pre-release.ps1 -Type alpha -Identifier "feature-xyz"

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('alpha', 'beta', 'rc')]
    [string]$Type,
    
    [Parameter(Mandatory = $false)]
    [string]$Identifier = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Message = "Pre-release version"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host " PRE-RELEASE BUILDER" -ForegroundColor Magenta
Write-Host ""

try {
    # Get current version
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*(\d+\.\d+\.\d+)') {
        $baseVersion = $matches[1]
    }
    else {
        throw "Could not parse version from pubspec.yaml"
    }
    
    # Get next pre-release number
    $tags = git tag | Where-Object { $_ -match "$baseVersion-$Type" }
    $nextNum = 1
    if ($tags) {
        $nums = $tags | ForEach-Object {
            if ($_ -match "$Type\.(\d+)") {
                [int]$matches[1]
            }
        }
        $nextNum = ($nums | Measure-Object -Maximum).Maximum + 1
    }
    
    # Build version string
    if ($Identifier) {
        $newVersion = "$baseVersion-$Type.$nextNum+$Identifier"
    }
    else {
        $newVersion = "$baseVersion-$Type.$nextNum"
    }
    
    Write-Host " Base version: $baseVersion" -ForegroundColor Yellow
    Write-Host " New version:  $newVersion" -ForegroundColor Green
    Write-Host ""
    
    # Run tests
    Write-Host " Running tests..." -ForegroundColor Cyan
    dart pub get | Out-Null
    dart test 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Tests failed!"
    }
    
    # Update version
    $content = Get-Content "pubspec.yaml" -Raw
    $content = $content -replace 'version:\s*[\d\.\-\+\w]+', "version: $newVersion"
    Set-Content "pubspec.yaml" $content -NoNewline
    
    # Update changelog
    $date = Get-Date -Format "yyyy-MM-dd"
    $changelogEntry = @"
## [$newVersion] - $date

### Pre-release
- $Message
- Type: $Type
$(if ($Identifier) { "- Identifier: $Identifier" })

"@
    $changelog = Get-Content "CHANGELOG.md" -Raw
    $changelog = $changelog -replace '(## \[Unreleased\].*?\n\n)', "`$1$changelogEntry"
    Set-Content "CHANGELOG.md" $changelog -NoNewline
    
    # Git operations
    Write-Host " Committing changes..." -ForegroundColor Cyan
    git add pubspec.yaml CHANGELOG.md
    git commit -m "chore: pre-release v$newVersion - $Message"
    git tag -a "v$newVersion" -m "Pre-release v$newVersion"
    
    Write-Host " Pushing to private repository..." -ForegroundColor Cyan
    git push private main
    git push private "v$newVersion"
    
    Write-Host ""
    Write-Host " Pre-release v$newVersion created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host " Note: This is a pre-release version" -ForegroundColor Yellow
    Write-Host "   Users must explicitly opt-in to use it" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To publish to pub.dev:" -ForegroundColor Cyan
    Write-Host "  dart pub publish" -ForegroundColor White
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host " Error: $_" -ForegroundColor Red
    exit 1
}
