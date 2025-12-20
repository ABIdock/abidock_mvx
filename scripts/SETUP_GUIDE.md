# 🚀 Complete Publishing Setup Guide

## ✅ What's Been Created

You now have **5 enterprise-level publishing scripts** in the `scripts/` directory:

1. **`publish.ps1`** - Full release workflow (patch/minor/major)
2. **`quick-publish.ps1`** - Fast patch releases
3. **`pre-release.ps1`** - Alpha/Beta/RC versions
4. **`rollback.ps1`** - Emergency rollback tool
5. **`status.ps1`** - Release status checker
6. **`version-check.ps1`** - Version comparison tool

---

## 🎯 Quick Start

### First Time Setup

```powershell
# 1. Initialize git repository (if not already done)
git init
git add .
git commit -m "Initial commit"

# 2. Add remote repository
git remote add origin https://github.com/ABIdock/abidock_mvx.git
git branch -M main
git push -u origin main

# 3. Verify scripts are excluded from git
git status
# scripts/ should NOT appear (it's in .gitignore)
```

### Your First Release

```powershell
# Check current status
.\scripts\status.ps1

# Compare versions
.\scripts\version-check.ps1

# Publish a patch version
.\scripts\publish.ps1 -VersionType patch -Message "Initial release"

# Or for quick publish
.\scripts\quick-publish.ps1 -Message "Initial release"
```

---

## 📖 Script Usage Guide

### 1. `status.ps1` - Check Everything

**When to use:** Before publishing, debugging, or checking package health

```powershell
.\scripts\status.ps1
```

**Shows:**
- ✅ Version info (local, git tag, pub.dev)
- ✅ Git status and branch
- ✅ Package health checks
- ✅ Test & analysis results
- ✅ Pub validation status
- ✅ Publishing recommendations

---

### 2. `version-check.ps1` - Compare Versions

**When to use:** To see what version to publish next

```powershell
.\scripts\version-check.ps1
```

**Shows:**
- Current local vs published version
- Suggested next versions (patch/minor/major)
- Recent version history from pub.dev
- Ready-to-use publish commands

---

### 3. `publish.ps1` - Full Release (MAIN SCRIPT)

**When to use:** Standard releases with full validation

```powershell
# Patch release (2.0.0 → 2.0.1)
.\scripts\publish.ps1 -VersionType patch -Message "Fix wallet bug"

# Minor release (2.0.1 → 2.1.0)
.\scripts\publish.ps1 -VersionType minor -Message "Add new features"

# Major release (2.1.0 → 3.0.0)
.\scripts\publish.ps1 -VersionType major -Message "Breaking changes"

# Test without changes (DRY RUN)
.\scripts\publish.ps1 -VersionType patch -Message "Test" -DryRun

# Skip tests (emergency only!)
.\scripts\publish.ps1 -VersionType patch -Message "Hotfix" -SkipTests
```

**Complete workflow:**
1. ✅ Prerequisites check
2. ✅ Git status validation
3. ✅ Run all tests
4. ✅ Static analysis
5. ✅ Code formatting
6. ✅ Update `pubspec.yaml`
7. ✅ Update `CHANGELOG.md`
8. ✅ Publish dry-run
9. ✅ Git commit
10. ✅ Create tag
11. ✅ Push to remote
12. ✅ Publish to pub.dev (with confirmation)

---

### 4. `quick-publish.ps1` - Fast Patch Release

**When to use:** Hotfixes, small bug fixes, quick iterations

```powershell
.\scripts\quick-publish.ps1 -Message "Fix critical bug"
```

**What it does:**
- Auto-increments patch version
- Quick validation
- Updates files
- Commits, tags, pushes
- GitHub Actions publishes automatically

**Perfect for:**
- 🐛 Bug fixes
- 📝 Documentation updates
- 🔧 Minor tweaks

---

### 5. `pre-release.ps1` - Test Versions

**When to use:** Testing before major releases

```powershell
# Alpha (early testing)
.\scripts\pre-release.ps1 -Type alpha -Message "Testing new features"

# Beta (wider testing)
.\scripts\pre-release.ps1 -Type beta -Message "Ready for beta"

# Beta with identifier
.\scripts\pre-release.ps1 -Type beta -Identifier "feature-xyz" -Message "Testing XYZ"

# Release Candidate (final testing)
.\scripts\pre-release.ps1 -Type rc -Message "Release candidate for v3.0.0"
```

