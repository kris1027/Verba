# Verba design system

Verba looks like a calm, dark terminal wrapped around a book: near black panes, sharp thin borders, a muted sage accent, and small monospaced labels, while everything you read (lesson titles, explanations, prompts, feedback) is set in New York, Apple's serif. Printed lessons switch to a light, ink friendly style.

The code in `Packages/VerbaKit/Sources/DesignSystem/` is the source of truth. This file mirrors it so people can read the rules without opening Swift. A test (`DesignDocTests`) reads the palette table below and fails if any hex value differs from the code, so change both together. The decision and its reasons live in [spec 0004](docs/specs/0004-design-system/index.md).

Open the Design Gallery in a debug build (Debug › Design Gallery, ⌥⌘D) to see every token and component in every state.

## Rules for every screen

- Use `Theme` tokens, never a literal color, font size, or corner radius.
- Set content fonts with `.themeFont(_:)`, or put the area under `.verbaContentFont()`. A bare `.font(.body)` ignores Verba's text size and is a bug.
- Show every grade with its glyph and word, never by color alone.
- Never use `.disabled` to lock an answer (it dims below AA); use the components' `isLocked`.
- `DesignSystem` imports no domain module. `Features` maps `Core` values to plain strings and enums first.
- The sidebar, toolbar, and menus stay native, at system text size.

## Color

Verba's screen is dark only, whatever the macOS setting. The Increase Contrast palette takes over by itself when that accessibility setting is on. The print palette is used only on paper and in PDFs.

### Palettes

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
| `correct` | correct tone (mint) | `#5EE0A0` | same | `#555555` |
| `partly` | partly correct tone (amber) | `#E5B454` | same | `#555555` |
| `wrong` | wrong tone (soft red) | `#F2837A` | same | `#555555` |

### Contrast

The lowest ratio of each foreground against `background`, `surface`, and `raised`. `ContrastTests` checks every pair in all three palettes and fails below the threshold.

| Foreground | Threshold | Standard | Increase Contrast | Print (on white) |
|---|---|---|---|---|
| `text` | 4.5 (7.0 with Increase Contrast) | 12.9 | 12.9 | 18.9 |
| `textSecondary` | 4.5 (7.0 with Increase Contrast) | 7.0 | 10.1 | 8.9 |
| `textTertiary` | 4.5 | 5.0 | 7.9 | 8.9 |
| `correct`, `partly`, `wrong` | 4.5 | 9.6, 8.3, 6.3 | same | 7.5 |
| `accent` (focus border, selection marker) | 3.0 | 7.5 | 7.5 | not used |
| `onAccent` on `accent` | 4.5 | 9.0 | 9.0 | not used |
| `controlBorder` | 3.0 | 3.2 | 5.4 | 7.5 |

`hairline` is decorative and never marks the edge of a control, so it has no threshold. `textTertiary` and `controlBorder` sit close to their limits; any change goes through the contrast test.

## Type

Every font comes from a text style, then Verba scales it by its own text size (macOS gives SwiftUI no Dynamic Type).

| Token | Font | Use |
|---|---|---|
| `readingTitle` | New York, large title, bold | lesson title |
| `readingHeading` | New York, title 2, bold | Markdown headings, section heads |
| `readingBody` | New York, title 2 (about 17 pt), line spacing 4 × scale | explanations, prompts, feedback explanations |
| `ui` | SF Pro, body | buttons, fields, content area base font |
| `label` | SF Mono, callout, capitals, tracking 0.5 | kind labels, counters, status lines, key hints |
| `code` | SF Mono, body | inline code, code blocks, typed answers shown back |

`.caption` and `.caption2` are not used.

### Text size

View › Bigger (⌘+), Smaller (⌘−), and Actual Size (⌘0) step through ten sizes. The choice is saved under the `UserDefaults` key `verba.textSize` (an unknown value falls back to `large`). Native control chrome keeps its system size, but content areas switch native controls to the large control size from `xxxLarge` up.

| Step | `xSmall` | `small` | `medium` | `large` | `xLarge` | `xxLarge` | `xxxLarge` | `accessibility1` | `accessibility2` | `accessibility3` |
|---|---|---|---|---|---|---|---|---|---|---|
| Scale | 0.82 | 0.88 | 0.94 | 1.0 | 1.12 | 1.24 | 1.35 | 1.65 | 1.94 | 2.35 |
| Reading width (pt) | 558 | 598 | 639 | 680 | 762 | 843 | 918 | 1122 | 1319 | 1598 |

## Spacing, shape, motion

- **Spacing** (4 point grid, fixed at every text size): `xs` 4, `s` 8, `m` 12, `l` 16, `xl` 24, `xxl` 40.
- **Shape**: corner radius 2, border width 1, no shadows; a held down button drops to 0.8 opacity. Panes use a `hairline` border; controls use `controlBorder`.
- **Reading column**: 680 × text size scale, centered, `xl` side padding; at large sizes it simply fills the window.
- **Focus**: every focusable component draws its own 2 point `accent` border and turns off the system focus ring, so focus is always sage.
- **Motion**: the feedback panel fades in and rises `xs` over 0.15 s (ease out); the checking cursor blinks with a 1 s period. With Reduce Motion on, the panel appears without animation and the cursor stays solid.

