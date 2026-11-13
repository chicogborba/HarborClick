# UI and visual architecture

The UI is a physical vocabulary in three materials, implemented by `UiTheme`:
generated nine-patches, bitmap typography, amber primary keys and teal service
accents. Runtime code composes controls; generators own pixels.

Which material a thing is made of says what kind of thing it is. **Steel** —
hull-green enamel with a brushed pinstripe — is the terminal's own signage: the
gantry over the port, the key console under it, the dark glass a lit number sits
behind. **Container** is every overlay: a board is the end wall of a shipping
container, corrugated steel painted in one of five liveries
(`UiTheme.board_style(content, tone)`: `rust` shop, `sea` ports and minigames,
`green` missions and levels, `steel` settings and readouts, `gold` wheel and
rebuild), with a corner casting in each corner and a cream manifest sheet sunk
into it, hanging from a crane spreader. `header()` paints the nameplate in the
livery the board was just built with. On the sheet, cards are cargo labels
(cream stickers, brown edge), items stand in a sky-blue window, and the price is
a moulded green key — green means "this spends cargo" and nothing else is green.
**Leather** is the third and the rarest: the logbook — only the two diaries are
bound in it.

The equipment tab of the shop is a shelf, not a ledger: `ShopCard.tile` lays a
card out upright (machine, name, yield, price key) and the tab is a grid of
them, two abreast on a phone and more on a wide window. Every other list keeps
the card lying down.

## Motion

`UiTheme` says what a thing is made of; `UiMotion` (`scripts/ui/ui_motion.gd`)
says how it behaves. One vocabulary, applied centrally so no board opts in:

- **A board is racked into view** (`UiTheme.pop_open` / `pop_close`): it rises
  from under the screen and overshoots, and its nameplate, tabs and visible
  rows arrive one after another (`cascade`).
- **The port goes out of focus behind it** (`dress_scrim`, `ui_scrim.gdshader`):
  a pixel mosaic, desaturated toward dusk, whose strength rides the scrim's own
  alpha so it grows with the existing fade.
- **Every key sinks and springs** (`wire_press`, hooked in `style_button`,
  `style_tab`, `style_segment`).
- **Every amber and green key shares one gloss** (`sheen`, `ui_sheen.gdshader`): a single
  screen-space sweep on one clock, not a blink per key.
- **Lists deal in on a tab change** (`Shop._deal_tab`), and the rate board's
  factors fill as log-scale bars in formula order (`RateBreakdown.RateBar`).
- **The port is seen through a lens** (`lens.gdshader`, `Main._build_lens`): a
  banded, dithered vignette between the world and the HUD.

Two rules: nothing waits on motion (state changes first, "movimento reduzido"
and headless make every call a no-op), and the layout always wins (a slide that
finds its control somewhere other than where it last put it adopts the new
place). `tools/capture/motion.tscn -- shop` writes a film strip of an opening,
which is the only way to review any of this without watching it.

A book still comes up shut and its cover swings open (`BookFx`). Each gesture
has one sound file cut to the same clock as its tween. See
`scripts/ui/README.md` for the contracts.

## Entry points

- `title_screen.gd` — pixel panorama, logo and three profile cards.
- `responsive_shell.gd` — portrait/landscape arrangement.
- `hud.gd` and `command_rail.gd` — always-visible play state: the gantry across
  the top of the port and the console across the bottom of it. `Hud.BAR_H` is the
  gantry's height and the contract `port_clock.gd` mounts its dial against;
  `PortCamera.set_view_insets` is how the camera is told what the two panels are
  covering, so the port can still be scrolled out from under them.
- `shop.gd`, `route_map.gd`, `port_journal.gd`, `settings_panel.gd` and
  `prestige_dialog.gd` — board overlays.
- `ui_theme.gd` — every shared surface, font, icon and accessibility helper.

## Generated assets

Edit `tools/sprites/gen_*.py`, never the resulting PNG directly. The new title
panorama is `tools/sprites/gen_title.py` → `assets/sprites/ui_title_port.png`.
Nearest-neighbour filtering and integer font sizes are mandatory.

## Responsive contract

