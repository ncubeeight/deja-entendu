# App Icon — Launch Assets

Design: bubble→card shape, camera + mic (stacked) on the left as input,
"A" over "あ" (stacked) on the right as output, connected by a two-arm
paisley/swirl symbol in the center. All four files below are the same
vector geometry — only the gradient colors (and, on one file, the left
paisley's opacity) differ.

## Files

- **app-icon.svg** — Deep Blue → Turquoise
  `#14227A → #0A6FB0 → #00E8C6`
  Both swirl arms full opacity (matching color intensity on both sides).

- **app-icon-purple-gold.svg** — Purple → Golden Yellow
  `#3B1368 → #9A3FA8 → #FFC94A`
  Both swirl arms full opacity.

- **app-icon-purple-gold-lightened.svg** — Purple → Golden Yellow (survey-preferred variant)
  Same colors as above, but the left swirl arm is set to 40% opacity so it
  reads as a soft echo behind the right arm. This is the version your
  survey panel responded to best for clarity.

- **app-icon-magenta-orange-gold.svg** — Magenta → Orange → Golden Yellow
  `#D6217F → #FF7A29 → #FFCB47`
  Both swirl arms full opacity.

## Notes for Claude Code

- These are single-file, dependency-free SVGs (viewBox 0 0 200 200) — no
  external fonts required to render the shapes; the "A" and "あ" glyphs use
  system font fallbacks (`SF Pro Display`/Arial, `Hiragino Sans`/`Noto Sans JP`).
- For iOS/Android app icon requirements, these will need rasterizing to PNG
  at each required size (e.g. 1024×1024 master, then 180×180, 120×120, 87×87,
  etc. for iOS; 512×512 and adaptive icon layers for Android). Ask Claude Code
  to generate these from whichever SVG you finalize on, e.g. via `rsvg-convert`
  or `sips`.
- If you land on the lightened purple-gold version as final, you likely won't
  need the other three in the shipped app — keep them in a `/design/icon-variants/`
  folder for reference rather than the production asset path.
