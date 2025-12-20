# Abidock MVX Publishing Scripts

This directory contains enterprise-level publishing scripts for managing releases across private and public repositories.

## 🔧 Repository Setup

The project uses two Git remotes:
- **`private`** - `github.com/ReneDuris/abidock_mvx` (internal testing)
- **`public`** - `github.com/ABIdock/abidock_mvx` (public releases)

## 📜 Available Scripts

### Private Repository Scripts

#### `push-private.ps1` - Push to Private Repository
Push changes to the private repository for internal testing.

```powershell
.\scripts\push-private.ps1 -Message "Add new feature for testing"
```

#### `pre-release.ps1` - Alpha/Beta/RC Versions
Create pre-release versions on the private repository.

```powershell
.\scripts\pre-release.ps1 -Type alpha -Message "Testing new features"
.\scripts\pre-release.ps1 -Type beta -Identifier "feature-xyz" -Message "Testing XYZ"
.\scripts\pre-release.ps1 -Type rc -Message "Final testing before v3.0.0"
```

---

### Public Repository Scripts

#### `sync-to-public.ps1` - Sync Private to Public
Sync all changes from private to public repository after testing.

```powershell
.\scripts\sync-to-public.ps1
.\scripts\sync-to-public.ps1 -Force  # Skip confirmation
```

#### `release-public.ps1` - Full Public Release
Create a public release with version bump and pub.dev publishing.

```powershell
.\scripts\release-public.ps1 -VersionType patch -Message "Bug fixes"
.\scripts\release-public.ps1 -VersionType minor -Message "New features"
.\scripts\release-public.ps1 -VersionType major -Message "Breaking changes"
.\scripts\release-public.ps1 -VersionType patch -DryRun  # Test without changes
```

---

### Full Publishing Scripts (Both Repositories)

### 1. `publish.ps1` - Full Release (Main Script)

Complete enterprise-level publishing workflow with all checks and balances.

**Usage:**
```powershell
# Patch release (2.0.0 → 2.0.1)
.\scripts\publish.ps1 -VersionType patch -Message "Fix wallet generation bug"

# Minor release (2.0.1 → 2.1.0)
.\scripts\publish.ps1 -VersionType minor -Message "Add new API endpoints"

# Major release (2.1.0 → 3.0.0)
.\scripts\publish.ps1 -VersionType major -Message "Breaking changes in wallet API"

# Dry run (test without making changes)
.\scripts\publish.ps1 -VersionType patch -Message "Test" -DryRun

# Skip tests (not recommended)
.\scripts\publish.ps1 -VersionType patch -Message "Hotfix" -SkipTests
```

**What it does:**
1. ✅ Checks prerequisites (Git, Dart, clean working directory)
2. ✅ Verifies you're on main branch
3. ✅ Runs all tests
4. ✅ Runs static analysis
5. ✅ Formats code
6. ✅ Updates version in `pubspec.yaml`
7. ✅ Updates `CHANGELOG.md`
8. ✅ Runs `dart pub publish --dry-run`
9. ✅ Commits changes with proper message
10. ✅ Creates Git tag
11. ✅ Pushes to remote repository
12. ✅ Publishes to pub.dev (with confirmation)
13. ✅ Shows comprehensive summary

---

### 2. `quick-publish.ps1` - Quick Patch Release

Simplified script for rapid patch releases. Uses GitHub Actions for automated publishing.

**Usage:**
```powershell
.\scripts\quick-publish.ps1 -Message "Fix bug in transaction signing"
```

**What it does:**
1. ✅ Auto-increments patch version
2. ✅ Runs quick validation
3. ✅ Updates `pubspec.yaml` and `CHANGELOG.md`
4. ✅ Commits, tags, and pushes
5. ✅ GitHub Actions handles the publishing

**Perfect for:** Hotfixes, small bug fixes, documentation updates

---

### 3. `pre-release.ps1` - Alpha/Beta/RC Versions

Create pre-release versions for testing.

**Usage:**
```powershell
# Alpha release
.\scripts\pre-release.ps1 -Type alpha -Message "Testing new features"

# Beta release with identifier
.\scripts\pre-release.ps1 -Type beta -Identifier "feature-xyz" -Message "Testing XYZ feature"

# Release candidate
.\scripts\pre-release.ps1 -Type rc -Message "Final testing before v3.0.0"
```

**Version format:**
- Alpha: `2.0.1-alpha.1`, `2.0.1-alpha.2`, etc.
- Beta: `2.0.1-beta.1+feature-xyz`
- RC: `2.0.1-rc.1`

**What it does:**
1. ✅ Creates pre-release version
2. ✅ Runs tests
3. ✅ Updates version and changelog
4. ✅ Commits and tags
5. ✅ Pushes to remote
6. ⚠️ Does NOT auto-publish (manual `dart pub publish` required)

