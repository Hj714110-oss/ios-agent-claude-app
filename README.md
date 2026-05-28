# AgentIDE-iOS

Open-source iPhone Agent IDE inspired by PythonIDE-iOS.

This repository ships a v1 architecture with:

- Dual build profiles: `StoreProfile` and `OpenProfile`
- SwiftUI app shell with UIKit editor bridge
- Workspace + Git service interfaces
- Chat + PIAN (plan panel) task model
- Agent loop: `Plan -> Execute -> Observe -> Patch -> Verify`
- Local-first runtime with remote fallback
- Declarative skills (`JSON` now, `YAML` ready via adapter point)
- Keychain-backed secrets and permission-gated tools
- Claude-like mobile Studio tab for live design/code/full-app generation artifacts
- M1.5: OpenAI-compatible streaming, artifact contract parsing, and preview-first apply queue
- High-freedom model controls: custom base URL/model/persona/system prompt and advanced sampling params
- M1.6: multi-profile provider registry, global prompt strategy, and full-app subdirectory generation

## Quick Start

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Run:

```bash
xcodegen generate
open AgentIDE.xcodeproj
```

3. Select one configuration:
- `StoreProfile-Debug` / `StoreProfile-Release`
- `OpenProfile-Debug` / `OpenProfile-Release`

4. Run on iPhone simulator (iOS 17+).

## Cloud CI with Codemagic (No macOS required)

This repository uses **Codemagic** for cloud-based iOS builds:

### Setup Steps

1. **Sign up** at [codemagic.io](https://codemagic.io) (free tier available)
2. **Connect your repository** (GitHub/GitLab/Bitbucket)
3. **Codemagic will auto-detect** `codemagic.yaml` configuration
4. **Trigger builds** via:
   - Push to `main`/`master`/`develop` branches
   - Pull requests
   - Manual trigger from Codemagic dashboard

### Configuration Files

- `codemagic.yaml` - Main CI/CD configuration
  - `ios-workflow`: Full build + tests for both profiles
  - `ios-build-only`: Quick build without tests (for feature branches)

### What Gets Built

- ✅ `StoreProfile-Debug` - Curated tools, no remote execution
- ✅ `OpenProfile-Debug` - Full feature set with remote execution
- ✅ Unit tests via `AgentIDEAppTests`
- ✅ Artifacts: `.app` bundles, test results (`.xcresult`), logs

### Why Codemagic?

- **No macOS needed** - Runs on cloud Mac Mini M1 instances
- **Free tier** - 500 build minutes/month for open source
- **Fast** - M1 hardware, cached dependencies
- **iOS-focused** - Better than generic GitHub Actions for mobile

### Migration from GitHub Actions

The old GitHub Actions workflow (`.github/workflows/ios-ci.yml`) has been **replaced** with Codemagic. Benefits:

| Feature | GitHub Actions | Codemagic |
|---------|---------------|-----------|
| macOS runner | `macos-latest` (Intel) | Mac Mini M1 (faster) |
| Free tier | 2000 min/month | 500 min/month (sufficient) |
| iOS tooling | Generic | Specialized (Xcode, simulators, signing) |
| Setup complexity | High (manual Xcode setup) | Low (pre-configured) |

## Build Profiles

- `StoreProfile`
  - Remote execution feature flag disabled by default
  - Only curated tools enabled
- `OpenProfile`
  - Remote execution available
  - Wider tool surface allowed

## Project Layout

- `AgentIDEApp/`
  - `Core/` shared domain, protocols, orchestrator
  - `Features/` Workspace, Editor, Chat, PIAN, Skills, Settings
  - `Infrastructure/` providers, persistence, security
  - `UI/` root navigation, Workspace/Studio/Agent/Settings screens

## Notes

- Local Python execution is scaffolded through `LocalPythonExecutionProvider`.
- CPython XCFramework integration hook is documented in code comments.
- Skills loader currently supports JSON manifests directly; YAML can be added by wiring a parser in `SkillManifestLoader`.
- `StudioScreen` streams artifacts in 3 modes (`Design Sketch`, `Code Generation`, `Full App`) and renders:
  - live token stream
  - parsed artifact cards from block protocol
  - apply queue (manual apply/skip, apply all, rollback last)
- OpenAI-compatible settings are persisted (base URL, model, temperature, max tokens) and API key is stored in Keychain.
- Advanced controls include `top_p`, `presence_penalty`, `frequency_penalty`, persona name, and custom system prompt.
- Connection test is available from Settings.
- Multiple provider profiles are supported (create/duplicate/delete/switch/import/export JSON). API keys are stored per profile key reference.
- Full App mode supports one-click bundle write to `workspace/GeneratedApps/<appName>/` using the same path-safe write layer.
- Global prompt strategy is unified: if `customSystemPrompt` is non-empty it overrides default system text; otherwise persona-based default is used.

## License

MIT
