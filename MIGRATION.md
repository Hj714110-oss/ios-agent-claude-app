# Migration Guide: GitHub Actions → Codemagic

## Why Migrate?

The original GitHub Actions workflow required macOS runners, which are:
- Slower (Intel-based `macos-latest`)
- Generic (not optimized for iOS)
- Limited free tier for private repos

Codemagic provides:
- ✅ **Faster builds** - Mac Mini M1 instances
- ✅ **iOS-specialized** - Pre-configured Xcode, simulators, signing
- ✅ **No local macOS needed** - Fully cloud-based
- ✅ **500 free minutes/month** for open source

## What Changed?

### Removed Files
- `.github/workflows/ios-ci.yml` (GitHub Actions workflow)
- `scripts/ci_ios.sh` (bash script for xcodebuild)

### Added Files
- `codemagic.yaml` (Codemagic configuration)

### Updated Files
- `README.md` (new CI setup instructions)

## Setup Instructions

### 1. Sign Up for Codemagic
1. Go to [codemagic.io](https://codemagic.io)
2. Sign up with GitHub/GitLab/Bitbucket
3. Free tier: 500 build minutes/month

### 2. Connect Repository
1. Click **"Add application"**
2. Select your Git provider
3. Choose `Hj714110-oss/ios-agent-claude-app`
4. Codemagic auto-detects `codemagic.yaml`

### 3. Configure (Optional)
- **Environment variables**: Set in Codemagic UI under "Environment variables"
- **Email notifications**: Update `codemagic.yaml` → `publishing.email.recipients`
- **Signing**: For App Store builds, add certificates in Codemagic UI

### 4. Trigger Builds
Builds trigger automatically on:
- Push to `main`, `master`, `develop`
- Pull requests
- Manual trigger from Codemagic dashboard

## Workflow Comparison

### GitHub Actions (Old)
```yaml
# .github/workflows/ios-ci.yml
runs-on: macos-latest
- brew install xcodegen
- xcodegen generate
- xcodebuild -project ... -scheme ... test
```

### Codemagic (New)
```yaml
# codemagic.yaml
instance_type: mac_mini_m1
scripts:
  - brew install xcodegen
  - xcodegen generate
  - xcodebuild -project ... -scheme ... test
```

## Features

### Two Workflows

#### 1. `ios-workflow` (Full Build + Tests)
- Triggers: Push to `main`/`master`/`develop`, PRs
- Builds: `StoreProfile-Debug` + `OpenProfile-Debug`
- Tests: Runs `AgentIDEAppTests`
- Artifacts: `.app` bundles, `.xcresult`, logs

#### 2. `ios-build-only` (Quick Build)
- Triggers: Push to `feature/*` branches
- Builds: `StoreProfile-Debug` only
- Tests: Skipped (faster feedback)
- Artifacts: `.app` bundle

## Troubleshooting

### Build Fails: "No such file or directory"
- **Cause**: XcodeGen not generating project
- **Fix**: Check `project.yml` syntax

### Build Fails: "Code signing required"
- **Cause**: Simulator builds shouldn't need signing
- **Fix**: Already handled with `CODE_SIGNING_REQUIRED=NO` in `codemagic.yaml`

### Tests Fail: "Simulator not found"
- **Cause**: iOS version mismatch
- **Fix**: Update `destination` in `codemagic.yaml` to match available simulators

### Want to Keep GitHub Actions?
If you prefer GitHub Actions, you can:
1. Keep both configurations (Codemagic + GitHub Actions)
2. Use GitHub Actions for simple checks, Codemagic for full builds
3. Restore `.github/workflows/ios-ci.yml` from git history

## Cost Comparison

| Provider | Free Tier | Runner Type | Speed |
|----------|-----------|-------------|-------|
| GitHub Actions | 2000 min/month | Intel Mac | Slower |
| Codemagic | 500 min/month | M1 Mac | Faster |

**Typical build time**: 10-15 minutes
- GitHub Actions: ~133 builds/month
- Codemagic: ~33 builds/month (sufficient for most projects)

## Next Steps

1. ✅ Commit `codemagic.yaml` to repository
2. ✅ Update `README.md` with new instructions
3. ✅ Remove old GitHub Actions files (optional)
4. 🔄 Connect repository to Codemagic
5. 🚀 Trigger first build

## Support

- Codemagic Docs: https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/
- Codemagic Slack: https://codemagicio.slack.com
- GitHub Issues: Report problems in this repository
