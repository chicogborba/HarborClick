"""16x16 interface icons, outlined, for the HUD the release plan builds (D2).

The 12x12 sheet in `gen_ui.py` stays for the controls that already use it; this
one is for everything new — level, skills, boosts, ads, build queue — where an
icon has to be read at arm's length on a phone, alone, with no label beside it.

Each icon is authored as a 14x14 character map (the outline adds the 16th
pixel all round), which keeps the drawing reviewable in a diff: you can see the
picture in the source. Letters index `INK`.

`ui_icons16.png` is a horizontal strip in `ORDER`; `UiTheme.Icon16` mirrors it.
"""
import palette as P
from common import new_img, outline, px, save, sheet

GOLD = P.ramp((246, 196, 64), 5, hue_shift=16.0, dark=0.45, light=0.7)
STEEL = P.ramp((122, 130, 150), 5, hue_shift=12.0)
RED = P.ramp((222, 70, 60), 5, hue_shift=14.0)
BLUE = P.ramp((70, 130, 214), 5, hue_shift=16.0)
GREEN = P.ramp((92, 176, 84), 5, hue_shift=14.0)
TEAL = P.ramp((60, 170, 160), 5, hue_shift=14.0)
ORANGE = P.ramp((240, 140, 50), 5, hue_shift=14.0)
PAPER = (248, 240, 216, 255)
WOOD = P.ramp((150, 104, 62), 5, hue_shift=12.0)
SKIN = (236, 190, 152, 255)
OUT = (38, 30, 44, 255)

INK = {
    "g": GOLD[2], "G": GOLD[3], "Y": GOLD[4], "d": GOLD[1], "D": GOLD[0],
    "s": STEEL[2], "S": STEEL[3], "W": STEEL[4], "k": STEEL[1], "K": STEEL[0],
    "r": RED[2], "R": RED[3], "m": RED[1],
    "b": BLUE[2], "B": BLUE[3], "n": BLUE[1],
    "e": GREEN[2], "E": GREEN[3], "f": GREEN[1],
    "t": TEAL[2], "T": TEAL[3], "u": TEAL[1],
    "o": ORANGE[2], "O": ORANGE[3], "p": ORANGE[1],
    "w": PAPER, "c": WOOD[2], "C": WOOD[3], "x": WOOD[1],
    "h": SKIN, "#": OUT,
}