---

### 4. `rollback.ps1` - Undo Last Release

Emergency rollback of the last Git release (tag and commits).

**Usage:**
```powershell
# Interactive (asks for confirmation)
.\scripts\rollback.ps1

# Force rollback (no confirmation)
.\scripts\rollback.ps1 -Force
```

**⚠️ IMPORTANT:**
- Only rolls back Git operations (tag, commits)
- **CANNOT** unpublish from pub.dev (pub.dev versions are permanent)
- Use only for Git mistakes before publishing
- Destructive operation (force push to remote)

**What it does:**
1. ⚠️ Deletes latest tag (local + remote)
2. ⚠️ Resets branch to previous commit
3. ⚠️ Force pushes to remote

---

## 🎯 Recommended Workflows

### Standard Release Flow
```powershell
# 1. Ensure working directory is clean
git status

# 2. Run full publish script
.\scripts\publish.ps1 -VersionType patch -Message "Your change description"

# 3. Monitor GitHub Actions
# https://github.com/ABIdock/abidock_mvx/actions

# 4. Verify on pub.dev
# https://pub.dev/packages/abidock_mvx
```

### Hotfix Flow
```powershell
# 1. Fix the bug
# 2. Commit your changes
git add .
git commit -m "fix: critical bug in wallet"

# 3. Quick publish
.\scripts\quick-publish.ps1 -Message "Fix critical bug in wallet"
```

### Pre-release Testing Flow
```powershell
# 1. Create alpha version
.\scripts\pre-release.ps1 -Type alpha -Message "Testing new feature"

# 2. Test the alpha version
dart pub get

# 3. If good, create beta
.\scripts\pre-release.ps1 -Type beta -Message "Feature ready for beta testing"

# 4. If beta is stable, create RC
.\scripts\pre-release.ps1 -Type rc -Message "Release candidate for v3.0.0"

# 5. Finally, do full release
.\scripts\publish.ps1 -VersionType minor -Message "New feature release"
```

---

## 📋 Pre-flight Checklist

Before running any publish script:

- [ ] All tests pass: `dart test`
- [ ] No analysis errors: `dart analyze`
- [ ] Code is formatted: `dart format .`
- [ ] Working directory is clean: `git status`
- [ ] On main/master branch: `git branch --show-current`
- [ ] Changes are committed
- [ ] CHANGELOG.md is updated (or let script do it)
- [ ] Documentation is updated if needed

---

## 🔒 Security Notes

**These scripts are NOT in `.gitignore` by design!**

You need to add them manually:

```powershell
# Add to .gitignore
Add-Content .gitignore "`nscripts/"
git add .gitignore
git commit -m "chore: ignore local publishing scripts"
```

**Why keep them local?**
- Contains your personal workflow preferences
- May contain custom configurations
- Prevents accidental publication of internal processes
- Allows team members to have their own variants

---

## 🚨 Troubleshooting

### "Working directory is not clean"
```powershell
# Check what's uncommitted
git status

# Either commit changes or stash them
git add .
git commit -m "your message"
# OR
git stash
```

### "Tests failed"
```powershell
# Run tests manually to see errors
dart test

# Fix the errors, then retry
```

### "Not on main branch"
```powershell
# Switch to main
git checkout main

# Pull latest changes
git pull
```

### "Tag already exists"
```powershell
# Delete local tag
git tag -d v2.0.1

# Delete remote tag
git push origin --delete v2.0.1
```

### Publishing to pub.dev fails
```powershell
# Ensure you're authenticated
dart pub login

# Verify package credentials
dart pub publish --dry-run
```

---

## 📚 Additional Resources

- [Dart pub.dev Publishing Guide](https://dart.dev/tools/pub/publishing)
- [Semantic Versioning](https://semver.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Git Tagging Best Practices](https://git-scm.com/book/en/v2/Git-Basics-Tagging)

---

## 💡 Tips

1. **Always use semantic versioning:**
   - MAJOR: Breaking changes
   - MINOR: New features (backwards compatible)
   - PATCH: Bug fixes

2. **Write meaningful changelog messages:**
   - Good: "Fix null pointer exception in wallet creation"
   - Bad: "Fix bug"

3. **Test pre-releases before major versions:**
   - 2.0.0 → 3.0.0-alpha.1 → 3.0.0-beta.1 → 3.0.0-rc.1 → 3.0.0

4. **Use dry-run for first-time releases:**
   ```powershell
   .\scripts\publish.ps1 -VersionType patch -Message "Test" -DryRun
   ```

5. **Monitor GitHub Actions after publishing:**
   - Watch for CI failures
   - Verify automatic pub.dev publishing
   - Check for any warnings

---

**Happy Publishing! 🚀**
