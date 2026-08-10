# UI and visual architecture

The UI is a physical vocabulary in two materials, implemented by `UiTheme`:
generated nine-patches, bitmap typography, amber primary keys and teal service
accents. Runtime code composes controls; generators own pixels.

Which material a thing is made of says what kind of thing it is. **Steel** —
navy enamel, brushed pinstripe, one amber hairline on the edge facing the water
— is the terminal's own signage: the gantry over the port, the key console under
it, the dark glass a lit number sits behind. **Paper** — wood, spring clip,
manifest sheets — is the paperwork: every overlay. Anything permanently over the
port is steel so it reads as structure; anything you open is paper so it reads as
something handed to you.

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