ART = {
    # Terminal level: a gold star on a blue shield.
    "level": [
        "..bbbbbbbbbb..",
        ".bBBBBBBBBBBb.",
        ".bBBBBYYBBBBb.",
        ".bBBBBYYBBBBb.",
        ".bBYYYYYYYYBb.",
        ".bBBYYGGYYBBb.",
        ".bBBBYGGYBBBb.",
        ".bbBYYGGYYBbb.",
        ".bbBYYbbYYBbb.",
        "..bbYbbbbYbb..",
        "..nbbbbbbbbn..",
        "...nnbbbbnn...",
        ".....nbbn.....",
        "......nn......",
    ],
    # XP: an upward chevron pair.
    "xp": [
        "......EE......",
        ".....EEEE.....",
        "....EEeeEE....",
        "...EEe..eEE...",
        "..EEe....eEE..",
        ".ffe......eff.",
        "......EE......",
        ".....EEEE.....",
        "....EEeeEE....",
        "...EEe..eEE...",
        "..EEe....eEE..",
        ".ffe......eff.",
        "..............",
        "..............",
    ],
    # Rewarded ad: a film frame with a play triangle.
    "ad": [
        "KKKKKKKKKKKKKK",
        "KwKKwKKwKKwKKK",
        "KKKKKKKKKKKKKK",
        "KssssssssssssK",
        "KsssYYsssssssK",
        "KsssYYYYsssssK",
        "KsssYYYYYYsssK",
        "KsssYYYYYYsssK",
        "KsssYYYYsssssK",
        "KsssYYsssssssK",
        "KssssssssssssK",
        "KKKKKKKKKKKKKK",
        "KwKKwKKwKKwKKK",
        "KKKKKKKKKKKKKK",
    ],
    # Boost: a lightning bolt.
    "boost": [
        ".......YYYY...",
        "......YYYG....",
        ".....YYYG.....",
        "....YYYG......",
        "...YYYG.......",
        "..YYYYYYYY....",
        "..GGGGYYYG....",
        "......YYG.....",
        ".....YYG......",
        "....YYG.......",
        "...YYG........",
        "..YYd.........",
        "..Yd..........",
        "..d...........",
    ],
    # Combo: a flame.
    "combo": [
        "......o.......",
        ".....oO.......",
        ".....OO...o...",
        "....oOOo..O...",
        "....OOOO.oO...",
        "...oOOOOoOOo..",
        "...OOYYOOOOO..",
        "..oOYYYYOOOOo.",
        "..OOYYYYYOOOO.",
        "..OOYwwYYYOOO.",
        "..pOYwwwYYOOp.",
        "...pOYwwYOOp..",
        "....ppOOOpp...",
        "......ppp.....",
    ],
    # Build queue: a hammer.
    "build": [
        "..SSSSSSS.....",
        ".SWWWWWWWS....",
        ".SsssssssSk...",
        ".kkkksskkkk...",
        "....kCCk......",
        ".....CCx......",
        ".....CCx......",
        ".....CCx......",
        ".....CCx......",
        ".....CCx......",
        ".....CCx......",
        ".....CCx......",
        ".....xxx......",
        "..............",
    ],
    # Skill: Turno Extra — a clock face with a bolt across it.
    "skill_overtime": [
        "....ssssss....",
        "..ssWWWWWWss..",
        ".sWWWWkWWWWWs.",
        ".sWWWWkWWYYWs.",
        "sWWWWWkWYYWWWs",
        "sWWWWWkYYWWWWs",
        "sWWWWWYYYYYWWs",
        "sWWWWWkkYYWWWs",
        "sWWWWWWYYWWWWs",
        ".sWWWWYYWWWWs.",
        ".sWWWYYWWWWWs.",
        "..ssWYWWWWss..",
        "....ssssss....",
        "..............",
    ],
    # Skill: Mutirão — three hard hats in a row.
    "skill_mutirao": [
        "..............",
        ".....YYYY.....",
        "....YYYYYY....",
        "...GGGGGGGG...",
        "....hhhhhh....",
        ".YYY.hhhh.YYY.",
        "YYYYY.oo.YYYYY",
        "GGGGGooooGGGGG",
        ".hhh.oooo.hhh.",
        ".hhh.oooo.hhh.",
        ".ooo.oooo.ooo.",
        "ooooooooooooo.",
        "ooooooooooooo.",
        "pppppppppppp..",
    ],
    # Skill: Prático a Bordo — a ship's wheel.
    "skill_pilot": [
        "......cc......",
        "..c...cc...c..",
        "...c.CCCC.c...",
        "...CCC..CCC...",
        "..CC.c..c.CC..",
        ".cC...cc...Cc.",
        "ccC..cGGc..Ccc",
        "ccC..cGGc..Ccc",
        ".cC...cc...Cc.",
        "..CC.c..c.CC..",
        "...CCC..CCC...",
        "...c.CCCC.c...",
        "..c...cc...c..",
        "......cc......",
    ],
    # Album: an open book with a ship stamp.
    "album": [
        "..............",
        ".bbbbbb.bbbbbb",
        "bwwwwwwbwwwwwb",
        "bwwwwwwbwwwwwb",
        "bwkkkwwbwwrwwb",
        "bwwwwwwbwrrrwb",
        "bwkkkkwbwwrwwb",
        "bwwwwwwbwnnnwb",
        "bwkkkwwbnnnnnb",
        "bwwwwwwbwnnnwb",
        "bwwwwwwbwwwwwb",
        "nbbbbbbnbbbbbn",
        ".nnnnnn.nnnnn.",
        "..............",
    ],
    # Mission: a clipboard with ticks.
    "mission": [
        "....kSSSSk....",
        ".cccSWWWWSccc.",
        ".cCCkkkkkkCCx.",
        ".cwwwwwwwwwwx.",
        ".cwEwwkkkkwwx.",
        ".cEwwwwwwwwwx.",
        ".cwwwwwwwwwwx.",
        ".cwEwwkkkkwwx.",
        ".cEwwwwwwwwwx.",
        ".cwwwwwwwwwwx.",
        ".cwsswkkkkwwx.",
        ".cwsswwwwwwwx.",
        ".cwwwwwwwwwwx.",
        ".xxxxxxxxxxxx.",
    ],
    # Wheel token: a striped chip.
    "token": [
        "....rrrrrr....",
        "..rrwwRRwwrr..",
        ".rwwRRRRRRwwr.",
        ".rwRRRRRRRRwr.",
        "rwRRRwwwwRRRwr",
        "rRRRwwYYwwRRRr",
        "rRRRwYYYYwRRRr",
        "rRRRwYYYYwRRRr",
        "rRRRwwYYwwRRRr",
        "rwRRRwwwwRRRwr",
        ".mwRRRRRRRRwm.",
        ".mwwRRRRRRwwm.",
        "..mmwwRRwwmm..",
        "....mmmmmm....",
    ],
    # Tap: a pointing hand.
    "tap": [
        ".....hh.......",
        "....hhhh......",
        "....hhhh......",
        "....hhhh......",
        "....hhhhhh....",
        "....hhhhhhhh..",
        ".hh.hhhhhhhhh.",
        ".hhhhhhhhhhhh.",
        ".hhhhhhhhhhhh.",
        "..hhhhhhhhhhh.",
        "...hhhhhhhhh..",
        "....hhhhhhhh..",
        "....oooooooo..",
        "....pppppppp..",
    ],
    # Ship, bow up.
    "ship": [
        "......bb......",
        ".....bBBb.....",
        "....bBwwBb....",
        "....bwwwwb....",
        "...bBrrooBb...",
        "...bBrrooBb...",
        "...bBeebbBb...",
        "...bBeebbBb...",
        "...bBoorrBb...",
        "...bBoorrBb...",
        "...bBwwwwBb...",
        "...bBwkkwBb...",
        "...nbbbbbbn...",
        "....nnnnnn....",
    ],
    # Container (TEU).
    "teu": [
        "..............",
        "..............",
        "oooooooooooooo",
        "oOOOOOOOOOOOOo",
        "oOpOpOpOpOpOOo",
        "oOpOpOpOpOpOOo",
        "oOpOpOpOpOpOOo",
        "oOpOpOpOpOpOOo",
        "oOpOpOpOpOpOOo",
        "oOOOOOOOOOOOOo",
        "pppppppppppppp",
        "pp..........pp",
        "..............",
        "..............",
    ],
    # Gear (settings).
    "gear": [
        "......ss......",
        "..ss.sSSs.ss..",
        "..sSssSSssSs..",
        "...sSSSSSSs...",
        ".ssSSkkkkSSss.",
        "sSSSk....kSSSs",
        "sSSSk....kSSSs",
        "sSSSk....kSSSs",
        "sSSSk....kSSSs",
        ".ssSSkkkkSSss.",
        "...sSSSSSSs...",
        "..sSssSSssSs..",
        "..kk.sSSs.kk..",
        "......kk......",
    ],
}
ORDER = ["level", "xp", "ad", "boost", "combo", "build", "skill_overtime",
         "skill_mutirao", "skill_pilot", "album", "mission", "token", "tap",
         "ship", "teu", "gear"]


def icon(name):
    rows = ART[name]
    assert len(rows) == 14 and all(len(r) == 14 for r in rows), name
    img = new_img(16, 16)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px(img, x + 1, y + 1, INK[ch])
    return outline(img, OUT)


def gen_icons16():
    save(sheet([icon(n) for n in ORDER]), "ui_icons16")


if __name__ == "__main__":
    print("icons16:")
    gen_icons16()
