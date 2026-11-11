# UI domain

`UiTheme` is the visual and accessibility source of truth. Screen scripts
compose it; they should not invent unrelated colors, fonts, rounded boxes or
focus behavior.

The interface is made of two materials, and which one a thing is made of says
what kind of thing it is. **Steel** — navy enamel, brushed pinstripe, one amber
hairline on the edge facing the water — is the terminal's own signage: the
gantry, the key console, the glass a lit number sits behind (`gantry_style`,
`console_style`, `glass_style`, `tag_style`, the `steel` button kind). **Paper**
— clean manifest sheets held in an enamel frame, under a spring clip — is the
paperwork: every overlay. The frame is the HUD's own navy, so a board reads as
part of the terminal, and the sheet inside it is plain cream with no fibre.

Every board opens with the same nameplate: `UiTheme.header(title, close, icon)`
returns `{root, title, close}` — amber title on enamel, steel close key at its
right end. Do not hand-build a title row; a long title steps down to body size
by itself (`UiTheme.fit_title`, call it again after changing the text).
Cards are chunky slips with a coloured spine (amber: affordable, teal: done);
a key that is not available yet is flat paper (`ui_btn_off`), never a grey
bevelled key that competes with the amber one beside it.

Entry points:

- `title_screen.gd` — profile selection.
- `responsive_shell.gd` — viewport/breakpoint layout.
- `hud.gd`, `readout.gd`, `command_rail.gd` — play HUD.
- `level_hud.gd` — the terminal level badge (level + XP bar) under the gantry,
  and the unlock ceremony: when a level opens features, a card drops from the
  top naming them, queued one per level. Feature names map in `FEATURE_NAMES`.
  The card wraps its text (never clips it) and, from level 3 on, carries one
  rewarded offer — `level_bonus`: output x2 for 2 min (5 min every fifth level),
  shown on the last card of a queued batch and only when `AdService` would play it.
- `boost_chips.gd` — every active multiplier as a chip with its countdown: the
  luck surge and the tap combo. (The Capataz skill bar was removed: three
  cooldown keys over the port that nobody understood.)
- `build_hud.gd` — unused: construction waits were removed (a machine bought
  is a machine working). `GameState.build_times_enabled` stays false, and a
  queue left in an old save is stood up on the first frame.
- Rewarded-ad placements live where the reward is: `lucky_wheel_panel.gd`
  (`wheel_spin` when out of tokens, `wheel_double` after a cash prize),
  `minigame_board.gd` (`minigame_retry` on a loss, 6 s window),
  `offline_popup.gd` (`offline_double`), `level_hud.gd` (`level_bonus`).
  All optional, all hidden at the daily cap.
- `rate_breakdown.gd` — the factors behind the rate, opened by pressing the rate
  tag on the counter. It is the formula, not a caption for it: machines at
  catalogue rate, then milestones, fitted upgrades, capital, turmas, global
  upgrades, fog and surge — multiply the rows and you land back on
  `GameState.base_cps`. A game whose whole strategy layer is "why did that number
  go up" cannot only ever show the product. **Adding a factor to `recompute` means
  adding a row here**: a port that converted a fleet into conductors traded the
  "Melhorias" row away to buy the "Turmas" one, and a trade invisible in the
  formula did not happen anywhere the player can see.