**Version format:**
- `2.0.0-alpha.1`, `2.0.0-alpha.2`, ...
- `2.0.0-beta.1`, `2.0.0-beta.2+feature-xyz`, ...
- `2.0.0-rc.1`, `2.0.0-rc.2`, ...

**Note:** Pre-releases DON'T auto-publish. You must manually run:
```powershell
dart pub publish
```

---

### 6. `rollback.ps1` - Emergency Undo

**When to use:** Wrong tag pushed, need to undo Git operations

```powershell
# Interactive (asks confirmation)
.\scripts\rollback.ps1

# Force rollback
.\scripts\rollback.ps1 -Force
```

**⚠️ CRITICAL WARNING:**
- Only rolls back Git operations (tag, commits)
- **CANNOT** unpublish from pub.dev
- pub.dev versions are **PERMANENT**
- Use ONLY before publishing to pub.dev
- Destructive operation (force push)

---

## 🎬 Example Workflows

### Scenario 1: Standard Feature Release

```powershell
# 1. Check current status
.\scripts\status.ps1

# 2. Make your changes
# ... edit code ...

# 3. Test locally
dart test

# 4. Commit changes
git add .
git commit -m "feat: add new wallet feature"

# 5. Check versions
.\scripts\version-check.ps1

# 6. Publish minor version
.\scripts\publish.ps1 -VersionType minor -Message "Add new wallet feature"

# 7. Monitor
# https://github.com/ABIdock/abidock_mvx/actions
# https://pub.dev/packages/abidock_mvx
```

---

### Scenario 2: Hotfix Release

```powershell
# 1. Fix the bug
# ... edit code ...

# 2. Commit fix
git add .
git commit -m "fix: critical wallet bug"

# 3. Quick publish
.\scripts\quick-publish.ps1 -Message "Fix critical wallet bug"

# Done! GitHub Actions handles publishing
```

---

### Scenario 3: Major Version with Testing

```powershell
# 1. Make breaking changes
# ... edit code ...

# 2. Create alpha version
.\scripts\pre-release.ps1 -Type alpha -Message "Testing v3.0.0 changes"

# 3. Test alpha
dart pub get
dart test

# 4. If good, create beta
.\scripts\pre-release.ps1 -Type beta -Message "v3.0.0 beta ready"

# 5. More testing...

# 6. Create RC
.\scripts\pre-release.ps1 -Type rc -Message "v3.0.0 release candidate"

# 7. Final testing...

# 8. Release final version
.\scripts\publish.ps1 -VersionType major -Message "v3.0.0 with breaking changes"
```

---

### Scenario 4: Emergency Rollback

```powershell
# Oops! Tagged wrong version

# Check what happened
git log --oneline -5
git tag

# Rollback (Git only)
.\scripts\rollback.ps1

# If already published to pub.dev:
# - Cannot undo
# - Must publish new version with fix
.\scripts\quick-publish.ps1 -Message "Fix incorrect release"
```

---

## 📋 Pre-Publish Checklist

Run this before every publish:

```powershell
# 1. Status check
.\scripts\status.ps1

# Should show:
# ✅ Versions in sync (or ahead)
# ✅ Git working directory clean
# ✅ On main/master branch
# ✅ Tests passing
# ✅ Analysis clean
# ✅ Pub check ready

# 2. Version check
.\scripts\version-check.ps1

# Should show version ahead of published

# 3. Manual checks
dart test              # All pass?
dart analyze           # No errors?
dart format .          # All formatted?
git status             # Clean?
```

---

## 🔧 Troubleshooting

### "Working directory is not clean"
```powershell
git status              # See what's uncommitted
git add .
git commit -m "..."     # Commit changes
# OR
git stash              # Stash for later
```

### "Tests failed"
```powershell
dart test              # See failures
# Fix tests, then retry
```

### "Not on main branch"
```powershell
git checkout main
git pull origin main
```

### "Version already exists on pub.dev"
```powershell
# Check versions
.\scripts\version-check.ps1

# Update version manually in pubspec.yaml
# Then retry publish
```

### "Tag already exists"
```powershell
# Delete local tag
git tag -d v2.0.1

# Delete remote tag
git push origin --delete v2.0.1

# Now retry
```

### Scripts not running
```powershell
# Enable script execution (Windows)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass
powershell -ExecutionPolicy Bypass -File .\scripts\publish.ps1 -VersionType patch -Message "Test"
```

