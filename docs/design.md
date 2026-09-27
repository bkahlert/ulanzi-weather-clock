# Design

How the clock is put together: the show and its two designs, the sprite wipes, the weather
scenes, the buttons and the optional departures board. Written from the inside; the
[README](../README.md) has the short version.

## One app, two designs

One app, [`clock.ax`](../scripts/clock.ax), loops through four phases in one of two designs.
The middle button switches between them; the choice (`design`) is a setting and survives a
reboot.

### Muted

The default. The time `HH:MM` stands at the right on every page, colon steady; everything is
drawn at `dimming` % (65), on top of which the light sensor still works.

| Phase | Default | What |
|---|---|---|
| Calendar | 12 s | the calendar card at the backdrop brightness (`backdrop`, 45 %) with the day at the left |
| Fade | 3 s (`fade`) | the left block cross-fades into the weather, slowly enough to escape the eye; the time stands through it |
| Weather | 8 s | the animated scene dimmed to the same backdrop over columns 0–13, each motion at its own pace (clouds drift, rain falls, the sun and the bolt stand); the temperature full-size on top of it where the card has its day, the degree sign a single pixel |
| Fade | 3 s | back to the calendar |

### Classic

The look before it, at full brightness.

| Phase | Default | What |
|---|---|---|
| Time | 12 s | the calendar card, `HH:MM` from column 12, colon blinking — the look of the built-in Time app |
| Wipe to the weather | a sprite, 3.2–4.5 s | moves in from the left; the weather appears behind it, the time is still ahead of it |
| Weather | 8 s | the animated scene bright at the left, the temperature at the right |
| Wipe to the time | another sprite, 3.2–4.5 s | moves in from the left; the time appears behind it |

### Settings

Everything in the Default column is a setting of the script, changed in the web UI (Apps tab,
⚙ next to Clock): the two page lengths, who carries each wipe (`random`, a sprite's name to
pin it, or `none` for a hard cut), the wipe pace (ms per pixel, 90 as in the original GIF) and
the weather scene's animation step (ms, 250). A name the roster no longer has counts as
`random`.

Saving restarts the app with the new values; the firmware plays its transition once while
doing so, a fade to black and back with `Fade`. `apply` reports values that differ from the
header and leaves them alone; `apply --reset-config` writes the header defaults back.

The script plans a cycle - its two sprites, hence its length - when the app is shown and
again at each cycle's end, never in between, so a running cycle keeps its timing.
`duration()` is the first cycle's length: the firmware asks once when the rotation picks the
app and, the clock being the only app, never again.

### Why one app draws both pages

Built-in transitions are a fixed list of whole-frame effects and cannot carry a sprite, and
two apps never see each other's pixels, so whoever draws the reveal has to draw both pages.

The calendar card and the time therefore mirror the built-in Time app (which is switched off)
and read `time24h`, `timeLeadingZero`, `timeSeparatorMode`, `textColor` / `timeColor` and the
three calendar colours from the device settings. Seconds, AM/PM and the weekday bar are not
drawn.

## Wipes

### A wipe frame

Left of the sprite the arriving page, right of it the leaving page, both drawn by the
firmware and cut at the sprite's edges pixel by pixel.

Inside the sprite's box the script draws both pages itself, glyphs included, and picks per
pixel: the sprite where it is opaque; where it is transparent, the page the pixel's cluster
names. Transparent pixels form clusters (4-neighbour). A cluster touching the sprite's left
edge shows the arriving page, one touching its right edge the leaving page, and the clusters
in between show the arriving page dimmed, evenly from left to right (one cluster: half; two:
two thirds and one third), over black.

The gap between Mario and Luigi is such a cluster, and so is the one between Blinky and
Pac-Man; the invader's tentacles leave six, and the new page glints through them in six
shades. Hence the rule for any wipe sprite: every frame must cut the panel in all eight rows,
or the two edge clusters merge into one and the rule has nothing to work with;
[`sprites/extract`](../sprites/extract) refuses such a sprite.