- `shop.gd` — the purchase board. Upgrade cards carry coloured chips from
  `upgrade_chips()` — teal TEU/s, green whole port, amber tap, blue per-machine,
  purple swap, slate rail — plus a rose "ESCOLHA 1 DE 2" on exclusive pairs, and
  the effect line says "this or X, you can swap later" before the first buy.
  Chips are prebuilt in `ShopCard.set_chips` and only rewritten on change. Its DECOR. tab is the one place in the game
  that sells nothing productive: a row there carries a price before it is owned
  and an on/off switch afterwards, and the switch is the reason the tab works —
  a decoration you cannot take back off is one nobody risks buying. See
  `scripts/data/cosmetic_db.gd`.
  - **The upgrades tab is a list first, with the map one key away.** The
    transit map was the only view for a while, and on a phone it was fifty grey
    dots with half their names cut off — nobody could tell what was for sale,
    what it did or what it cost without tapping stations one by one. The list
    answers those in the order they are asked: DISPONÍVEIS (cheapest first; the
    affordable ones light up), PRÓXIMAS (nodes whose parents are all owned,
    each with the one sentence that shuts it), and COMPRADAS folded away. Every
    card carries the node's effect in words (`GameState.upgrade_preview`) — a
    kind with no effect text is a test failure in `ui_p0`.
    - **Cards are built once and moved, never rebuilt** (`_build_upgrade_cards`,
      `_refresh_upgrade_list`). Order and membership only change on a purchase or
      an unlock, the list compares a key before moving anything, and it never
      re-lays itself while a pointer is down.
    - The MAPA key swaps in `upgrade_map.gd` and its ticket, which keep their
      own rules below.
  - **A shut station says what shuts it.** `_gate_reason` turns the two ways a
    node can be blocked — an unbought prerequisite, a fleet the port has not got
    — into one sentence naming the thing to go and do. A dead control with no
    sentence is indistinguishable from a bug. The third case, a buy that refits an
    exclusive sibling out, is not a state but a price, and it is on the ticket
    before the press rather than in a dialog after it.
- `upgrade_map.gd` — the upgrade graph drawn as a transit map: one coloured line
  per trunk, one station per upgrade, depth as distance along the line. Bought
  track is solid, unbought is a dashed survey line, and a node that excludes a
  sibling is drawn as an interchange.
  - **It is one `_draw()`, not fifty Controls.** Fifty stations made of Controls
    are fifty layouts, and the tab refreshes on a timer while it is open.
    `refresh()` compares every station's state against a cache and returns without
    repainting when nothing moved.
  - **Zoom is about the anchor.** `_set_zoom` keeps whatever was under the fingers
    under them. Zooming about the origin instead throws the thing the player was
    looking at off the edge, which on a map is the difference between a control
    and a fight.
  - **A tap is a press that did not travel.** `TAP_SLOP` separates selecting a
    station from panning, and `_station_at` picks the *nearest* station rather
    than the first hit — two stations can be a lane apart at low zoom and the one
    whose circle you technically landed in is not always the one you aimed at.
- `route_map.gd`, `port_journal.gd`, `settings_panel.gd`,
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
- `wheel_button.gd` / `lucky_wheel_panel.gd`, `daily_orders_button.gd` /
  `daily_orders_panel.gd` — the two steel keys stacked under the gantry's left
  end and the paper boards they open: the Roda da Sorte and the Missões do Dia.
  Both boards fit their height a frame after their width (an autowrapped label
  measured at width 0 reports a fantasy height, which once pushed the wheel's
  board off a phone), and both open() let that settle before `pop_open`
  records the resting position. Rows are built once and rewritten in place.
- `notice_bell.gd` — the **port diary** (class name kept): a leather book on
  the gantry (`ui_diary_key.png`) that opens in a five-frame pixel animation
  (`ui_diary_open.png`, `tools/sprites/gen_diary.py`) onto two bookmarks.
  AVISOS is the notices log below. MEDALHAS is every `AchievementDB` entry as a
  struck medal (dark until earned, tap for what it asks and pays) under the
  final trophy (`ui_trophy_final.png`), lit for whoever earns them all. The
  medal grid is built once and recoloured on open.
  Every notice, collected instead of thrown. Nothing
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
- `minigame_board.gd` — the shell every minigame is played on (the two charter
  games and the X-ray scan); the subclass supplies only the middle of it and,
  through `_result_text`, the closing shout. `crane_minigame.gd` is timing,
  `maze_minigame.gd` is navigation.
- `notification_coordinator.gd` — notice policy: what is routine, what collapses,
  what is kept. It has no opinion about how a notice is shown.
