# DesignSystem

## Overview

Verba's look in one domain free library: color, type, spacing, shape and motion tokens, the base lesson components (lesson page, Markdown explanation, the five exercise inputs, the feedback panel, buttons, labels), Verba's own text size, the light print path, and the debug Design Gallery. `Features` builds screens from it; it knows nothing about lessons as data. The decision is [spec 0004](../../../../docs/specs/0004-design-system/index.md); the human readable record is the root [design.md](../../../../design.md).

## Key files

| Path | Owns |
|---|---|
| `Tokens/` | `Palette` (standard, Increase Contrast, print) of `RGB` hex values, `ColorToken`, `Contrast`, `ThemeFont`, `TextSize` (ten steps and their scale) |
| `Theme/` | `Theme` colors as `ThemeColor` styles, spacing, shape, motion, reading width, `.themeFont(_:)`, `.verbaContentFont()`, the `\.textSize` environment entry |
| `Window/` | `Appearance.applyDark()` and `.verbaWindowStyle()` (dark scheme, sage tint, text size from `verba.textSize`) |
| `Commands/` | `TextSizeCommands` (⌘+ or ⌘=, ⌘− ⌘0), `PrintCommands` (⌘P), `DebugCommands` (⌥⌘D) |
| `Components/` | `TerminalLabel`, button styles, `BlinkingCursor`, `.focusBorder(_:)`, `.verbaBox(fill:border:)` (the shared rounded fill and border) |
| `Lesson/`, `Markdown/` | `ReadingColumn`, `LessonHeader`, `MarkdownDocument` (parse to blocks), `MarkdownText` |
| `Exercise/` | `ExerciseCard`, `ExerciseAction`, `ChoiceList`, `AnswerField`, `ReorderBoard`, `MatchBoard`, `MatchPair`, `.locked(_:)`, the focus request helpers |
| `Feedback/` | `FeedbackTone`, `FeedbackState`, `FeedbackPanel` |
| `Print/` | `LessonPrintDocument`, `PrintedExercise`, `LessonPrinter` (AppKit), the `lessonPrintAction` focused value |
| `Gallery/` | `DesignGalleryView`, its sections, and `SampleLesson` |

## Conventions

- Imports SwiftUI, Foundation, AppKit, and `os` (logging) only; AppKit only for the print path and `Appearance`. The SwiftLint rule `design_system_is_domain_free` fails on any `Core`, `Persistence`, `ClaudeBridge`, `GRDB`, or `Subprocess` import.
- Components take plain values, bindings, and closures; the caller owns all state. `Features` maps domain values first (`Grade` to `FeedbackTone`, shuffled parts to strings, a typed error to its message).
- Never reorder options, tokens, or match items; show them in the order passed (the app shuffles in `Core`).
- No literal colors, font sizes, or radii: use `Theme`. Every font goes through `.themeFont(_:)`, or sits under `.verbaContentFont()`, so text size reaches it. A bare `.font(.body)` in a content area is a bug.
- Every focusable component draws `.focusBorder(_:)` (sage, 2 pt) instead of the system ring, and reads as a labelled element for VoiceOver.
- Lock inputs with `isLocked` (no clicks, out of the focus order), never `.disabled`, which dims below AA.
- Main actor by default (the target setting). Value types used by tests or the print builder are `nonisolated` and `Sendable`.
- Packages never check the build type: the app decides whether `DebugCommands` exists.
- A color change goes through `ContrastTests`; a palette hex change must also land in `design.md` (`DesignDocTests` compares them).

## Gotchas

- macOS SwiftUI ignores `.dynamicTypeSize` and `@ScaledMetric`; Verba scales with `Font.scaled(by:)` from `TextSize.scale`.
- `ExerciseCard` raises a focus request in the environment; each input focuses itself on it. The gallery turns this off (`exerciseIsLive`) for its static state grid, which also drops the cards' Return and Esc shortcuts.
- Return can run a button action captured on an earlier render (seen with `.keyboardShortcut(.defaultAction)` on macOS), so an action must read changing values from state (an `@Observable` model, `@State`, or a binding), never from a plain `let` it captured. The gallery's failure toggle broke this way.
- For typed answers the field submits Check; the card's button only takes Return once it says Next, so Return never fires twice.
- `FeedbackPanel` keeps a stable container while hidden so the change into a result is seen and announced once. `ExerciseCard` gives each `position` its own panel (`.id(position)`), so equal grades on two exercises in a row are both announced.

_Drafted by /sync from the introducing change, worth a quick human pass._
