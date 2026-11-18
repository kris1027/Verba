# 0004. Rationale: dark terminal design system

## Context

> ⚠️ Premise note: the scope asks for "light and dark mode", and you chose dark only. That is a fair call for a personal app, but it changes the feature's done line, and printed pages still need a light style, so this spec keeps one light palette for print only. Second, a terminal look and long reading pull in opposite directions: monospaced, dense screens tire the eye over several paragraphs of native language explanation. The spec resolves this by keeping the terminal feel in the frame (colors, borders, labels) and setting all reading text in a serif.

Verba is a native macOS 26 SwiftUI app where every lesson, explanation, and correction is long form text in the learner's native language, followed by short drills with instant feedback. Right now every screen is stock SwiftUI with placeholders. Slice 1 (the first lesson loop) is next, and without a shared look each slice would choose its own colors, type, and component behavior, and the course would feel stitched together.

The forces: the learner reads a lot, so line length, type, and contrast matter more than in most apps. Answering must be fast and keyboard friendly. Feedback must be unmistakable and never depend on color alone. The AGENTS.md accessibility baseline (labelled controls, Dynamic Type, VoiceOver order, WCAG AA) applies to every screen, but macOS does not drive SwiftUI text styles from a system setting, so "Dynamic Type" needs an in app control. Lesson explanations arrive as Markdown with tables, which SwiftUI `Text` cannot render. Lessons must print cleanly. The architecture rules keep `Features` free of infrastructure and want boundaries the compiler or the linter enforce. The engineer wants the app to feel like Claude Code: a dark terminal, with a muted sage accent.

Not deciding means Slice 1 sets the look by accident, and every later slice either copies it inconsistently or reworks it.

## Options considered

### Option 1: DesignSystem target, dark terminal theme over native chrome

A domain free library target holds tokens and base components; the content area gets the terminal look, while the sidebar, toolbar, menus, and Settings stay native and are forced dark.

**Pros**:
- The compiler and a lint rule keep the UI kit free of domain types, so components stay reusable and previews stay fast.
- Native chrome keeps macOS behavior (sidebar selection, keyboard focus, VoiceOver) for free.
- One place for tokens, one gallery to check them.

**Cons**:
- `Features` has to map domain values (grades, parts, errors) to plain component inputs, a little extra code per screen.
- The window mixes native vibrancy at the edge with flat terminal panes.

### Option 2: Theme folder inside Features

The same tokens and components, but as a folder in `Features`.

**Pros**:
- No new target, no `Package.swift` or `project.yml` changes.

**Cons**:
- Nothing stops a component from importing `Core` or calling a feature model, so the kit slowly couples to screens.
- Previews and builds of the kit pull in all of `Features`.

### Option 3: Fully custom terminal chrome

Replace the sidebar and toolbar with custom flat views in SF Mono.

**Pros**:
- The most complete terminal look.

**Cons**:
- Selection, focus, keyboard navigation, and VoiceOver for the sidebar must be rebuilt by hand, which is where accessibility bugs hide.
- Fights the platform on every macOS release.

### Option 4: Stock macOS look with an accent color

Keep system colors and fonts, follow the system appearance, set a sage accent.

**Pros**:
- Least work, light and dark for free, fully native.

**Cons**:
- Not the look the engineer asked for; not book like for reading.
- Still needs the Markdown renderer, print style, and exercise components, so the saving is mostly in colors.

Smaller choices settled in the conversation, with their runner up:

- **Print path**: AppKit text layout (`NSPrintOperation` over `NSTextView`) over SwiftUI `ImageRenderer` (one tall page or lines cut at page breaks) and WebKit HTML (a second styling system).
- **Markdown**: own renderer on Foundation's `AttributedString(markdown:)` over a third party package (a new dependency needing explicit OK, its own theme API, and no print path) and inline only Markdown with a changed prompt (weaker lessons, no tables).
- **Feedback colors**: a distinct mint, amber, soft red trio with symbols, over reusing the sage accent for correct (every sage button would read as "right answer").
- **Text size**: View menu commands with ⌘+ ⌘− ⌘0 over a Settings only slider (slower to reach mid lesson).
- **Text size mechanism (updated 2026-11-17, during the build)**: the first version scaled text with `.dynamicTypeSize(_:)` and `@ScaledMetric`. Measured on macOS 26 with the real toolchain, both are no-ops: text styles keep one size at every step and a scaled metric never changes. `Font.scaled(by:)` does work. Chosen: Verba's own `TextSize` scale factor in the environment, applied by `.themeFont(_:)` and `.verbaContentFont()`, with the reading width as `680 × scale`. Runner up: fixed point sizes per step (`.system(size:design:)` from a size table), rejected because it drops text styles (AC-4) and gives up the system's per style weight and leading. Also rejected: an AppKit wide magnification (`NSWindow` scaling or a view `scaleUnitSquare`), which blurs text, scales borders and hit areas, and fights SwiftUI layout. The scale steps copy the iOS body sizes so the ten steps feel familiar. Cost: one more convention every component must follow (no bare `.font`), checked by eye in the gallery at the largest step.
- **Breadth**: tokens plus Slice 1 parts now, over all five components now (chat bubble and progress view would sit unused for slices).

## Rationale

Option 1 fits the forces best. The module rules in AGENTS.md already rely on compiler enforced boundaries; a domain free `DesignSystem` target extends the same idea to the UI, and spec 0001 set it as the default. Keeping native chrome while theming the content puts the effort where the learner looks (the reading column and the exercise card) and keeps macOS doing the accessibility heavy lifting at the edges, which matters because the accessibility baseline applies to every screen.

The terminal look is your preference, and it fits the frame well, but monospaced type for long native language reading would hurt the core job. Serif reading text inside terminal panes gives the look you asked for without making lessons tiring. Dark only is your choice; the spec records the cost (no light screen mode, scope line changes) and keeps the token names role based so adding a light screen palette later is a values change, not a redesign.

Building the Markdown renderer on Foundation keeps the dependency rule intact and lets one parsed `MarkdownDocument` feed both the SwiftUI view and the print attributed string, so screen and paper stay in step. The contrast values were measured before writing: every text token is at or above 5:1 on the lightest dark surface (`raised`), and control borders at 3.2:1, so the palette passes AA as drawn; the margins are thin for `textTertiary` and `controlBorder`, which is why the contrast test guards every pair. Reading text uses `.title2` (about 17 points at the default size) because macOS text styles are small and lessons are long.

A cross check by a second model before acceptance added the focus, Return, and Esc rules, the component input definitions, the Markdown mapping details, the RGB token form, the explicit contrast pair table, and the design.md sync test.