- `tutorial_spotlight.gd` — Alisson on foot (the project manager and futsal
  star from the crew roster; `ui_guide_body.png` from
  `tools/sprites/gen_guide.py`, shown at 3x). He hops in from the edge, hops
  over to whatever he is talking about and stands beside it, talking out of a
  speech bubble that rides above or below him and never covers the target; the
  typed line babbles in `voice_1..10` blips. Tour steps wait for a tap or for
  the action (tap the ship 15x, open the shop, hire a docker); the veil
  swallows every press outside the highlight (`_Veil._has_point`). After the
  tour Main calls him back with `tip(id, say, target)` — the first parcel
  affordable, the first upgrade, each unlocked feature — once per profile
  (`flags.guide_tips`), no veil, gone on a tap or after 9 s, 40 s apart, never
  over an open board. Old profiles have what is already true marked seen.
  A tip names its speaker: `tip(id, say, target, who)` with `who` a key of
  `SPEAKERS` — Alisson, or Neide, the Receita Federal auditor
  (`ui_customs_body.png` from `tools/sprites/gen_customs.py`, same seven-frame
  layout; voice family `voice_rf`; she brings a rubber stamp down while she
  waits where he juggles). Tips marked `seed: false` in `Main._guide_tips` are
  never pre-marked seen, so an old profile still meets her. `dismiss_tip()`
  removes a tip at once; Main calls it whenever a board opens.
- `xray_minigame.gd` — the Receita Federal inspection on the `MinigameBoard`
  shell: the container rolls through the portal, the Creatus Security e VWI
  monitor boots, then the scan — tap the contraband (`XrayScan` rules). The
  intro is skippable and the clock only runs on the scan. `xray_panel.gd` is
  the scanner's board (buy / next inspection / inspect) and `xray_button.gd`
  its HUD key, packed into the wheel/daily column by `Main._refresh_xray_key`.

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

The screen is a photograph of the port the player is about to open, in the
port's own daylight and out of the port's own art: `gen_title.py` tiles the same
ground `GroundBaker` tiles, stacks the same eight container liveries and parks
the same machines the shop sells. Nothing on it is a second drawing of something
the game already has, which is what the version before it was.

It is allowed to be alive, and everything that moves lives in `PortActors` — one
`Node2D` carrying the backdrop's COVERED transform, so its children are placed
in *port* pixels rather than screen ones and a drifting backdrop cannot leave
them behind. On it:

- **the trolleys**, one per gantry. The booms are baked into the picture and
  what rides them is not, because a box coming off the ship, crossing the apron
  and being set down is the only thing on this screen that is the game rather
  than a picture of it. `CRANE_YS` here and in `gen_title.py` are the same three
  numbers and have to stay that way.
- **the gulls**, from the four-frame sheet the world's `Critters` use.

The rest is `modulate` or the backdrop's own rect — never a control the layout
pass owns, or a resize mid-tween parks a key off its mark. Loops wait for the
arrival fade to finish, because a looping tint running against a fade is how two
correct animations make a control flicker. With motion off the trolleys stay put
holding their boxes, which is a working terminal rather than a paused one.

The title has its own material, and it is the only screen that does. Everywhere
else a key is a 1px-edged slab because it sits on paper or on navy; here it sits
on a photograph, and only `UiTheme.title_button_style` — two pixels of ink, the
corners knocked off, rivets — survives that. The wordmark is a drawn object
rather than two Labels: extruded, ringed and rimmed in `gen_title.py` out of the
game's own glyphs, because the body font at title size *is* a caption.

Three of its drawings are not drawn by code: the crest astride the plate, the
ship at the berth in `ui_title_port`, and the berth photograph on each terminal
slot. They come from `tools/sprites/pixellab` and are used at 1:1 — a
non-integer scale would sand the pixels off the one asset class that was worth
generating. The slot cards are sized around the 64px photograph rather than the
other way round.

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
