# Version Comparison Tool
# Compare local version with published version and suggest next version

$ErrorActionPreference = "Stop"

function Get-LocalVersion {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*(\d+)\.(\d+)\.(\d+)(-([a-zA-Z0-9\.\-]+))?') {
        return @{
            Full       = $matches[0] -replace 'version:\s*', ''
            Major      = [int]$matches[1]
            Minor      = [int]$matches[2]
            Patch      = [int]$matches[3]
            PreRelease = if ($matches[5]) { $matches[5] } else { $null }
        }
    }
    return $null
}

function Get-PublishedVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://pub.dev/api/packages/abidock_mvx" -ErrorAction Stop
        if ($response.latest.version -match '(\d+)\.(\d+)\.(\d+)(-([a-zA-Z0-9\.\-]+))?') {
            return @{
                Full       = $response.latest.version
                Major      = [int]$matches[1]
                Minor      = [int]$matches[2]
                Patch      = [int]$matches[3]
                PreRelease = if ($matches[5]) { $matches[5] } else { $null }
            }
        }
    }
    catch {
        return $null
    }
}

function Compare-Versions {
    param($Local, $Published)
    
    if (-not $Published) {
        return "Not published yet"
    }
    
    if ($Local.Full -eq $Published.Full) {
        return "Same"
    }
    
    if ($Local.Major -gt $Published.Major) {
        return "Major ahead"
    }
    elseif ($Local.Major -lt $Published.Major) {
        return "Behind"
    }
    
    if ($Local.Minor -gt $Published.Minor) {
        return "Minor ahead"
    }
    elseif ($Local.Minor -lt $Published.Minor) {
        return "Behind"
    }
    
    if ($Local.Patch -gt $Published.Patch) {
        return "Patch ahead"
    }
    elseif ($Local.Patch -lt $Published.Patch) {
        return "Behind"
    }
    
    return "Unknown"
}

function Get-SuggestedVersions {
    param($Current)
    
    return @{
        Patch = "$($Current.Major).$($Current.Minor).$($Current.Patch + 1)"
        Minor = "$($Current.Major).$($Current.Minor + 1).0"
        Major = "$($Current.Major + 1).0.0"
    }
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host " VERSION COMPARISON TOOL" -ForegroundColor Cyan
Write-Host ""

$local = Get-LocalVersion
$published = Get-PublishedVersion

if (-not $local) {
    Write-Host " Could not read local version from pubspec.yaml" -ForegroundColor Red
    exit 1
}

Write-Host "Local Version:     " -NoNewline
Write-Host $local.Full -ForegroundColor Yellow

if ($published) {
    Write-Host "Published Version: " -NoNewline
    Write-Host $published.Full -ForegroundColor Green
    
    $comparison = Compare-Versions -Local $local -Published $published
    
    Write-Host "Status:            " -NoNewline
    switch ($comparison) {
        "Same" {
            Write-Host "  Same as published - needs version bump!" -ForegroundColor Yellow
        }
        "Patch ahead" {
            Write-Host " Patch version ahead - ready to publish" -ForegroundColor Green
        }
        "Minor ahead" {
            Write-Host " Minor version ahead - ready to publish" -ForegroundColor Green
        }
        "Major ahead" {
            Write-Host " Major version ahead - ready to publish" -ForegroundColor Green
        }
        "Behind" {
            Write-Host " Local version is behind published!" -ForegroundColor Red
        }
        "Not published yet" {
            Write-Host " Package not published yet" -ForegroundColor Cyan
        }
        default {
            Write-Host $comparison -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "Published Version: " -NoNewline
    Write-Host "Not found (package may not be published yet)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "" -ForegroundColor Gray
Write-Host ""

$suggestions = Get-SuggestedVersions -Current $local

Write-Host "Suggested next versions:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Patch (bug fixes):          " -NoNewline
Write-Host $suggestions.Patch -ForegroundColor Yellow
Write-Host "    Usage: .\scripts\publish.ps1 -VersionType patch -Message 'Fix: ...'"
Write-Host ""
Write-Host "  Minor (new features):       " -NoNewline
Write-Host $suggestions.Minor -ForegroundColor Yellow
Write-Host "    Usage: .\scripts\publish.ps1 -VersionType minor -Message 'Add: ...'"
Write-Host ""
Write-Host "  Major (breaking changes):   " -NoNewline
Write-Host $suggestions.Major -ForegroundColor Yellow
Write-Host "    Usage: .\scripts\publish.ps1 -VersionType major -Message 'Breaking: ...'"
Write-Host ""

# Show all published versions if available
Write-Host "" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "Recent published versions:" -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri "https://pub.dev/api/packages/abidock_mvx"
    $versions = $response.versions | Select-Object -First 10
    foreach ($v in $versions) {
        $date = ([DateTime]$v.published).ToString("yyyy-MM-dd")
        Write-Host "  $($v.version) " -NoNewline -ForegroundColor Green
        Write-Host "($date)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  Unable to fetch version history" -ForegroundColor Gray
}

Write-Host ""
