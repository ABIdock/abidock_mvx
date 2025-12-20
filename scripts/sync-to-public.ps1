# Sync Private to Public Repository
# Usage: .\scripts\sync-to-public.ps1
# This syncs the private repo to the public repo (ABIdock/abidock_mvx)

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "🌐 SYNC TO PUBLIC REPOSITORY" -ForegroundColor Cyan
Write-Host "   From: github.com/ReneDuris/abidock_mvx (private)" -ForegroundColor DarkGray
Write-Host "   To:   github.com/ABIdock/abidock_mvx (public)" -ForegroundColor DarkGray
Write-Host ""

try {
    # Check for uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Host "❌ Working directory is not clean!" -ForegroundColor Red
        Write-Host "   Please commit or stash changes first." -ForegroundColor Yellow
        Write-Host ""
        git status --short
        exit 1
    }

    # Ensure we're on main branch
    $branch = git branch --show-current
    if ($branch -ne "main") {
        Write-Host "❌ Not on main branch (current: $branch)" -ForegroundColor Red
        Write-Host "   Please switch to main branch first." -ForegroundColor Yellow
        exit 1
    }

    # Run full test suite
    Write-Host "→ Running full test suite..." -ForegroundColor Cyan
    dart test 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Tests failed! Cannot sync to public." -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ Tests passed" -ForegroundColor Green

    # Run analysis
    Write-Host "→ Running analysis..." -ForegroundColor Cyan
    $analysisResult = dart analyze 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($analysisResult -match 'error') {
            Write-Host "❌ Analysis errors found! Cannot sync to public." -ForegroundColor Red
            Write-Host $analysisResult
            exit 1
        }
        Write-Host "  ⚠️  Warnings found (continuing)" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ✓ Analysis passed" -ForegroundColor Green
    }

    # Confirmation
    if (-not $Force) {
        Write-Host ""
        Write-Host "⚠️  This will push all commits to the PUBLIC repository!" -ForegroundColor Yellow
        Write-Host "   Everyone will be able to see these changes." -ForegroundColor DarkGray
        Write-Host ""
        $confirm = Read-Host "Continue? (y/n)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "Cancelled." -ForegroundColor Gray
            exit 0
        }
    }

    # Push to public
    Write-Host ""
    Write-Host "→ Pushing to public repository..." -ForegroundColor Cyan
    git push public main

    # Push tags
    Write-Host "→ Pushing tags..." -ForegroundColor Cyan
    git push public --tags

    Write-Host ""
    Write-Host "✅ Successfully synced to public repository!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Public repo: https://github.com/ABIdock/abidock_mvx" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
