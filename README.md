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

## Cloud CI (No local macOS required)

This repository includes GitHub Actions workflow:

- `.github/workflows/ios-ci.yml`
- `scripts/ci_ios.sh`

It runs on `macos-latest` and supports:

- `xcodegen generate`
- Build `StoreProfile-Debug` and `OpenProfile-Debug`
- Run `AgentIDEAppTests` on `iPhone 15 / iOS 17.0`
- Upload build logs and `.xcresult` bundles as artifacts

Manual trigger options (`workflow_dispatch`):

- `profile`: `all` / `store` / `open`
- `run_tests`: `true` / `false`

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