A sprite pixel may also be translucent - a palette value `0xAARRGGBB`, `AA` its opacity in
60ths - and is then its colour blended over the arriving page. KITT's trail is three such
columns at 45, 30 and 15, the beam's two at 30 and 15.

### The roster

Nine sprites: Mario and Luigi running (16 px, 4.4 s), Blinky chasing Pac-Man (17 px, 4.5 s;
Pac-Man's mouth opens onto the page he leaves), the Space Invaders squid in its two arcade
poses, a light beam (3 px, 3.2 s), Yoshi walking, Sonic running, a Lemming walking, KITT's
scanner (4 px, 3.3 s; a rainbow column with a translucent trail fading out behind it over the
page it reveals) and a Metroid with wiggling fangs - the 8 px ones take 3.7 s. By default
every wipe draws one of them at random, never the same one twice in a row, so the cycle's
length varies with the two widths.

Kirby left the roster: the Hub GIF is seven rows tall and a row-doubled head looked
stretched, and the cluster rule needs eight rows anyway.

### Why the sprites are pixel strings

`icon()` draws 8×8 only and paints GIF black as black (see the tripwire in
[operations.md](operations.md)), so anything that moves over other content is pixel data in
the script. All sprites live in the one `sprites` module returning the cast and the names: a
module compiles once at boot with the heap empty, and it is one module rather than one per
sprite because the apps listing crashed the clock at 21 scripts (see
[memory.md](memory.md)).

### How sprites/extract makes them

Four sprites are cut from the GIFs in [`sprites/`](../sprites/): the six-frame run cycle of
the pair from [`mario-luigi.gif`](../sprites/mario-luigi.gif), one frame per pixel moved;
Yoshi's five poses from frames 0–20 of [`yoshi.gif`](../sprites/yoshi.gif), anchored at his
front and played at the GIF's 330 ms; and [`sonicrun.gif`](../sprites/sonicrun.gif) and
[`lemming.gif`](../sprites/lemming.gif) whole, at their own timing, blank frames dropped and,
for Sonic, the two near-black blues of his outline cut.

The other five are drawn from rows of palette letters or geometry: Pac-Man's mouth is a wedge
cut from the 8×8 disc, the invader's eyes are an opaque dark grey so the pages do not shine
through them, KITT's hues are the Hub scanner's with the trail computed as opacities.

The generator writes each transparent pixel's cluster class into the frame as a digit and the
classes' opacities per frame. The heap shapes the module too: every sprite but KITT and the
beam draws its colours from one shared palette (a letter and four bytes per colour however
many sprites use it; 39 of the 52 letters are taken, digits being the classes), a sprite's
frames are one string indexed by frame, and opacities and frame timings (10 ms units) are
`bytes`. Near-black pixels of a dithered GIF can be declared transparent, and single colours
cut (Sonic's dark fringe, the two blues of his outline).

A new wipe sprite is a GIF or a few rows in `sprites/extract` and an entry in its cast. The
generator writes the module and the `toWeather` / `toTime` options of the header (the cast's
order is the header's), and refuses when the palette would need a 53rd colour - merge colours
or give the sprite its own palette, as KITT has.

```bash
sprites/extract --write   # writes scripts/sprites.ax and the header options
art/generate --write      # writes scripts/art.ax and the marked block in scripts/weather.ax
```

## Modules

The show is one app and its modules. [`clock.ax`](../scripts/clock.ax) holds the settings and
wires the modules together, nothing else. [`cycle`](../scripts/cycle.ax) runs the four
phases, the random draw, the button jumps and the demo; [`timepage`](../scripts/timepage.ax)
draws the calendar card and the time; [`weather`](../scripts/weather.ax) fetches the weather
and draws its page from the [`art`](../scripts/art.ax) elements; [`wipes`](../scripts/wipes.ax)
composes a wipe frame from the [`sprites`](../scripts/sprites.ax); and
[`targets`](../scripts/targets.ax) is where a page draws: the panel through the firmware, or
the script's own pixels inside a sprite's box.

Each module returns a class or a map; the app instantiates the classes in `init()` and hands
the page drawers to the wipe compositor. The split is not taste but the heap rules in
[memory.md](memory.md): the firmware compiles a script's whole source in one contiguous block,
recompiles the app on every settings save, and keeps 24 KB out of reach while it does.

The built-in Temperature, Humidity, Battery and Date apps are switched off in
[`apps.json`](../apps.json). The TC001's SHT31 sits next to the LED matrix and reads several
degrees high; no offset tracked an analogue thermometer, so the reading is not shown. The I²C
bus stays on, so `GET /api/v1/device` still reports it.

## Weather

### The fetch

Fetch and colour ramp in [`weather.ax`](../scripts/weather.ax) come from the Hub script
[fGEhP0cZZd6E](https://awtrix.de/flow/fGEhP0cZZd6E) v3.6 by Hank_the_Tank: Open-Meteo, no
API key, the answer streamed and parsed with regular expressions to fit the script heap
(`find` on `"current":`, 300-byte window; only the `current` block is read). The coordinates
are the `lat` / `lon` settings (Berlin by default): set them in the web UI, or change the
header defaults and run `apply --reset-config`.

### The page

| Columns | Rows | What |
|---|---|---|
| 0–15 | 0–7 | the scene for the current WMO weather code, drawn by the script (below) |
| 17–31 | 2–6 | temperature, centred, coloured by the Hub script's temperature ramp |
| 31 | 0 | red when the last fetch is more than 20 minutes old |

### The elements

The elements of a scene are built by [`art/generate`](../art/generate) and written to the
`art` module as rows of palette letters, which the weather module copies into itself. The sun
is a 5×5 disc with a ring of eight aura pixels - beside its four sides and at its four
corners - in two dim shades of its yellow (55 % and 30 %), kept as three frames (no ring,
faint, bright). The moon is a disc with a larger disc taken out. Every cloud is the
silhouette of the Hub icon [cloud](https://awtrix.de/icons/cloud) (one bump, rounded
underneath, the lowest pixel of each column in the shade colour): stretched to ten columns
and tinted for the cloud, storm, flash and fog, at its own seven for the dark cloud behind the
overcast one.

Change a shape in `art/generate`, run it to check [`preview.png`](../art/preview.png), then
`art/generate --write` and `apply`.

### The motion

Only the motion is computed in the weather module, one step per `anim` ms (four a second by
default): the sun's ring breathes dark, faint, bright, faint at two steps per state (a 2 s
cycle), the partly-cloudy cloud comes in from the right, passes in front of the sun and leaves
left, drops and flakes cycle through the four rows under the cloud, lightning strikes every
eighth step with a white flash, mist lines drift. The scene is cut at column 15, never at the
sun.

| Code | Day | Night |
|---|---|---|
| 0–1 clear | sun with its breathing ring | crescent moon, twinkling stars |
| 2 partly cloudy | sun, a cloud passing in front | moon, a cloud passing in front |
| 3 overcast | a small dark cloud up right, peeking in from the edge, the big cloud low left, drifting against each other | same |
| 45–48 fog | grey cloud over two drifting mist lines | same |
| 51–57 drizzle | cloud, three short dim drops | same |
| 61–67 rain | cloud, three falling drops | same |
| 71–77, 85–86 snow | cloud, three wobbling flakes | same |
| 80–82 showers | sun peeking behind a cloud, drops | moon peeking behind a cloud, drops |
| 95+ thunderstorm | dark cloud, rain, lightning and flash | same |

### The muted scene

In the muted design the scene is cut at column 13, and each motion has its own pace: clouds,
mist, sway and stars one step per 1.5 s, rain one row per 0.6 s, snow per 1.2 s. The sun
stands with its bright ring. Thunder keeps its bolt at the cloud's left edge, clear of a
two-character temperature (a three-character one covers its top pixel), and brightens the
cloud for 0.3 s every 10 s in place of the flash.

The scene is drawn as a backdrop at the `backdrop` brightness (45 % by default; the weather
module keeps a dimmed copy of the palette, rebuilt when the setting or the design changes)
with the temperature full-size over it where the calendar card has its day - rows 2–6,
centred on columns 3–11, so the cross-fade turns the one into the other. The degree sign is a
single pixel beside the digits' top row (Fahrenheit shows an F while the label has two
characters, the pixel beyond that), and nothing passes column 13. The calendar card is drawn
at the same backdrop brightness, its day as set, so the fade swaps two blocks of one weight.

### The classic scene

In the classic design the scene is bright and 16 columns wide, and the temperature with its
unit is centred over columns 17–31: the degree sign a 2×2 block one column after the digits
on rows 2–3, drawn by the script (Fahrenheit the font's F).

> **⚠️ Tripwire — the firmware draws ° as a 3×3 ring.** Its small font takes ASCII from
> `awtrix.bdf`, where the degree sign is a 2×2 block, but every character past 0x7E - the degree
> sign among them - from `MatrixChunky6.bdf` (`scripts/gen_font.py` in the firmware repository):
> a 3×3 ring four columns wide. Both pages draw their degree mark themselves and never pass °
> to `text()`; the art font has no ° either, so the wipe compositor and the panel agree.

## Buttons

### Next and previous

**Right** moves on to the clock's next page, **left** back to the previous one, each brought
in by its transition: on the calendar page right starts the fade or wipe to the weather, on
the weather page left starts the one to the calendar. A left or right press moves the cycle's
clock, so the sprites planned for the cycle stay.

The two pages are each other's neighbours both ways, so past the last page or before the
first the cycle wraps - with two pages either button flips to the other page - and the press
is handed back to the firmware, whose own navigation (previous and next app) moves on to
another app once the rotation has one; with the clock alone it does nothing more.

### The design switch

**Select** switches between the muted and the classic design, stores the choice and starts
the cycle over; the display switch is the web UI's (or Home Assistant's) now.

### The demo

**Hold select** for 600 ms and the clock runs a demo: every weather scene in turn - clear day
and night, partly cloudy in both, overcast, fog, drizzle, rain, snow, showers, thunder - about
five seconds each with a temperature of its own (a negative one and a three-character one
among them), on whichever design is showing, with hard cuts between scenes. After one lap of
about a minute the live weather and the cycle come back by themselves; a second hold ends it
early.

The firmware only reports a hold on a press the script has taken, so the design switch
happens on the release of a short press rather than on the press itself.

> **⚠️ Tripwire — the hold needs AWTRIX NG 1.1.2 or later.** Firmware 1.1.1 knows only
> `on_button(btn)` and calls it on the press itself: select switches the design the moment the
> button goes down and no hold is ever reported, however long it is held. The device log says
> nothing about it; `GET /api/v1/version` does. `./apply` warns on an older firmware, and the
> upgrade is one request, see [operations.md](operations.md#firmware-upgrade).

## Departures

[`departures.ax`](../scripts/departures.ax) is a second app, in the repository but not on
the clock: `departures` is listed in `disabled` in [`apps.json`](../apps.json), and `apply`
removes a switched-off script app from the clock instead of installing it, because loaded and
idle it held 6.4 KB of the Berry heap that the wipe sprites needed (see
[memory.md](memory.md)). To enable it, move `departures` to `order` and run `apply`, which
installs it.

It scrolls the next departures at the stop of its `stop` setting (S+U Alexanderplatz by
default) once per turn, line label coloured by product (S-Bahn green, U-Bahn blue, tram red,
bus purple), minutes computed from the clock's own time. Data from `v6.bvg.transport.rest`,
no key. Settings (stop id, count, minutes to walk, refresh, product toggles) are `# @config`
lines in the script. Another stop: look up its id with
`https://v6.bvg.transport.rest/locations?query=<name>&results=3`.
