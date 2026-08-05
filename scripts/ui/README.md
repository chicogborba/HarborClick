# UI domain

`UiTheme` is the visual and accessibility source of truth. Screen scripts
compose it; they should not invent unrelated colors, fonts, rounded boxes or
focus behavior.

The interface is made of two materials, and which one a thing is made of says
what kind of thing it is. **Steel** — navy enamel, brushed pinstripe, one amber
hairline on the edge facing the water — is the terminal's own signage: the
gantry, the key console, the glass a lit number sits behind (`gantry_style`,
`console_style`, `glass_style`, `tag_style`, the `steel` button kind). **Paper**
— wood, spring clip, manifest sheets — is the paperwork: every overlay. Anything
permanently over the port is steel; anything you open is paper. Do not mix them:
a wooden board floating over the quay reads as nothing, which is what the old
HUD was.

Entry points:

- `title_screen.gd` — profile selection.
- `responsive_shell.gd` — viewport/breakpoint layout.
- `hud.gd`, `readout.gd`, `command_rail.gd` — play HUD.
- `rate_breakdown.gd` — the factors behind the rate, opened by pressing the rate
  tag on the counter. It is the formula, not a caption for it: machines at
  catalogue rate, then milestones, fitted upgrades, capital, global upgrades,
  fog and surge — multiply the rows and you land back on `GameState.base_cps`.
  A game whose whole strategy layer is "why did that number go up" cannot only
  ever show the product.
- `shop.gd`, `route_map.gd`, `port_journal.gd`, `settings_panel.gd`,
  `prestige_dialog.gd` — overlays. The journal's EQUIPE tab is the whole shift in
  one list, which the per-person dossier cannot give.
- `npc_card.gd` — one crew member's staff badge, opened by tapping them: teal
  header, a mounted photograph, and the record printed beside it. The photo is a
  24x28 portrait from `portrait_sheet`, picked from the person's uid so it never
  changes, with the hard hat as a separate greyscale overlay `modulate` tints —
  the same trick the walking sprite uses, and for the same reason. Only people on
  foot open it: `StructureActor.is_person()`, not `is_crew()`. A crewed machine
  is still a machine, and inspecting by crew turned every reach stacker in the
  yard into a personnel card waiting to open.
- `notice_bell.gd` — every notice, collected instead of thrown. Nothing
  interrupts the port: `NotificationCoordinator` still decides what is worth
  keeping and still collapses repeats, and this lights a lamp on the gantry and
  waits. It must answer `notify_shown_finished()` the moment a notice arrives —
  nothing is being displayed, so the slot is free, and not saying so wedges the
  queue behind a banner that no longer exists.
- `hud.gd` — the gantry bolted across the top of the *world* rect, never the
  window, so an inset moves it with the port instead of leaving it spanning the
  glass. It is the only tally in the game. The berth hangs under it on its own
  tag, so a status that grows into a sentence can never move the counter; with
  more than one berth the tag also carries a lamp per berth, because otherwise a
  second and third ship are invisible until one is tapped.
- `command_rail.gd` — the console. Four keys, and above them one line that
  answers "what now?": the objective on the left, and on the right the single
  most valuable press available — rebuilding the port outranks a purchase, and a
  purchase outranks a countdown to one. That countdown is `Shop.next_purchase_eta`,
  and it exists because a wait the player cannot price is a stall.
- `readout.gd` — the tally, as a totaliser rather than a caption. The glass is a
  fixed window cut for the widest string `GameState.fmt` can return and the
  digits are right-aligned in it, so nothing moves when the number rolls over;
  the cells it has not reached carry unlit eights, which the monospace font makes
  tile against the lit number exactly. Earning lights the glass rather than
  punching the digits — no geometry moves, so it can fire on every credited box.
- `port_clock.gd` — day, hour, sky and wind, mounted into the right-hand end of
  that same gantry; `Hud.BAR_H` is the contract between the two. The dial is a
  painted sky disc that turns, not a hand on a face: it says what the light is
  doing without being read. Wind is three pips and the words live in the
  accessibility label — spelled out it cost eleven characters of the bar.
- `PortCamera.set_view_insets` — the camera has to be told what the gantry and
  the console are covering. Without it neither the gate nor the last row of
  buildings can be dragged out from under them: the camera stops at the edge of
  the terminal, not at the edge of what can be seen.
- `special_call_alert.gd` — the charter interruption.
- `minigame_board.gd` — the shell both charter games are played on; the subclass
  supplies only the middle of it. `crane_minigame.gd` is timing,
  `maze_minigame.gd` is navigation.
- `notification_coordinator.gd` — notice policy: what is routine, what collapses,
  what is kept. It has no opinion about how a notice is shown.
- `tutorial.gd`, `tutorial_spotlight.gd` — onboarding.

`FloatText` is the game's only answer to "did my tap pay?", so it is deliberately
loud: a large warm number with a thick dark outline, punched in and risen. Small
bright type over pixel art of any colour needs the outline or it disappears into
whatever is under it.

All labels that can grow must clip or wrap without increasing a phone panel's
minimum width. Use the logical Control rect for layout under viewport stretch.
A panel holding wrapped prose must not size itself from its own minimum: measure
after the layout pass, clamp to the safe area and let the content scroll — an
autowrap label measured at the wrong width reports a height of thousands of
pixels. The font is a hand-made bitmap: it has `-`, `•`, `→`, `▸` and no em dash
or middle dot, and a missing glyph prints as a hollow box. A Control laid out by
a container has its transform managed for it, so `rotation` on the control itself
is discarded — rotate a child instead.
Godot draws a few things for itself, and a tooltip is one of them: it is a popup
parented to the `Window`, not to the control that asked for it, so
`UiTheme.install_window_theme()` is the only place that reaches it. Both entry
scenes call it — the title screen on the way in, and Main as well, because
running Main directly skips the title.

Run ui_p0, a11y, contrast, notification and the capture matrix.

`RouteMap.RouteChart` draws a quantized equirectangular pixel atlas. Route data
owns geographically coherent port waypoints, including edge-wrapped Pacific
legs, so destination pins and painted trade lanes cannot drift apart.

## The title is two pages

`title_screen.gd` shows a marquee — plate, JOGAR / CONTINUAR / AJUSTES, four
corner keys, footer — and a board with the three terminals behind JOGAR. A title
has one job, which is getting the player into a terminal; the board is a detour
and should not be charged on the way in.

CONTINUAR is the whole point of the split: one key that returns a player to where
they were. Which terminal that is lives in `UserPreferences.last_profile`, not in
a save file, because the title has to answer "continue which one?" before any
profile has been loaded — and the key hides itself when that slot has since been
deleted, because an enabled CONTINUAR that starts a fresh run is the same betrayal
as a save that was not there.

The slot list scrolls. Three terminals fit a phone today and the board must not be
the thing that decides that.

## The frame is always portrait

`PortraitFrame` (autoload) clamps the window's aspect: wider than 2:3 gets
pillarboxed, taller than 2:3 keeps the extra height. `ResponsiveShell` therefore
only ever sees a portrait viewport, so there is exactly one layout and
`ResponsiveShell.PROFILE` is a constant.

There used to be a second one. A `desktop` profile handed two thirds of a wide
window to the port and the rest to a clipboard rail carrying the berth card, the
pinned objective, a port summary and the keys. The portrait clamp made it
unreachable, and it stayed in the tree for a week — tested, maintained, and
described in the roadmap as delivered, while carrying the *only* way to reach the
prestige dialog. It is deleted. Do not add a layout the game cannot open: put the
feature in the console and let the console grow.