The logical root rect, not the OS window pixels, drives layout. Panels must fit
320×568 through 1920×1080. The capture harness resizes the real scene and fails
when a panel leaves the viewport.

Godot uses fractional content scaling with nearest-neighbour texture filtering.
This lets the logical viewport expand to the full browser canvas on phones
instead of centring the largest integer-multiple rectangle over black gutters.

## Live panels must not rebuild themselves

A panel that answers `EventBus.teus_changed` by rebuilding its cards rebuilds
them **every frame**: `GameState._process` credits income and emits on each one.
A `Button` only emits `pressed` when the press and the release land on the same
node, so a card freed between the two swallows the tap — silently, and forever.
That is what made buying a route impossible for any port with production, while
the data suite stayed green because it never touched the panel.

The rule, and `shop.gd` and `route_map.gd` both follow it now: **build the
controls once, rewrite their contents in place, and throttle the rewrite.** The
signal sets a dirty flag; `_process` acts on it at most a few times a second.
`tests/route_ui_test_runner.gd` pushes a real press and release through the
viewport, frames apart, on a port that is earning the whole time.

Two mechanical notes that cost real time here:

- `Viewport.push_input(event, true)` — the second argument is `in_local_coords`,
  and without it a synthetic click on the root Window is transformed into
  nowhere and picks no control, which looks exactly like a broken button.
- A `ScrollContainer` does not take its scrollbar's width out of the child when
  horizontal scrolling is disabled; the child is stretched to the full rect and
  its last pixels sit under the bar. Reserve the gutter with a
  `MarginContainer` rather than trusting the container's arithmetic.

## Language

All display text comes from `Loc.t()`; see the **Idiomas** section of the
README. Controls built once and refreshed in place must also handle
`Loc.language_changed` — either by re-applying their strings or, for a board
opened by hand and never refreshed per frame, by rebuilding wholesale
(`SettingsPanel._build_body`). A rebuild triggered from inside a control's own
`pressed` handler is deferred to the end of the frame.

Assertions in tests must compare against `Loc.t(...)`, never against a literal:
a test that expects `"FIXADA:"` only passes on a machine whose device language
happens to be Brazilian Portuguese.

## Accessibility contract

- Every actionable control has an accessibility name.
- Focus is visible and restored when an overlay closes.
- Functional text combinations clear WCAG AA in the contrast suite.
- Touch targets use the shared `UiTheme` controls.

Run ui_p0, a11y, contrast, notification and the capture matrix after UI work.

## Boards that are not containers

Three boards deliberately break the container material, because they are a
different kind of object:

- **Missões do Dia** (`DailyOrdersPanel`) is the foreman's own list: a clipboard
  with ruled paper, pen-drawn boxes, a highlighter over whatever is ready and a
  tick the player makes. The row is the key — claiming *is* ticking the box.
  Everything hand-made is drawn in whole pixels from a seed (`stroke`,
  `wobble`), so it never shimmers between frames.
- **Passe do Porto** (`LevelRoadmap`) is the level as a pass: a horizontal
  track of thirty tiers, each with a prize collected by hand.
  `TerminalLevel.reward_for` decides the prize, `TerminalLevelService.claim`
  pays it, and the level badge on the HUD lights a pip while one is waiting.
  Features and cosmetics still open by themselves on reaching the level.
- **The logbook** (`NoticeBell`, `BookFx`) has one height whatever page it is
  open at, and its cover and leaves turn in perspective (`BookFx._Flap`): the
  free edge grows as it lifts and throws a shadow on the page. Shutting plays
  the cover back before the book drops.

## Land is built, not bought

Paying for a parcel starts works (`GameState.land_works`, minutes per parcel in
`LandDB.BUILD_MINUTES`, 5 for the first). The parcel joins `GameState.land` —
and `land_bought` fires — when they end; time away counts, and the `land_skip`
rewarded ad finishes them. `LandWorksSite` shows the works in the yard (the
asphalt laid so far is the progress) and the shop's land tab carries the clock
and the skip key. The X-ray scanner stands on the second parcel
(`LandDB.SCANNER_PARCEL`): it appears abandoned when that ground is paved, on a
band of its own with a loop off the road (`XrayStation._Loop`).
