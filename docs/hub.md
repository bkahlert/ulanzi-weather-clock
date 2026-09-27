# The awtrix.de flow

The clock's flow on the [AWTRIX Hub](https://awtrix.de/search?platform=awtrixng), kept here
so that an update is a paste. The Hub carries one script per flow and cannot hold modules,
so the flow is the app for finding and reading, and the installation goes through the
[release bundle](https://github.com/bkahlert/ulanzi-weather-clock/releases).

## Fields

| Field | Value |
|---|---|
| Title | Ulanzi Weather Clock |
| Platform | AWTRIX NG |
| Topic | Clock |
| Script | [`scripts/clock.ax`](../scripts/clock.ax) as it is in the release |
| Cover | [`preview/muted.gif`](../preview/muted.gif); [`preview/classic.gif`](../preview/classic.gif) as a second image if the form takes one |
| Icons | none |

## Description

Time, calendar and an animated weather scene in two designs. **Muted:** the time stands at
the right while calendar and weather cross-fade at the left over a dimmed scene. **Classic:**
calendar and time, then the weather, each wiped in by a sprite - Mario and Luigi, Blinky
chasing Pac-Man, a Space Invader, a light beam, Yoshi, Sonic, a Lemming, KITT's scanner, a
Metroid. A scene for every WMO weather code from Open-Meteo, no API key. The middle button
switches the design; hold it for a demo of every scene. No MQTT, no home automation, no
cloud account: the panel fetches the weather itself.

**Installation - read this first.** The clock is eight scripts: this app and seven modules
(art, cycle, sprites, targets, timepage, weather, wipes). The Hub carries one script per
flow, so *Send to AWTRIX* installs the app alone and the panel shows `ERR:` until the
modules are there. Install the whole clock in one step instead:

1. Download `ulanzi-weather-clock-<version>.zip` from
   https://github.com/bkahlert/ulanzi-weather-clock/releases
2. Web UI → **System → Restore backup** → the zip. It adds the eight scripts and touches
   nothing else on the panel.
3. Reboot. Then **Apps → ⚙ Clock**: set your latitude and longitude. Switch the built-in
   Time app off if you like.

An update is the same three steps with the next bundle.

**Requirements.** AWTRIX NG 1.1.2 or later (the hold on the middle button needs 1.1.2) on a
32×8 panel such as the Ulanzi TC001. The clock takes most of the panel's script heap and runs
with about 45 KB of it free, so run it alone or next to small scripts.

**Settings** (Apps → ⚙ Clock): design; latitude and longitude; °C or °F; weather refresh;
how long calendar and weather show; the scene's animation step; the muted design's backdrop,
brightness and fade; which sprite carries each wipe, or none; the wipe pace.

Source, documentation, previews and the offline tests:
https://github.com/bkahlert/ulanzi-weather-clock (MIT). The weather fetch, the temperature
colour ramp and the code mapping follow Hank_the_Tank's Weather Script
(https://awtrix.de/flow/fGEhP0cZZd6E).