---

## 🔐 Security & Privacy

### Scripts are LOCAL ONLY

The `scripts/` directory is in `.gitignore`:

```powershell
# Verify scripts are ignored
git status
# scripts/ should NOT appear

# If it appears, check .gitignore:
cat .gitignore | Select-String "scripts"
# Should show: scripts/
```

### Why keep them local?
- 🔒 Personal workflow preferences
- 🔒 Custom configurations
- 🔒 No accidental publication
- 🔒 Team members can have their own variants

### Sharing with team
If you want to share with your team:

```powershell
# Create a template directory
mkdir scripts-template
Copy-Item scripts\* scripts-template\
git add scripts-template/
git commit -m "Add publishing scripts template"
```

---

## 📚 Additional Commands

### Check published package info
```powershell
# Package page
Start-Process "https://pub.dev/packages/abidock_mvx"

# Score
Start-Process "https://pub.dev/packages/abidock_mvx/score"

# API
Invoke-RestMethod "https://pub.dev/api/packages/abidock_mvx" | ConvertTo-Json
```

### Monitor GitHub Actions
```powershell
# Actions page
Start-Process "https://github.com/ABIdock/abidock_mvx/actions"

# Latest workflow run (via gh CLI if installed)
gh run list --limit 1
gh run view
```

### Local testing
```powershell
# Full test suite
dart test

# Specific test
dart test test/wallet/wallet_test.dart

# With coverage
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

---

## 🎓 Best Practices

### Semantic Versioning

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
  - Changed API
  - Removed features
  - Incompatible changes

- **MINOR** (1.0.0 → 1.1.0): New features
  - Added functionality
  - Backwards compatible
  - No breaking changes

- **PATCH** (1.0.0 → 1.0.1): Bug fixes
  - Bug fixes
  - Security patches
  - No new features

### Changelog Messages

**Good examples:**
- ✅ "Fix null pointer exception in wallet creation"
- ✅ "Add support for multi-sig transactions"
- ✅ "Remove deprecated signTransaction method"

**Bad examples:**
- ❌ "Fix bug"
- ❌ "Update code"
- ❌ "Changes"

### Testing Strategy

1. **Alpha**: Internal testing only
2. **Beta**: Wider testing, stable-ish
3. **RC**: Final testing, production-ready
4. **Release**: Fully tested and stable

---

## 🚀 Advanced Usage

### Automated Publishing via GitHub Actions

Your `.github/workflows/publish.yml` automatically publishes on tags:

```powershell
# This triggers automatic publishing:
.\scripts\quick-publish.ps1 -Message "Auto-publish release"

# Monitor at:
# https://github.com/ABIdock/abidock_mvx/actions
```

### Batch Operations

```powershell
# Check status, then publish if ready
.\scripts\status.ps1
if ($?) {
    .\scripts\publish.ps1 -VersionType patch -Message "Batch release"
}

# Multiple pre-releases
@('alpha', 'beta', 'rc') | ForEach-Object {
    .\scripts\pre-release.ps1 -Type $_ -Message "Testing $_"
    # ... test ...
}
```

### Custom Version Bumping

```powershell
# Edit pubspec.yaml manually
code pubspec.yaml

# Then commit and tag manually
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: release v2.5.7"
git tag -a "v2.5.7" -m "Release v2.5.7"
git push origin main
git push origin v2.5.7

# Publish
dart pub publish
```

---

## 📞 Support & Resources

- 📖 [Dart Publishing Guide](https://dart.dev/tools/pub/publishing)
- 📖 [Semantic Versioning](https://semver.org/)
- 📖 [GitHub Actions Docs](https://docs.github.com/en/actions)
- 📦 [pub.dev](https://pub.dev)
- 🔧 [Git Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)

---

## 🎉 You're All Set!

Your publishing workflow is now **enterprise-grade** and ready to go!

**Quick reference:**
```powershell
.\scripts\status.ps1                           # Check status
.\scripts\version-check.ps1                    # Compare versions
.\scripts\publish.ps1 -VersionType patch -M "..." # Full release
.\scripts\quick-publish.ps1 -Message "..."     # Quick release
.\scripts\pre-release.ps1 -Type alpha -M "..." # Pre-release
.\scripts\rollback.ps1                         # Emergency rollback
```

**Happy Publishing! 🚀**
