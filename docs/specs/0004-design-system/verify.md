# Verify: Design system & UI foundation · spec 0004 · updated 2026-11-17
_Steps derived from spec 0004 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## UI / manual
Build and open `Verba Dev.app`, then Debug › Design Gallery (⌥⌘D).

- [ ] Set macOS to Light appearance, launch Verba → main window, Settings, menus, an alert, and the print panel are all dark; content uses the palette background; controls are sage tinted; sidebar and toolbar look native → AC-2
- [ ] Release build (`-configuration Release`) → no Debug menu; the gallery never opens on launch or after relaunch with it open → AC-13
- [ ] Gallery shows every color token with hex and contrast, every type style, spacing and shape tokens, and every exercise kind in idle, selected, checking, failed, correct, partly correct, wrong → AC-13
- [ ] Lesson title, explanation, prompts, and feedback explanation are serif; buttons SF Pro; labels and counters SF Mono → AC-4
- [ ] View › Bigger ⌘+ to the largest step → gallery and Settings text grows, sidebar and menus do not; Bigger is disabled at the top; no text in the gallery is clipped or truncated; Smaller ⌘− disables at the bottom; Actual Size ⌘0 returns to default → AC-5
- [ ] Quit and relaunch at a non default size → the size is kept. Run `defaults write <bundle id> verba.textSize 42`, relaunch → default size → AC-5
- [ ] Lesson page: header shows `LESSON · SPANISH · SER AND ESTAR` and the serif title; the explanation shows headings, bold, italic, inline code, a nested list (indented), a quote with a sage bar, a code block, and the table; the column is 680 pt at default and widens with text size → AC-6
- [ ] Markdown edge cases section: the HTML block and the thematic break show as plain text; the wide table scrolls sideways instead of clipping → AC-6
- [ ] Every card shows a counter like `03/05` and its kind label; options read `[1]` to `[4]` in the given order → AC-7
- [ ] Choice exercise, keyboard only: focus lands on the options; press 2 → option 2 selected (`›` and sage border); Return → `Checking…` with blinking cursor, then `✓ Correct` with the explanation inline; Return → Next resets → AC-8, AC-9
- [ ] Pick option 1 instead → `✗ Not quite`, the answer `es` shown, the chosen row marked wrong and row 2 marked correct, three tones visibly different from sage → AC-9
- [ ] Fill in and translate: Return checks; in translate Option Return inserts a new line → AC-8
- [ ] Reorder and match with Tab and Space only: place and remove words; pick, pair, and unpair items; each focused item has a sage border → AC-8
- [ ] Press Esc while idle → nothing; while `Checking…` → check cancels and the input unlocks → AC-8, AC-10
- [ ] Turn on "Make checking fail", check → message and Try Again; the input stays locked and readable at full contrast; Try Again checks again → AC-10
- [ ] Turn on Reduce Motion → the panel appears without animation and the cursor is solid → AC-11
- [ ] Turn on Increase Contrast → secondary text and borders brighten → AC-3
- [ ] VoiceOver: card reads "Exercise 3 of 5, Translate"; an option reads "Option 2 of 4, es" with selected state; reorder tokens say "in answer, position 2" or "not placed"; match items say "paired with …" or "not paired"; the panel is one element; a result is announced once (grade, then explanation); the cursor is not read → AC-9, AC-15
- [ ] With the gallery focused, File › Print… (⌘P) → light page: title, topic, explanation with the table, then each exercise with prompt, your answer or "Not answered", glyph and word in gray, the answer when not correct, and the explanation; no line is cut across pages → AC-12
- [ ] Save as PDF from the print panel → the PDF text is selectable → AC-12
- [ ] Focus the main window → File › Print… is disabled → AC-12

## Commands
- [ ] `swift test --package-path Packages/VerbaKit` → all suites pass, including `ContrastTests`, `TextSizeTests`, `MarkdownDocumentTests`, `ExerciseComponentTests`, `LessonPrintTests`, `DesignDocTests` → AC-3, AC-5, AC-6, AC-7, AC-9, AC-12, AC-14
- [ ] Add `import Core` to any file in `Sources/DesignSystem/`, run `swiftlint lint --strict` → fails with `design_system_is_domain_free`; remove it → AC-1
- [ ] Change one hex value in `design.md`, run `swift test --filter DesignDocTests` → fails; revert → AC-14

## Value sourcing
- [ ] Contrast in the gallery matches `Contrast.ratio` (compare one ratio to the `design.md` table) → AC-3
- [ ] Increase Contrast on and off switches the palette live, without relaunch → AC-3
- [ ] Reduce Motion on and off switches animation live → AC-11
- [ ] Text size comes from `verba.textSize`: change it in one window, every window follows → AC-5
- [ ] Reading width at `accessibility1` is 1122 pt (or the window width if narrower) → AC-6
- [ ] Options, tokens, and match items appear exactly in the order passed (compare to `SampleLesson`) → AC-7
- [ ] Print paper size follows the print panel's paper choice (switch A4 and US Letter) → AC-12
- [ ] Debug menu shows only in debug builds → AC-13

## Acceptance-criteria coverage
- AC-1 lint step · AC-2 appearance step · AC-3 contrast test, Increase Contrast steps · AC-4 fonts step · AC-5 text size steps and test · AC-6 lesson page, edge cases, width · AC-7 counter and order steps · AC-8 keyboard steps · AC-9 feedback steps · AC-10 Esc and failure steps · AC-11 Reduce Motion · AC-12 print steps and test · AC-13 gallery and release steps · AC-14 design.md test · AC-15 VoiceOver step