## Components

All components take plain values, bindings, and closures. The feature model owns the state.

| Component | What it is | States |
|---|---|---|
| `ReadingColumn` | the lesson page container: vertical scroll, reading width, palette background | none |
| `LessonHeader` | `LESSON · <topic>` label and the serif title (a heading for VoiceOver) | none |
| `MarkdownText` | the explanation: paragraphs, headings, nested lists, quotes (sage bar), code blocks, tables (scroll sideways when wide); unknown blocks show as plain text | none |
| `ExerciseCard` | counter `03/08` (read as "Exercise 3 of 8"), kind label, prompt, input, feedback panel, primary button, key hint | follows its input and feedback |
| `ChoiceList` | numbered rows `[1]` to `[n]` in the given order | idle, selected (`›` and sage border), locked, marked (tone glyph and border per row) |
| `AnswerField` | `›` marker and a field: one line for fill in, growing lines for translate | empty, typing, focused, locked (answer shown as text) |
| `ReorderBoard` | answer line above, word bank below | empty, partly placed, all placed, locked |
| `MatchBoard` | two columns; pairs tagged `A`, `B`… by left row | unpaired, picked (`›` and sage border), paired, locked |
| `FeedbackPanel` | the inline panel under the answer, one VoiceOver element | hidden, checking (`Checking…` and blinking cursor), failed (message and Try Again), correct, partly correct, wrong |
| `TerminalLabel` | small monospaced capitals in `textTertiary` | none |
| `PrimaryButtonStyle` | sage fill, dark text | enabled, pressed, focused, disabled (outline, tertiary text, still AA) |
| `SecondaryButtonStyle` | `controlBorder` outline, primary text | enabled, pressed, focused, disabled |
| `BlinkingCursor` | `▍` in sage, hidden from VoiceOver | blinking, solid under Reduce Motion |

### Grades

| Tone | Glyph and word | Color |
|---|---|---|
| correct | `✓ Correct` | `correct` (mint) |
| partly correct | `~ Partly correct` | `partly` (amber) |
| wrong | `✗ Not quite` | `wrong` (soft red) |

When the grade is not correct, the panel also shows the correct answer. VoiceOver announces the grade word and the explanation once each time a result appears.

### Exercise flow

1. A new exercise appears and focus moves to its input.
2. With an answer, the button says Check; with none, Check is disabled.
3. Check locks the input (it stays readable at full contrast) and the panel shows `Checking…`.
4. The result appears inline; the button says Next.
5. If checking fails, the panel shows the message and Try Again. The input stays locked until Next.

### Planned components

These are described here so later slices match; they are built with their features.

- **Chat bubble** (Slice 3, tutor chat): your messages on `raised` with a `controlBorder` outline, aligned trailing; tutor messages on `surface` with a `hairline` outline, aligned leading, text in `readingBody`; a `TerminalLabel` with the speaker above each; corrections use the grade tones with glyph and word. States: sending (blinking cursor), sent, failed (message and Try Again).
- **Progress view** (Slice 2, progress): a `TerminalLabel` counter such as `LESSONS · 12` and a flat bar, `accent` fill on `raised` with a `controlBorder` edge, no rounding beyond the radius 2. States: empty, in progress, complete.

## Keyboard

| Key | Where | Does |
|---|---|---|
| 1 to 9 | choice list | picks that option |
| Up, Down | choice list | moves the selection one row |
| Up, Down | choice list | moves the selection |
| Return | any exercise | Check, then Next; Try Again after a failed check |
| Option Return | translate field | inserts a line break |
| Tab, Shift Tab | everywhere | moves through every control in reading order (sage focus border); buttons join the order only when System Settings › Keyboard › Keyboard navigation is on, as everywhere on macOS, and Return and Esc reach Check, Next, Try Again, and Cancel either way |
| Space or click | reorder and match items | places or removes a word; picks, pairs, or unpairs an item |
| Esc | while checking | cancels the check (does nothing otherwise) |
| ⌘+ (or ⌘=), ⌘−, ⌘0 | View menu | Bigger, Smaller, Actual Size |
| ⌘P | File menu | prints the lesson the focused window offers |
| ⌥⌘D | Debug menu (debug builds only) | opens the Design Gallery |

## Print style

File › Print… (⌘P) prints the focused lesson; the print panel also offers Save as PDF, which keeps the text selectable.

- White page, print palette only, no backgrounds, 72 point margins, paper size from the system.
- Fixed sizes (paper does not follow the screen text size): title 20 pt New York bold, headings 14 pt bold, body 11 pt New York, code 10 pt SF Mono, labels 9 pt SF Mono.
- Order: title, topic label, explanation (lists indented, tables as tab stopped rows with a rule under the header), then each exercise: `03 · TRANSLATE` label, prompt, "Your answer: …" or "Not answered", grade glyph and word in `#555555`, "Answer: …" when not correct, and the explanation.
- Lines never split across pages.
