# 0001. Native SwiftUI app on GRDB with a local Claude Code bridge

**Date**: 2026-11-05
**Status**: Accepted

## Summary

Verba is built as a native Mac app in Swift and SwiftUI (Apple's own language and UI toolkit). Everything it remembers lives in one SQLite database file (a small local database) in your Library folder, read and written through the GRDB library. The app talks to Claude by starting the `claude` command line tool in the background, inside its own empty work folder with every tool turned off. For building, this means one app target plus a local Swift package split into a few modules, a text defined Xcode project (XcodeGen), and an app that is not sandboxed and is signed only to run on your own Mac.

## Decision

**Chosen option**: Option 1: Native SwiftUI + GRDB + XcodeGen.

Build Verba as an unsandboxed, single window SwiftUI app for macOS 26 and later, written in Swift 6 language mode, storing all learner data in a GRDB managed SQLite file under Application Support, and reaching Claude only through the local `claude` CLI launched with swift-subprocess.

**Implementation skills**: `swiftui-pro` (`twostraws/swiftui-agent-skill`, `.claude/skills/swiftui-pro/`) · `swift-concurrency` (`avdlee/swift-concurrency-agent-skill`, `.claude/skills/swift-concurrency/`) · `swift-testing-pro` (`twostraws/swift-testing-agent-skill`, `.claude/skills/swift-testing-pro/`) · `grdb` (`johnrogers/claude-swift-engineering`, `.claude/skills/grdb/`)

## Rationale

Reasoning, options, and the landscape check: see [rationale.md](rationale.md).

## Proposed stack

| Layer | Choice | Reason |
|---|---|---|
| Platform | macOS only, minimum **macOS 26 Tahoe** | Current SwiftUI and `@Observable`, one version behind the newest so a later share is not blocked. |
| Toolchain | **Xcode 27.1**, **Swift 6.4** | Current stable release (Xcode 27 needs macOS Tahoe 26.6+ on Apple silicon to build). |
| Language mode | **Swift 6 language mode**, strict concurrency on every target | The CLI bridge streams on background tasks into the UI, and the compiler should catch data races before you do. |
| UI framework | **SwiftUI**, no AppKit unless a gap forces it | Native look, and built in speech (Slice 8, 9) and print to PDF (Slice 6) need no bridges. |
| App pattern | **`@Observable` feature models + protocol services** | Views read a feature model, the model calls services (store, Claude, speech) passed in from the app; tests swap the services. |
| Window shape | **One main window**: `NavigationSplitView` sidebar (Home, Lessons, Chat, Review, Notebook) + a `Settings` scene | Matches the one course feel and grows one sidebar entry per slice. |
| Modules | **Thin app target + local Swift package `VerbaKit`** (see *Module layout*) | Logic builds and tests with `swift test` without launching the app, and the target boundaries are enforced by the compiler. |
| Project definition | **XcodeGen** (`project.yml`, latest 2.x, 2.46 at the time of writing); the generated `.xcodeproj` is gitignored | The project is a short text file people and agents can edit and diff; no `project.pbxproj` merge pain. |
| Dependencies | **Swift Package Manager** only | Built in; no CocoaPods or Carthage. |
| Primary storage | **GRDB.swift 7** (7.12 at the time of writing) over one SQLite file, `DatabasePool` in WAL mode | Relational data with explicit, versioned migrations, so later slices extend the schema instead of breaking it. |
| Reactive reads | **GRDB `ValueObservation`** feeding `@Observable` models | Screens update when a lesson or score is saved, with no manual refresh code. |
| Data location | `~/Library/Application Support/Verba/` (release) and `.../Verba-Dev/` (debug builds) | The macOS convention, backed up by Time Machine; debug work never touches your real progress. |
| Small UI preferences | **`UserDefaults`**, for window and view conveniences only | Anything about learning (goal, level, records, preferences for teaching) lives in SQLite, so one file holds everything that matters. |
| Claude access | Local **`claude` CLI** in headless mode (`claude -p`, JSON output), subscription login, no API key | Your scope's rule: no server, no key. Prompts, schemas, and flags are owned by spec 4 (Claude Code bridge). |
| Process launching | **swift-subprocess 1.x** (`swiftlang/swift-subprocess`, 1.0.2 at the time of writing) | async/await process API with streamed output and cancellation that fits Swift 6 concurrency. |
| CLI isolation | Every call runs with its working folder set to `<data folder>/claude-work/` (kept empty), with tools and MCP servers turned off | Lessons can never touch your files, and your global hooks and project `CLAUDE.md` do not leak into prompts. Exact flags: spec 4. |
| App Sandbox | **Off** | A sandboxed app cannot run a binary from your PATH or read the CLI's login state; the Mac App Store is already out of scope. |
| Signing | **Sign to Run Locally** (ad hoc), **Hardened Runtime on** | Runs on your Mac with no Apple account or team ID in the repo; notarization waits for public distribution. |
| Bundle ID | `com.verba.app` (release), `com.verba.app.dev` (debug) | The engineer's pick. The debug suffix keeps debug `UserDefaults` and the debug app separate from the real one. |
| Logging | **Apple `os.Logger`**, subsystem = bundle ID, one category per module (`app`, `store`, `bridge`, `ui`) | Zero dependencies; read it in Console.app or `log stream`; private values are redacted by default. |
| Unit tests | **Swift Testing** (`@Test`, `#expect`) in each package test target, run by `swift test` | The current Apple default, with parameterized tests for grading and shuffling rules. |
| UI tests | **XCUITest**, a few end to end flows only, in an `AppUITests` target added at Slice 1 (not by the scaffold) | Beta tier runs `/test`; most behavior is proven at the package level, so the UI suite stays small, and the scaffold has no flow to test yet. |
| Version control | **git**, started at scaffold, with a Swift/Xcode `.gitignore` | Your workflow skills read history and diffs. |
| Hosting, auth, server | **None** | Everything runs on the Mac; the only "login" is your existing Claude Code session. |

### Module layout

```
Verba/
├── project.yml                     # XcodeGen: app target, scheme (AppUITests target added at Slice 1)
├── App/                            # Verba app target (thin)
│   ├── VerbaApp.swift              # @main, WindowGroup + Settings scenes
│   ├── AppEnvironment.swift        # composition root: picks the data folder, builds the real services
│   └── Verba.entitlements          # empty <dict/> (no app-sandbox key); Info.plist is generated by XcodeGen
└── Packages/VerbaKit/
    ├── Package.swift
    ├── Package.resolved            # committed
    ├── Sources/
    │   ├── Core/                   # domain types, teaching rules, service protocols, AppPaths, Log. Foundation only.
    │   ├── Persistence/            # GRDB: AppDatabase, migrations, repositories. Depends on Core, GRDB.
    │   ├── ClaudeBridge/           # the CLI client. Depends on Core, swift-subprocess.
    │   └── Features/               # SwiftUI views + @Observable models, one folder per feature. Depends on Core only.
    └── Tests/
        ├── CoreTests/
        ├── PersistenceTests/
        ├── ClaudeBridgeTests/
        └── FeaturesTests/
```

Dependency rule (the compiler enforces it through `Package.swift`): `Features` imports `Core` only. It never imports `Persistence` or `ClaudeBridge`. Those two implement protocols declared in `Core` (for example a lesson store and a Claude client), and the app target wires the real implementations into the feature models. This keeps every screen testable with fakes and keeps GRDB and the CLI out of view code.

Where the UI kit goes (colors, type, the lesson page, quiz, and chat bubble components) is decided by spec 5 (design system). The default, unless spec 5 says otherwise, is a `DesignSystem` library target that `Features` depends on. The scaffold does not create it.

### Rules the build must honor

- **Concurrency defaults.** The `App` and `Features` targets use main actor default isolation; `Core`, `Persistence`, and `ClaudeBridge` stay nonisolated by default. The upcoming feature `NonisolatedNonsendingByDefault` stays off, so nonisolated `async` service methods run off the main actor (what the bridge wants). Runner up: explicit `@MainActor` on every view model, rejected as noise.
- **Services are protocols in `Core`.** Every service protocol is `Sendable`; its methods are `async`, and live reads return `AsyncStream` of `Sendable` values. Real implementations are built once in `AppEnvironment` and passed into feature models through their initializers or a SwiftUI `@Environment` entry. No singletons, no global database handle.
- **GRDB stays inside `Persistence`.** The bridge from `ValueObservation` to `AsyncStream` lives in `Persistence`; `Features` consumes the stream and never sees a GRDB type.
- **One database, opened once.** `AppDatabase` opens a `DatabasePool` at `<data folder>/verba.sqlite`, runs `DatabaseMigrator` on launch before any screen reads, and is the only writer. Most tests use an in memory `DatabaseQueue` with the same migrator; at least one test opens a real `DatabasePool` in a temporary folder, so WAL behavior is covered. Runner up: a single `DatabaseQueue` everywhere, which is simpler but blocks reads during a long write.
- **Migrations only move forward.** Each schema change is a new, named migration; an applied migration is never edited. The scaffold registers one permanent no op migration, `v0_scaffold`, so the file exists with a migration history; spec 3 appends its migrations after it. No `eraseDatabaseOnSchemaChange`. The schema itself is spec 3.
- **The app target chooses the data folder; packages never check the build type.** `#if DEBUG` does not reliably reach Swift package targets, so `AppEnvironment` (app target, where Xcode's Debug config sets `DEBUG`) picks `Verba-Dev` or `Verba` under Application Support and passes that root into `AppPaths(root:)`. `AppPaths` (in `Core`) exposes pure paths (`database`, `claudeWork`) plus a `prepareFolders()` that `AppEnvironment` calls once at launch to create the root and an empty `claude-work/`. Tests pass a temporary folder and never touch real or dev data.
- **Logging goes through one helper.** `Log` in `Core` makes `os.Logger` instances per category, with subsystem `Bundle.main.bundleIdentifier ?? "com.verba.app"` (so tests also work).
- **The app shuffles quiz options, not Claude.** Shuffling is a `Core` rule with its own tests (from the teaching principles).
- **Claude is reached only through `ClaudeBridge`.** No other module launches a process or builds a prompt.
- **No third party dependency** beyond GRDB and swift-subprocess without a spec or an explicit OK.
- **Build commands** the scaffold must make work: `xcodegen generate`, `xcodebuild -scheme Verba -destination 'platform=macOS' -derivedDataPath build build` (Debug by default, so the app lands at `build/Build/Products/Debug/Verba Dev.app`), and `swift test --package-path Packages/VerbaKit`. Package tests run only through `swift test`; there is no Xcode test plan.
- **Toolchain check first.** The scaffold starts by running `xcodebuild -version` and `swift --version`. If Xcode 27 / Swift 6.2+ is missing, stop and report; never lower the settings below to make an older toolchain build.

### Scaffold settings (exact values)

**`Package.swift`** (`Packages/VerbaKit`):
- `// swift-tools-version: 6.2`, `platforms: [.macOS(.v26)]`, `swiftLanguageModes: [.v6]`.
- Four library products, one per module: `Core`, `Persistence`, `ClaudeBridge`, `Features`.
- Dependencies: `GRDB.swift` `from: "7.12.0"`, `swift-subprocess` `from: "1.0.2"`. `Persistence` depends on `Core` + `GRDB`; `ClaudeBridge` on `Core` + `Subprocess`; `Features` on `Core` only.
- `swiftSettings: [.defaultIsolation(MainActor.self)]` on `Features` only.
- Test targets: `CoreTests`, `PersistenceTests`, `ClaudeBridgeTests`, `FeaturesTests`. Proof tests the scaffold includes: `PersistenceTests` migrates a real `DatabasePool` in a temp folder; `ClaudeBridgeTests` runs `/usr/bin/true` through swift-subprocess and expects exit code 0 (this also settles whether swift-subprocess builds for macOS 26).
- `Package.resolved` is committed.

**`project.yml`** (XcodeGen):
- `name: Verba`; `options.deploymentTarget.macOS: "26.0"`; `options.createIntermediateGroups: true`; configs `Debug` and `Release` only.
- `packages: VerbaKit: { path: Packages/VerbaKit }`.
- Target `Verba`: `type: application`, `platform: macOS`, `sources: [App]`, dependencies on the four package products.
- Settings for both configs: `SWIFT_VERSION: 6.0`, `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`, `CODE_SIGN_IDENTITY: "-"`, `CODE_SIGN_STYLE: Manual`, `DEVELOPMENT_TEAM: ""`, `ENABLE_HARDENED_RUNTIME: YES`, `CODE_SIGN_ENTITLEMENTS: App/Verba.entitlements`, `MARKETING_VERSION: 0.1.0`, `CURRENT_PROJECT_VERSION: 1`.
- Per config: Debug `PRODUCT_BUNDLE_IDENTIFIER: com.verba.app.dev`, `PRODUCT_NAME: Verba Dev`; Release `com.verba.app`, `PRODUCT_NAME: Verba`. Two distinct names keep the two apps apart in the Dock and Launch Services.
- Info.plist generated through the target's `info:` key: `CFBundleDisplayName: $(PRODUCT_NAME)`, `CFBundleShortVersionString: $(MARKETING_VERSION)`, `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`, `LSMinimumSystemVersion: $(MACOSX_DEPLOYMENT_TARGET)`, `LSApplicationCategoryType: public.app-category.education`, `NSPrincipalClass: NSApplication`. No microphone or speech usage strings yet (Slice 9).
- The entitlements file is committed by hand as an empty `<dict/>` plist (not generated by XcodeGen's `entitlements:` key).
- One scheme, `Verba`: run uses Debug, archive uses Release.

**`.gitignore`**: `*.xcodeproj/`, `build/`, `.build/`, `DerivedData/`, `xcuserdata/`, `.swiftpm/`, `.DS_Store`. The generated project's own `Package.resolved` goes with it; the committed one in `Packages/VerbaKit` is the version pin.

### What the scaffold proves (the scope's done line, made checkable)

- The toolchain check passes; `xcodegen generate` then the `xcodebuild` command above succeeds from a clean clone.
- The app launches to an empty main window with the sidebar and an empty Settings window.
- On first launch the data folder (`Verba-Dev/` for a debug build) exists with `verba.sqlite` (with `v0_scaffold` applied) and an empty `claude-work/`.
- `swift test` passes, with at least one Swift Testing test in each package target, including the two proof tests above.
- The built app's signature shows ad hoc signing, Hardened Runtime on, and no App Sandbox (`codesign -dv --entitlements - "build/Build/Products/Debug/Verba Dev.app"`).

The steps to get there are derived by `/develop stack & architecture` from this section.

## Consequences

**Positive**:
- One language and one toolchain for UI, logic, storage, and speech; every later slice (voices, speech recognition, print to PDF) uses built in Apple frameworks.
- The schema can grow over nine slices through ordinary migrations, and the database is one file you can open with any SQLite tool.
- Logic is tested in seconds with `swift test`; UI tests stay few.
- Agents can edit `project.yml` and `Package.swift` safely; the generated project never conflicts.

**Negative / tradeoffs**:
- Mac only. A Windows or Linux version would be a rewrite of the UI layer.
- Unsandboxed means the app could, in principle, touch any of your files. The rule that only `ClaudeBridge` launches processes, and that the CLI runs with tools off in an empty folder, carries that safety instead of the OS.
- Ad hoc signing changes the code signature on every rebuild, so macOS may ask again for permissions like the microphone (Slice 9). Revisit signing (free Personal Team) at that slice.
- Swift 6 strict concurrency produces more compiler errors early on, mostly around the bridge and observation.
- GRDB needs hand written records and SQL migrations; more code than SwiftData would need.
- The app depends on a coding tool's CLI whose flags change between releases (see the premise note in [rationale.md](rationale.md)); spec 4 must pin and check them.
- XcodeGen is one more tool to install (`brew install xcodegen`), and contributors must run `xcodegen generate` after pulling.

**Neutral**:
- `com.verba.app` is permanent once real data lives under it; it does not need a domain you own for local use.
- The `.xcodeproj` is generated, so Xcode UI changes to target settings must be copied back into `project.yml` or they are lost.

## Follow-up

- [ ] Spec 3 (data model): design the schema and its first migration on top of GRDB and the "migrations only move forward" rule.
- [ ] Spec 4 (Claude Code bridge): pin the exact CLI flags for isolation (working folder, tools off, MCP off, JSON output, `--json-schema`), how the app finds `claude` when launched from Finder (a GUI app does not inherit your shell `PATH`), the minimum supported CLI version, and what to do when `--bare` becomes the default for `-p` (bare mode does not read subscription login).
- [ ] Spec 5 (design system): confirm or change the `DesignSystem` target default.
- [x] `/audit` (feature 2) should write root `AGENTS.md` from the real scaffold. Project wide skill conventions not yet in root `AGENTS.md`: `swiftui-pro`, `swift-concurrency`, `swift-testing-pro` belong in root `## Agent skills`; `grdb` belongs in a nested `Packages/VerbaKit/Sources/Persistence/AGENTS.md`.
- [ ] Spec 4 should confirm that an ad hoc signed parent app does not trigger Keychain prompts when `claude` reads its own login (the child runs under its own identity, so this is expected to be fine).
- [ ] Optional, never blocks the scaffold: MCP servers to connect yourself (one time config, then the agent uses them automatically): XcodeBuildMCP (`claude mcp add XcodeBuildMCP npx xcodebuildmcp@latest`), Apple's Xcode MCP bridge (`claude mcp add --transport stdio xcode -- xcrun mcpbridge`, needs Xcode open with the project), and an Apple docs MCP (`apple-docs-mcp`, community). Record them on the `MCP servers:` line of `AGENTS.md` once connected. All three were found through listings and are unconfirmed against their official repos.
- [ ] Revisit signing at Slice 9 (speech practice) if microphone permission prompts reappear after every rebuild.
