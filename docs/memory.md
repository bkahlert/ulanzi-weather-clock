# Memory

The panel compiles and runs the scripts in one Berry VM on a 96 KB heap. Everything about the
clock's shape - the split into modules, strings and `bytes` instead of lists and maps, the
installer's reboots - follows from the rules below, all of them met the hard way.

## The rules

Scripts are compiled on the panel, in one Berry VM on the internal heap (96 KB budget, no
PSRAM on the TC001). Three rules from the firmware source (`ScriptHost::set`,
`ScriptServices.h`) shape everything here:

- the lexer wants the whole source in one contiguous free block;
- an install needs source + 8 KB free (a replacement source + 4 KB);
- while it compiles, the allocator refuses to take free heap below a 24 KB reserve, which
  surfaces as a script installed with the error `out of memory`.

## The numbers

A fresh boot has about 100 KB free before scripts load. With its 8 scripts loaded (71 KB of
Berry heap: 11 KB the compiled sprites, 12.8 KB the weather, 8.9 KB the app, 7.9 KB the cycle
with the demo) the clock runs with 39–45 KB free after a clean boot and about 35 KB after a
settings save has recompiled the app (the button's design switch writes the store only and
recompiles nothing). With the switched-off departures still loaded it was 29–37 KB, and the
largest block has been seen at 9 KB.

So the app that a save recompiles is kept small (4.0 KB on the wire, 8.5 KB of heap when
compiled), the modules compile once at boot with the whole heap free, and no module is above
6.9 KB on the wire (`weather`).

Judge the heap after a clean reboot. An install that took the stub-and-reboot path, or a
settings save while something polls the HTTP API, leaves the free memory in small pieces (31 KB
free in blocks under 9 KB has been seen, and a config read then answered 507) until the next
boot. Reinstalling a module on a warm clock can still hit the reserve (`weather` has, twice,
with the old app loaded): `apply` stages a stub and reboots, and tries the upload once more if
the clock does not answer it - the one time it did not, the stub stayed and the panel showed
`ERR:clock` until the next run.

## A settings save recompiles the app

Saving in the web UI (or a `PATCH` on `/config`) restarts the app by compiling its source
again, under the rules above, with everything else still loaded.

What failed: `clock.ax` at 16.7 KB (version 1.4, sprites inline) and at 13.1 KB (sprites and
art as modules) against a 9 KB block; a 4.5 KB app and a 2.5 KB module at 35 KB free, against
the reserve. What works: the 2.5 KB app, saved four times in a row at 29–31 KB free; the
8.8 KB app of today, three times in a row from a clean boot at 39 KB free with a 31 KB block.
The same app with 3 KB more heap loaded (a demo module of its own) broke on the second save.

So that is the test for anything that adds heap: three saves in a row after a clean boot, with
`apply` to reinstall if it fails. In the minute after `apply` has installed scripts a save may
still answer 507 ("not enough free memory to store the change"); a minute later it went
through.

Keep the app to the settings and the wiring, everything else a module, and keep runtime data
as strings and `bytes`, not lists of integers or maps: a Berry list holds 16 bytes per number,
a map slot about fifty; the sprite palettes went from maps to letters and bytes for 2 KB. What
the app's `init()` allocates - the module instances and their tables - counts as the app's
heap and is allocated twice while a save recompiles. The next lever, if it is ever needed, is
the switched-off departures script: 6.4 KB of heap for nothing while it is off.

## Tripwires

> **⚠️ Tripwire — the apps listing crashes the clock at about twenty scripts.** With eleven
> sprite modules plus the rest (21 scripts) `GET /api/v1/apps` - which the web UI and `apply`
> call first - reset the connection and then panicked the device; at 14 scripts it was fine.
> Keep the script count low: the sprites are one module for this reason.

> **⚠️ Tripwire — a settings save recompiles the app**, with everything else still loaded and
> the 24 KB reserve out of reach. Anything that adds heap is judged by three saves in a row
> after a clean boot, as above.
