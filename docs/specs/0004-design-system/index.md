# 0004. Dark terminal design system in a DesignSystem target, with serif reading text and a light print style

**Date**: 2026-11-17
**Status**: In Progress

## Summary

Verba gets one shared look: a dark only, terminal style interface (near black panes, sharp thin borders, a muted sage green accent, small monospaced labels) where lesson text is set in Apple's built in serif so long explanations stay easy to read. All colors, type, spacing, and the base lesson components (lesson page, all five exercise kinds, instant feedback, the "checking" wait) live in a new `DesignSystem` library target that knows nothing about the domain, so feature screens only pass plain values in. Lessons print and save as PDF in a separate light, ink friendly style, and a debug only Design Gallery window shows every part so it can be checked before Slice 1 uses it. A root `design.md` records every value for people to read.

## Requirements

**User stories**:
- As a learner, I want every screen to look and behave like one calm course, so the app gets out of the way of learning.
- As a learner, I want to read long explanations in my native language comfortably, at a text size I choose.
- As a learner, I want to answer, check, and move on with the keyboard alone, and see right away whether I was right and why.
- As a learner, I want to print or save a lesson with my answers, so I can study it away from the screen.
- As the builder of later slices, I want ready components and written rules, so each new screen matches without inventing its own look.

**Acceptance criteria** (the contract; items marked *(manual)* are checked by hand in `/check verify`, the rest by tests):
- **AC-1**: A `DesignSystem` library target exists in `VerbaKit`; `Features` depends on it; `DesignSystem` imports none of `Core`, `Persistence`, `ClaudeBridge`, `GRDB`, `Subprocess`, and a SwiftLint `custom_rules` entry fails the lint (severity error) if it does.
- **AC-2**: The whole app runs in dark appearance whatever the macOS setting: main window, Settings window, menus, alerts, and file panels *(manual for menus, alerts, panels)*. Content areas use the palette background; native controls are tinted sage. The sidebar and toolbar stay native.
- **AC-3**: Every pair in the *Contrast pairs* table below meets its threshold in the standard, Increase Contrast, and print palettes: text 4.5:1 (AA); control borders and the focus ring 3:1; with Increase Contrast on, primary and secondary text 7:1. A unit test computes the ratios from the RGB tokens and fails if any pair drops below.
- **AC-4**: In the content area, reading text (lesson titles, explanations, exercise prompts, feedback explanations) uses New York (the system serif); controls use SF Pro; labels, counters, status lines, and key hints use SF Mono. Every content area font comes from a text style (no fixed point sizes) and is applied through `.themeFont(_:)`, which scales it by the current text size. The native sidebar, toolbar, and menus keep system sizes.
- **AC-5**: View menu items Bigger (⌘+), Smaller (⌘−), and Actual Size (⌘0) step Verba's own text size through ten steps, `.xSmall` to `.accessibility3` (default `.large`), each with a fixed scale factor (0.82 to 2.35, see *Text size*). Every content area text (main window detail, Design Gallery) and every text in the Settings window grows and shrinks with it; native control chrome (switches, pop up buttons, the sidebar, toolbar, and menus) keeps its system size. Bigger is disabled at the largest step and Smaller at the smallest. The choice is saved and survives a relaunch; an unknown saved value falls back to `.large`. The macOS system text size setting is not read (SwiftUI on macOS does not apply Dynamic Type). At the largest step no text in the Design Gallery is clipped or truncated *(manual)*.
- **AC-6**: The lesson page shows a header (monospaced label line with the topic, serif title) and the explanation rendered from Markdown (paragraphs, headings, bulleted and numbered lists including nested ones, bold, italic, inline code, block quotes, code blocks, and tables) in a centered reading column 680 points wide at default size, widening in proportion to the text size scale (680 × scale). A table wider than the column scrolls sideways. A Markdown block the renderer does not know (HTML, thematic break, anything else) shows as plain text, never as an error or blank.
- **AC-7**: Exercise components exist for all five kinds (`choice`, `fillBlank`, `translate`, `reorder`, `match`). Each renders the parts in exactly the order the caller passes and never reorders them; options are numbered `[1]` to `[n]`; each card shows a counter like `03/08` (read by VoiceOver as "Exercise 3 of 8") and the kind as a monospaced label.
- **AC-8**: From the keyboard alone: when a new exercise appears, focus moves to its input. Keys 1 to 9 pick the matching `choice` option. Return checks the answer, and Return again moves to the next exercise, in every kind; in the `translate` field Option Return inserts a new line. Tab reaches every control in reading order with a visible sage focus border. `reorder` and `match` are fully usable with Tab and Space (Space or click to place a token or make a pair, again to remove), with no drag required. Esc does nothing except while checking.
- **AC-9**: After checking, an inline feedback panel appears directly under the answer: grade glyph plus word (`✓ Correct`, `~ Partly correct`, `✗ Not quite`), the correct answer when the grade is not correct, and the explanation. The three tones use three distinct colors (mint, amber, soft red), none of them the sage accent, and never rely on color alone. VoiceOver announces the grade word and the explanation once each time the panel enters the result state.
- **AC-10**: While an answer is being checked, the feedback panel shows `Checking…` with a blinking block cursor and the input is locked; Esc cancels (calls the caller's cancel action). If checking fails, the panel shows the caller's message and a Try Again button that calls the caller's retry action. A locked input stays readable at full contrast and stays locked from Check until Next.
- **AC-11**: With Reduce Motion on, the feedback panel appears without animation and the checking cursor is static.
- **AC-12**: Printing a lesson document (File > Print…, ⌘P; in this feature, from the Design Gallery window) produces the light print style: white page, black serif text, no backgrounds, title and topic, the explanation (tables kept), then every exercise with its prompt, your last answer (or "Not answered"), grade glyph plus word in gray, the correct answer, and the explanation. Page breaks never cut a line in half, and Save as PDF from the print panel gives selectable text *(manual for pagination and PDF)*.
- **AC-13**: Debug builds show a Debug menu with Design Gallery (⌥⌘D) that opens a window showing every color token with its hex and contrast ratio, every type style, spacing and shape tokens, and every component in every state (idle, selected, checking, failed, correct, partly correct, wrong) for all five exercise kinds, using built in sample lesson data. Release builds have no Debug menu, and the gallery window never opens by itself (no restoration, no launch).
- **AC-14**: A root `design.md` documents the palettes (hex, role, contrast), the type ramp, spacing, shape, motion, every component with its states, the keyboard map, and the print style. A test reads the hex values in its palette tables and fails if any differs from the code tokens.
- **AC-15**: Every control has an accessibility label; option rows read as "Option 2 of 4, <text>" and expose the selected state; tokens in `reorder` and `match` say where they are ("in answer, position 2" or "not placed"; "paired with <text>" or "not paired"); the feedback panel is one accessibility element labelled with its grade or state; the blinking cursor is hidden from VoiceOver; a selected item has a visible marker (`›` and a border), not only a tint.

## Decision

**Chosen option**: Option 1: a `DesignSystem` target with a dark terminal theme over native chrome.

Build a domain free `DesignSystem` library target that holds Verba's tokens (dark only screen palette, Increase Contrast palette, light print palette, type, spacing, shape, motion), its base components for Slice 1 (lesson page, Markdown explanation, the five exercise inputs, feedback panel, buttons, labels), an in app text size control, an AppKit print path, and a debug Design Gallery, with `design.md` as the human readable record.

**Implementation skills**: `swiftui-pro` (`twostraws/swiftui-agent-skill`, `.agents/skills/swiftui-pro/`) · `swift-testing-pro` (`twostraws/swift-testing-agent-skill`, `.agents/skills/swift-testing-pro/`) · `swift-concurrency` (`avdlee/swift-concurrency-agent-skill`, `.agents/skills/swift-concurrency/`)

## Rationale

Reasoning and options: see [rationale.md](rationale.md).

## Feature design

### Module and wiring

- `Package.swift`: new `.target(name: "DesignSystem", swiftSettings: [.defaultIsolation(MainActor.self)])` with no dependencies, a `DesignSystem` library product, and a `DesignSystemTests` test target. `Features` gains `"DesignSystem"` in its dependencies. `project.yml` adds the `DesignSystem` product to the app target.
- `.swiftlint.yml`: new custom rule `design_system_is_domain_free`, regex `^\s*(@testable\s+)?import\s+(Core|Persistence|ClaudeBridge|GRDB|Subprocess)\b`, `included: '/Sources/DesignSystem/'`, `match_kinds: [keyword, identifier]`, severity error. Prove it with a real violation once, then remove it.
- `DesignSystem` may import SwiftUI, Foundation, and AppKit. AppKit is allowed only for the print path and the appearance helper (gaps SwiftUI does not cover).
- **Isolation**: views and `Color` derivation are main actor (the target default). Value types that tests and the print builder use off the main actor are marked `nonisolated` and `Sendable`: `RGB`, the palettes, `Contrast`, `MarkdownDocument`, `MarkdownBlock`, `LessonPrintDocument`, `PrintedExercise`, `TextSize`, `ThemeFont`. `LessonPrintDocument` holds values only; the `NSAttributedString` is built on demand on the main actor and never stored.
- **Domain to design mapping happens in `Features`**: `Grade` → `FeedbackTone`; `ExercisePart` (already shuffled by `Core`) → option, token, and match strings in display order; the correct answer → one `String`; a thrown typed error → its user facing message; `LessonDetail` → `LessonPrintDocument`; "nothing chosen yet" → `ExerciseAction.disabled`.
- **Forced dark**: `VerbaApp` gets an `@NSApplicationDelegateAdaptor` whose `applicationWillFinishLaunching` calls `Appearance.applyDark()` (sets `NSApplication.shared.appearance = NSAppearance(named: .darkAqua)`). Each SwiftUI window root also gets `.preferredColorScheme(.dark)` and `.tint(Theme.accent)`.
- **Debug gallery**: `AppEnvironment` exposes `static let showsDebugMenu: Bool` (true only under `#if DEBUG`, the one place the build type is checked). `VerbaApp` always declares `Window("Design Gallery", id: "design-gallery") { DesignGalleryView() }` with `.restorationBehavior(.disabled)` and `.defaultLaunchBehavior(.suppressed)`. Its `.commands` include `if AppEnvironment.showsDebugMenu { DebugCommands() }`; `DebugCommands` (in `DesignSystem`) is a `Commands` struct that reads `@Environment(\.openWindow)` and opens `"design-gallery"` with ⌥⌘D.
- **Text size**: measured on macOS 26, `.dynamicTypeSize(_:)` and `@ScaledMetric` change nothing (a `.title2` serif line stays 190 × 21 points from `.xSmall` to `.accessibility3`; a scaled metric of 680 stays 680), while `Font.scaled(by:)` does scale (factor 1.5 gave 277 × 31). So Verba scales its own fonts:
  - `TextSizeCommands` (a `Commands` struct in `DesignSystem`, `@AppStorage("verba.textSize")`) adds Bigger, Smaller, Actual Size to the View menu.
  - `.verbaWindowStyle()` (every window root: main, Settings, gallery) reads the same `@AppStorage` key and puts the current `TextSize` into the environment (`@Entry var textSize: TextSize = .large`). It does not change any font itself, so the native sidebar keeps its system size.
  - `.themeFont(_ font: ThemeFont)` reads `\.textSize` and applies `font.base.scaled(by: textSize.scale)` (plus the line spacing and tracking the token needs). Every `DesignSystem` component uses it; no component calls `.font(...)` with a token directly.
  - `.verbaContentFont()` sets the base font of a content area to `ThemeFont.ui` scaled, so a plain `Text` or a native control label inside it scales too. `ReadingColumn`, `DesignGalleryView`, the main window detail area, and `SettingsView` apply it; the sidebar does not.
  - `.controlSize`: content areas and Settings use `.large` from `.xxxLarge` up (scale ≥ 1.35), else `.regular`, so native controls grow a step with big text.
  - **Scale table** (the iOS body size at each step divided by 17, so the steps feel like Dynamic Type; `.large` is 1.0):

    | Step | `xSmall` | `small` | `medium` | `large` | `xLarge` | `xxLarge` | `xxxLarge` | `accessibility1` | `accessibility2` | `accessibility3` |
    |---|---|---|---|---|---|---|---|---|---|---|
    | Raw value | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
    | Scale | 0.82 | 0.88 | 0.94 | 1.0 | 1.12 | 1.24 | 1.35 | 1.65 | 1.94 | 2.35 |

  - Spacing, borders, and the corner radius stay fixed at every step; only fonts, the `readingBody` line spacing (`xs × scale`), and the reading width scale.
- **Print command**: `PrintCommands` (in `DesignSystem`) replaces `CommandGroup(replacing: .printItem)` with Print… (⌘P). It reads a `@FocusedValue(\.lessonPrintAction)`; a window offers printing by setting `.focusedSceneValue(\.lessonPrintAction, …)`. The gallery sets it to print `SampleLesson`; when no focused window offers it, the item is disabled. Slice 1's lesson screen sets the same value.
- **Files touched outside the package**: `App/VerbaApp.swift` (delegate adaptor, gallery window, commands, `.verbaWindowStyle()`), `App/AppEnvironment.swift` (`showsDebugMenu`), `project.yml`, `.swiftlint.yml`, root `design.md`.

### Tokens (code is the source of truth; `design.md` mirrors it, checked by a test)

Colors are defined as `RGB` values (8 bit sRGB components, built from hex) in three palettes: `Palette.standard`, `Palette.increasedContrast`, `Palette.print`. `Theme` resolves the screen palette from `@Environment(\.colorSchemeContrast)` and derives `Color` from `RGB`. `Contrast.ratio(_:_:)` (WCAG 2 relative luminance) is shared by the test and the gallery. Keep the exact hex values; do not "tidy" them.

| Token | Role | Standard | Increase Contrast | Print |
|---|---|---|---|---|
| `background` | window content area | `#0E100F` | same | `#FFFFFF` |
| `surface` | cards, exercise panes | `#151816` | same | `#FFFFFF` |
| `raised` | input fields, selected row fill | `#1E2320` | same | `#FFFFFF` |
| `text` | primary text | `#E6E8E3` | same | `#111111` |
| `textSecondary` | metadata, hints | `#A6AEA8` | `#C9CFCA` | `#4A4A4A` |
| `textTertiary` | labels, counters | `#8A938C` | `#B0B8B2` | `#4A4A4A` |
| `accent` | sage: focus border, primary button fill, selection marker | `#A3B899` | same | not used |
| `onAccent` | text on the accent | `#0E100F` | same | not used |
| `hairline` | decorative pane borders (exempt from contrast) | `#3A413C` | `#6B756E` | `#BBBBBB` |
| `controlBorder` | option rows, fields, tokens | `#68716B` | `#8E9891` | `#555555` |
| `correct` | correct tone | `#5EE0A0` | same | `#555555` |
| `partly` | partly correct tone | `#E5B454` | same | `#555555` |
| `wrong` | wrong tone | `#F2837A` | same | `#555555` |

**Contrast pairs** (what AC-3 tests; worst measured value in the standard palette in brackets):

| Foreground | On | Threshold |
|---|---|---|
| `text`, `textSecondary`, `textTertiary` | `background`, `surface`, `raised` | 4.5 (standard: text 12.9, secondary 7.0, tertiary 5.0); 7.0 for `text` and `textSecondary` in Increase Contrast (secondary 10.1) |
| `correct`, `partly`, `wrong` | `surface`, `raised` | 4.5 (wrong 6.3) |
| `accent` | `background`, `surface`, `raised` | 3.0, as focus border and selection marker (7.5) |
| `onAccent` | `accent` | 4.5 (9.0) |
| `controlBorder` | `background`, `surface`, `raised` | 3.0 (3.2; Increase Contrast 5.4) |
| print `text`, `textSecondary`, tones | print `background` | 4.5 (`#555555` 7.5) |

`hairline` is decorative: it never marks the edge of a control, so it has no threshold.

**Type** (`ThemeFont` cases, each built from a text style and applied with `.themeFont(_:)`, which multiplies it by `TextSize.scale`):

| Token | Font | Use |
|---|---|---|
| `readingTitle` | `.system(.largeTitle, design: .serif)`, `.bold()` | lesson title |
| `readingHeading` | `.system(.title2, design: .serif)`, `.bold()` | Markdown headings, section heads |
| `readingBody` | `.system(.title2, design: .serif)` (about 17 pt at `.large`), line spacing `Theme.Spacing.xs` | explanation, prompts, feedback explanation |
| `ui` | `.body` (SF Pro) | buttons, fields |
| `label` | `.system(.callout, design: .monospaced)`, uppercase, tracking 0.5 | kind labels, counters, status, key hints |
| `code` | `.system(.body, design: .monospaced)` | inline code, code blocks, typed answers shown back |

`.caption` and `.caption2` are not used anywhere.

**Spacing** (4 point grid): `xs 4`, `s 8`, `m 12`, `l 16`, `xl 24`, `xxl 40`. **Shape**: corner radius `2`, border width `1`, no shadows. **Reading width**: `Theme.readingWidth(for: textSize) = 680 × textSize.scale` (no `@ScaledMetric`, which macOS ignores), used as `maxWidth`, centered, `Theme.Spacing.xl` side padding; at large sizes the column simply fills the window. **Focus**: focusable components draw their own `accent` border (2 points) when `@FocusState` says they are focused, and turn off the system focus effect (`.focusEffectDisabled()`), so the ring is always sage. **Motion**: feedback reveal `.easeOut(duration: 0.15)` with opacity and an `xs` upward offset; cursor blink 1 second period; both off under `accessibilityReduceMotion`.

### Component surface (public API of `DesignSystem`)

All components take value types, bindings, and closures; the caller (a `Features` model) owns all state.

| Component | Kind | Key inputs | Behavior |
|---|---|---|---|
| `ReadingColumn<Content>` | container | content | vertical `ScrollView`, centered, `readingWidth` max, `Theme.background` |
| `LessonHeader` | view | `topic: String`, `title: String` | label line `LESSON · <topic>`, serif title marked as an accessibility heading |
| `MarkdownDocument` | value | `markdown: String` | `blocks: [MarkdownBlock]` (see *Markdown rendering*) |
| `MarkdownText` | view | `markdown: String` | renders `MarkdownDocument` blocks with `Theme` fonts |
| `ExerciseCard<Input>` | container | `position: Int` (0 based), `count: Int`, `kindLabel: String`, `prompt: String`, `input`, `feedback: FeedbackState`, `primaryAction: ExerciseAction`, `returnSubmitsFromInput: Bool` | counter `03/08`, label, prompt (serif, shown as written), input, feedback panel, primary button. Holds a `@FocusState` and moves focus to the input on appear and when `position` changes. When `returnSubmitsFromInput` is false (choice, reorder, match) the button carries `.keyboardShortcut(.defaultAction)`; when true (fill in, translate) the field's submit calls the action instead |
| `ExerciseAction` | enum | `.check(() -> Void)`, `.next(() -> Void)`, `.disabled` | button title "Check", "Next", or "Check" disabled; `Features` picks `.disabled` when nothing is chosen or the field is blank |
| `ChoiceList` | view | `options: [String]`, `selection: Binding<Int?>`, `isLocked: Bool`, `marks: [Int: FeedbackTone]` | `.focusable()`, numbered rows `[n]`, `›` marker and accent border on selection; `onKeyPress` for 1 to 9 selects index n−1 if it exists. `marks` keys are display indexes: after checking, the chosen row carries its grade, and when the grade is not correct the right row carries `.correct` |
| `AnswerField` | view | `text: Binding<String>`, `isMultiline: Bool`, `placeholder: String`, `isLocked: Bool`, `onSubmit: () -> Void` | `›` prompt marker, typed text in the `ui` font. `fillBlank`: single line `TextField`. `translate`: `TextField(axis: .vertical)`; Return submits, Option Return inserts a new line (the macOS default) |
| `ReorderBoard` | view | `tokens: [String]`, `placed: Binding<[Int]>`, `isLocked: Bool` | bank of unplaced tokens and the answer line; each token is a focusable button: Space or click on a bank token appends it, on a placed token removes it. No per token marks after checking |
| `MatchPair` | value | `left: Int`, `right: Int` (display indexes) | |
| `MatchBoard` | view | `left: [String]`, `right: [String]`, `pairs: Binding<[MatchPair]>`, `isLocked: Bool` | two columns of focusable buttons: pick a left item then a right item to pair; picking a paired item unpairs it. Pairs get letter tags `A`, `B`… in left row order. No per item marks after checking |
| `FeedbackState` | enum | `.hidden`, `.checking(cancel: () -> Void)`, `.failed(message: String, retry: () -> Void)`, `.result(tone: FeedbackTone, correctAnswer: String?, explanation: String?)` | |
| `FeedbackPanel` | view | `state: FeedbackState` | inline panel. In `.checking` it holds a hidden Cancel button with `.keyboardShortcut(.cancelAction)`. On a change into `.result` (via `onChange` of a state identity) it posts `AccessibilityNotification.Announcement("<word>. <explanation>")` once |
| `FeedbackTone` | enum | `.correct`, `.partlyCorrect`, `.wrong` | color token, glyph (`✓`, `~`, `✗`, plain text, the same characters in print), word ("Correct", "Partly correct", "Not quite") |
| `Locked` behavior | modifier | `isLocked: Bool` | `.allowsHitTesting(false)` plus `.focusable(false)` on the input; never `.disabled` (which dims below AA) |
| `TerminalLabel` | view | `String` | `label` font, `textTertiary` |
| `PrimaryButtonStyle`, `SecondaryButtonStyle` | `ButtonStyle` | none | accent fill with `onAccent` text / `controlBorder` outline; sharp corners; pressed and disabled states (disabled uses `textTertiary`, still AA) |
| `BlinkingCursor` | view | none | `▍` in `accent`, blinking, static under Reduce Motion, `.accessibilityHidden(true)` |
| `TextSize` | enum, `Int` raw values 0 to 9 | stored in `verba.textSize` | ten steps `.xSmall` … `.accessibility3`, default `.large`; `scale`, `bigger` and `smaller` (nil at the ends), `init(storedValue: Int?)` with the `.large` fallback (see *Text size*) |
| `ThemeFont` | enum | `readingTitle`, `readingHeading`, `readingBody`, `ui`, `label`, `code` | `base: Font` from the Type table; applied only through `.themeFont(_:)` |
| `.themeFont(_:)`, `.verbaContentFont()`, `.verbaWindowStyle()` | modifiers | see *Text size* | |
| `TextSizeCommands`, `DebugCommands`, `PrintCommands` | `Commands` | see *Module and wiring* | |
| `LessonPrintDocument` | value | `title`, `topic`, `explanationMarkdown`, `exercises: [PrintedExercise]` | |
| `PrintedExercise` | value | `number: Int`, `kindLabel: String`, `prompt: String`, `answer: String?`, `tone: FeedbackTone?`, `correctAnswer: String?`, `explanation: String?` | `answer == nil` prints "Not answered" |
| `LessonPrinter` | type, main actor | `LessonPrintDocument` | builds the attributed string, puts it in an `NSTextView` sized to the printable width of `NSPrintInfo.shared` (US Letter or A4 from the system, 72 pt margins), runs `NSPrintOperation` with the standard panel (which offers Save as PDF) |
| `DesignGalleryView` | view | none | every token (with hex and `Contrast.ratio`), type style, and component in every state, using `SampleLesson`; sets the print focused value |
| `SampleLesson` | value | static | two languages (Polish explanation, Spanish material), one table, one nested list, all five exercise kinds, one of each grade |
| `Appearance.applyDark()` | function | none | app wide dark aqua appearance |

### Markdown rendering

- Parse with `AttributedString(markdown: text, options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible))`. If it throws, the result is one `.plain(text)` block.
- Group adjacent runs into blocks by comparing the identities of their `presentationIntent` components. Map: `.paragraph` → paragraph; `.header(level)` → heading; `.orderedList` / `.unorderedList` + `.listItem(ordinal)` → list items with depth = number of list components (nested lists flatten into one list with indent per depth); `.blockQuote` → quote (accent left bar); `.codeBlock` → code block (`code` font, `raised` fill, horizontal scroll); `.table(columns)` with `.tableHeaderRow` / `.tableRow` / `.tableCell(columnIndex)` → table; `.thematicBreak`, `.htmlBlock`, or a run with no intent → `.plain` with its raw characters.
- Inside a block, keep the `AttributedString` and map `inlinePresentationIntent` to fonts (`.stronglyEmphasized` → bold, `.emphasized` → italic, `.code` → `code` font) before showing it with `Text`. Links keep their link attribute.
- Tables render as a SwiftUI `Grid` with a bold header row, a `hairline` rule under it, column alignment from the table's column alignments, and the whole grid inside a horizontal `ScrollView` so wide tables never clip.
- The print builder reads the same `MarkdownDocument` and writes paragraphs, headings, lists (indented), and tables as tab stopped rows with a rule under the header.

### Print style

White page, all text in the print palette, body 11 pt New York (`NSFont.systemFont(ofSize: 11).withDesign(.serif)` via its font descriptor), headings 14 pt bold, labels 9 pt SF Mono; fixed sizes (paper does not follow the screen text size). Order: title, topic label, explanation, then per exercise: `03 · TRANSLATE` label, prompt, "Your answer: …" or "Not answered", the grade glyph and word in `#555555`, "Answer: …" when not correct, and the explanation.

### Value sourcing

| Action | Value produced / displayed | Source |
|---|---|---|
| Any screen | colors, fonts, spacing, radius, motion | `Theme` tokens in this spec |
| Contrast shown in gallery and tested | ratio | `Contrast.ratio` over `RGB` tokens |
| Increase Contrast | which palette | `@Environment(\.colorSchemeContrast)` |
| Reduce Motion | animate or not | `@Environment(\.accessibilityReduceMotion)` |
| Text size | `TextSize` step and its scale | `UserDefaults` key `verba.textSize` (a small UI preference, allowed by spec 0001), read by `.verbaWindowStyle()` into `\.textSize`; the scale per step is the fixed table in *Text size* |
| Reading width | points | `680 × TextSize.scale` |
| Lesson header | topic, title | `Lesson.topic`, `Lesson.title`, passed by `Features` |
| Explanation | Markdown text | `Lesson.explanation` (Markdown per the `lesson-v1` prompt) |
| Exercise counter | position and count | `Exercise.position` and `LessonDetail.exercises.count`, passed by `Features` |
| Kind label | `CHOICE`, `FILL IN`, `TRANSLATE`, `ORDER`, `MATCH` | mapped from `ExerciseKind` in `Features` |
| Fill in prompt | prompt text | `Exercise.prompt` shown as written; no blank parsing |
| Option, token, match order | display order | `ExercisePart.displayPosition` from the `Core` shuffler; `DesignSystem` never reorders |
| Primary action state | check, next, disabled | the `Features` model (selection or text empty → `.disabled`) |
| Feedback tone | correct, partly, wrong | `Attempt.grade` mapped in `Features` |
| Choice marks | per row tone | chosen display index and the `isCorrect` part's display index, from `Features` |
| Correct answer shown | one string | the `isCorrect` part, the `correctPosition` order, or the `matchKey` pairs, joined in `Features` |
| Feedback explanation | text | `Attempt.feedback`, falling back to `Exercise.explanation` |
| Checking failure message | text | the user facing message of the thrown typed error (for example `ClaudeError`), passed by `Features` |
| Printed exercise answer | your last answer or none | the latest `Attempt.response` rendered to text in `Features`; nil when unanswered |
| Paper size | page size | `NSPrintInfo.shared` (system default, changeable in the print panel) |
| Gallery content | sample lesson | `SampleLesson`, static values in `DesignSystem` |
| Debug menu visibility | shown or not | `AppEnvironment.showsDebugMenu` (`#if DEBUG`) |
| Print availability | enabled or not | `@FocusedValue(\.lessonPrintAction)` set by the focused window |

### Key invariants

- `DesignSystem` never imports domain or infrastructure modules and never reorders parts it is given.
- No view outside `DesignSystem` uses a literal color, font size, or corner radius; they use `Theme`.
- Every grade is shown with glyph and word, on screen and in print.
- Every pair in *Contrast pairs* stays at or above its threshold; the contrast test is the guard.
- Content area fonts always come from text styles through `.themeFont(_:)` or `.verbaContentFont()`, so the text size scale reaches all of them. A bare `.font(.body)` in a content area would silently ignore text size; that is a bug.
- `design.md` palette hex values equal the code tokens (tested).

### Security model

No data leaves the Mac and no new data is stored, apart from one text size preference in `UserDefaults`. Printing goes through the system print panel, which the user controls. No compliance scope.

### Configuration required

None (no environment variables or credentials). One `UserDefaults` key: `verba.textSize`.

### Critical test scenarios

- Happy path: in the Design Gallery, focus lands on a choice exercise; key 2 picks option 2, Return shows `✓ Correct` inline with the explanation, Return goes on, verifies **AC-7**, **AC-8**, **AC-9**
- Contrast guard: `DesignSystemTests` computes every pair in *Contrast pairs* for all three palettes and fails under the thresholds, verifies **AC-3**
- Markdown: `MarkdownDocument` tests for paragraphs, a nested list, a table, a code block, an HTML block, and malformed input yield the expected blocks and never an empty result, verifies **AC-6**
- Failure case: in `.checking`, Esc calls cancel; in `.failed`, Try Again calls retry; a locked input ignores clicks and keys, verifies **AC-10**
- Print: `LessonPrintDocument` tests check the attributed string uses only print palette colors and no background, contains every glyph and word, "Not answered" for a nil answer, and every exercise section; Save as PDF from the gallery shows selectable text and whole lines per page (manual), verifies **AC-12**
- Text size: `TextSize` tests cover the step order, the scale table (strictly rising, `.large` is 1.0), `bigger` and `smaller` at the bounds, the fallback for an unknown stored value, and the reading width at three steps, verifies **AC-5**, **AC-6**
- design.md sync: a test parses the palette tables in `design.md` and compares hex values to the tokens, verifies **AC-14**
- Accessibility (manual): at `.accessibility3` with Increase Contrast and Reduce Motion on, the gallery shows no clipped text, brighter borders, and no animation; VoiceOver reads "Exercise 3 of 8", option position and selected state, and announces feedback once, verifies **AC-5**, **AC-11**, **AC-15**
- Boundary: lint fails on an `import Core` added inside `Sources/DesignSystem/`, verifies **AC-1**

## Build plan

Tracer Bullet: the first task runs end to end from the package through the real app window, then each later task thickens that thread.

1. **Target and boundary.** Add the `DesignSystem` target, product, test target, the `Features` dependency, the `project.yml` product, and the SwiftLint rule (proved once with a real violation). Satisfies **AC-1**
2. **Thin thread to the screen.** `RGB`, the three palettes, `Contrast`, the contrast test, `Appearance.applyDark()` through an app delegate adaptor, tint and palette background on the main and Settings windows; a first `DesignGalleryView` showing the color tokens with ratios, opened from `DebugCommands` (`AppEnvironment.showsDebugMenu`, window with restoration and launch suppressed). Files: `VerbaApp.swift`, `AppEnvironment.swift`. Satisfies **AC-2**, **AC-3**, **AC-13**
3. **Type and text size.** `ThemeFont`, `.themeFont(_:)`, `.verbaContentFont()`, spacing, shape, focus, and motion tokens; `TerminalLabel`, button styles, `BlinkingCursor`; `TextSize` with its scale table (with tests), the `\.textSize` environment entry set by `.verbaWindowStyle()`, and `TextSizeCommands`; apply `.verbaContentFont()` to the main window detail area, Settings, and the gallery; gallery sections for type and tokens. Satisfies **AC-4**, **AC-5**, **AC-11**
4. **Lesson page and choice loop.** `ReadingColumn`, `LessonHeader`, `MarkdownDocument` (with tests), `MarkdownText`, `ExerciseCard`, `ExerciseAction`, `ChoiceList`, `FeedbackState`, `FeedbackPanel` (all states), `FeedbackTone`, the locked behavior; focus, keyboard map, and VoiceOver labels; `SampleLesson`; the gallery shows the sample lesson with a working choice exercise in every state. Satisfies **AC-6**, **AC-7**, **AC-8**, **AC-9**, **AC-10**, **AC-11**, **AC-15**
5. **The other four kinds.** `AnswerField` (fill in, translate), `ReorderBoard`, `MatchBoard`, `MatchPair`, each with keyboard use, accessibility labels, and gallery states. Satisfies **AC-7**, **AC-8**, **AC-10**, **AC-15**
6. **Print.** `LessonPrintDocument`, `PrintedExercise` (with tests), `LessonPrinter`, `PrintCommands` and the focused print value; the gallery prints `SampleLesson`. Satisfies **AC-12**
7. **`design.md` and finish.** Write the root `design.md` from the code tokens and components, add the design.md sync test, fill any missing gallery state; run lint, `swift test`, and the manual checks (largest text size, Increase Contrast, Reduce Motion, VoiceOver, system panels dark, PDF). Satisfies **AC-14**, **AC-2**, **AC-5**, **AC-13**, **AC-15**

## Consequences

**Positive**:
- Every later slice gets ready parts and one written look, so screens match without new design work.
- The contrast test, the design.md sync test, and the lint rule turn easy to break rules (readable colors, written values matching code, a domain free UI kit) into failing builds.
- Lessons with tables and lists render properly on screen and in print with no new dependency.
- Keyboard first answering suits the terminal feel and makes VoiceOver and keyboard users first class.

**Negative / tradeoffs**:
- Text size is Verba's own setting, not the system one: macOS gives SwiftUI no Dynamic Type, so a future macOS text size setting would not reach Verba until it is wired in. Every content area text must go through `.themeFont(_:)` or sit under `.verbaContentFont()`; one stray `.font(.body)` quietly stays at a fixed size (the gallery at the largest step is the check).
- Dark only ignores the user's macOS appearance; people who read better on light backgrounds cannot switch. Adding a light screen palette later means a new set of values and contrast test rows.
- The scope's "light and dark mode" line no longer holds; the done line changes to dark only plus a light print style.
- An own Markdown renderer is code to maintain; uncommon Markdown (images, footnotes, HTML) shows as plain text.
- `textTertiary` (5.0) and `controlBorder` (3.2) sit close to their thresholds on `raised`; any color change must go through the contrast test.
- The print path uses AppKit inside `DesignSystem`, a second rendering path (attributed string, not SwiftUI) to keep visually in line with the screen.
- Forcing dark with the app appearance also darkens system panels Verba opens, which is the intent but differs from most Mac apps.
- The gallery window is declared in release builds too (unreachable there), to keep `#if DEBUG` inside `AppEnvironment`.

**Neutral**:
- Chat bubble and progress view are described in `design.md` (tokens, states) but built in Slice 3 and Slice 2.
- The sidebar keeps native styling and system text size, so the window mixes native chrome at the edge with flat terminal panes in the content.
- No schema change; one `UserDefaults` key.

## Follow-up

- [ ] Slice 1 (first lesson loop) builds its screens from these components and offers ⌘P on the lesson screen by setting the `lessonPrintAction` focused value.
- [ ] Slice 3 (tutor chat) builds the chat bubble and Slice 2 (progress) the progress view, both against `design.md`.
- [ ] If a light screen mode is ever wanted, add it as a new palette plus contrast test rows; the token names already separate role from value.
- [ ] `/sync`: root `AGENTS.md` says "`Features` ... imports `Core` only"; after this build it should say `Core` and `DesignSystem`, list `DesignSystem` in the module rules, and add a nested `Packages/VerbaKit/Sources/DesignSystem/AGENTS.md` (use `Theme`, never literals; no domain imports).
