# Operations

The files in the repository, what `apply` does with them, how to look at the panel from a
shell, firmware upgrades, a flash from scratch, and the tripwires on the way.

## Files

| File | Applied via | Holds |
|---|---|---|
| [`system.json`](../system.json) | `PUT /api/v1/system` | hostname, timezone, auth on, MQTT off. Secrets are merged in from `.env` at apply time. |
| [`settings.json`](../settings.json) | `PATCH /api/v1/settings` | brightness, transitions, time and date format, weekday bar |
| [`apps.json`](../apps.json) | `PUT /api/v1/apps/order` | the rotation and the switched-off apps. A script app listed in `disabled` is kept in the repository but not on the clock (see [design.md](design.md#departures)) |
| [`scripts/*.ax`](../scripts/) | `PUT /api/v1/apps/script/<name>` | Berry scripts. Two apps: [`clock.ax`](../scripts/clock.ax) is the show, [`departures.ax`](../scripts/departures.ax) the BVG departures board; their `# @config` lines are the settings the web UI shows (Apps tab, ⚙ next to the app); the defaults seed a fresh install, and what is set in the web UI stays. The rest are `# @module` scripts the clock imports: [`cycle`](../scripts/cycle.ax), [`timepage`](../scripts/timepage.ax), [`weather`](../scripts/weather.ax), [`wipes`](../scripts/wipes.ax), [`targets`](../scripts/targets.ax) hand-written, [`art`](../scripts/art.ax) and [`sprites`](../scripts/sprites.ax) generated. Uploaded without comments and indentation, modules before the scripts that import them (see below). Scripts on the clock that are not in this directory are removed. |
| `config/<app>.json` | `PATCH /api/v1/apps/<app>/config` | optional, per panel: settings pinned to this panel (coordinates, a stop), written whenever the panel's differ; `--config DIR` names another directory |
| [`icons/`](../icons/) | `POST /api/v1/files?dir=/ICONS` | GIFs a script draws with `icon()`; empty at the moment. Icons on the clock that are not here are removed. |
| [`sprites/`](../sprites/) | | the four Hub GIFs wipe sprites are cut from, and [`extract`](../sprites/extract), which draws five more and writes all nine into the `sprites` module and the sprite options of the clock's header (see [design.md](design.md#wipes)) |
| [`art/`](../art/) | | [`generate`](../art/generate) builds the weather scene elements from geometry and one cloud silhouette and writes them, with the glyph font, to the `art` module; [`preview.png`](../art/preview.png) shows them |
| [`apply`](../apply) | | idempotent push of all of the above; `--dry-run` shows the diff, `--reset-config` puts script settings back to the header defaults, `--only` limits the steps |
| [`bundle`](../bundle) | | writes `dist/ulanzi-weather-clock-<version>.zip`, the eight scripts as a backup the panel's Restore installs |
| [`preview/`](../preview/) | | [`render`](../preview/render) draws the preview GIFs from the scripts under the test harness |
| [`test/`](../test/) | | [`run`](../test/run) executes the clock and its modules in a standalone Berry under a stubbed script API: pixel-exact wipes for every sprite, every setting pairing, 200 random cycles, the button jumps, every weather scene. Run before `apply`. |
| [`flash`](../flash) | | USB erase + write of a release image via `esptool` |

Only values that differ from the firmware defaults are listed in the JSON files. The
transition effect is deliberately not listed: it is picked in the web UI and `apply` leaves it
alone.

## Day to day

```bash
test/run                # the offline tests; berry is built into ~/.cache/awtrix-berry the first time
./apply --dry-run       # what would change, and which script settings differ from the header
./apply                 # push system, settings, icons, scripts, rotation
./apply --reset-config  # the same, and script settings back to the header defaults
preview/render          # the README's GIFs, from the scripts as they are now
```

Every step reads the clock first and writes only the difference. System changes that need a
restart (hostname, auth, MQTT) trigger a reboot and wait for the clock to return.

To see the panel without standing in front of it, `GET /api/v1/display/screen` (basic auth)
returns `{"pixels": [...]}`, 256 colours row by row, top left first; polled a few times a
second over one cycle it shows every page and wipe. Do not poll it while a settings save is
due: the HTTP buffers fragment the heap the recompile lands in (see [memory.md](memory.md)).

## How apply installs scripts

`apply` uploads a stripped copy (header lines kept, then code without comments, blank lines or
indentation), reboots once before installing anything, and installs modules before the
scripts that import them, in import order, so nothing compiles against a module that is not
there yet (the firmware would reinstall the importer when it arrives, but reports the first
attempt as broken).

If an upload is still refused, or the clock stops answering (a panic), `apply` stages a stub
under the same name (the header lines, which keep the settings, and an empty app or a module
returning nil), reboots with the stub running, and uploads into the heap the stub leaves free.
Removing the old version first does not help: its heap is not given back until the next boot.

A script the clock reports as broken is reinstalled even when its source matches, and so is
one whose source the clock cannot send back: on a fragmented heap
`GET /api/v1/apps/script/<name>` has answered 200 with an empty body for a 13 KB script that
was fine on flash. After a reboot request the API keeps answering for a few seconds before the
restart begins, so `apply` waits for the clock's uptime to start over, not merely for an
answer.

## Firmware upgrade

Upgrading the firmware keeps settings, icons and scripts:

```bash
curl -u "$ULANZI_USER:$ULANZI_PASSWORD" -X POST http://$ULANZI_IP/update \
  -F "firmware=@firmware-awtrix-ng.bin"
```

## Re-flash from scratch

1. Connect the clock to the Mac with a USB **data** cable (`/dev/cu.usbserial-*` appears).
2. `./flash` — erases the chip and writes the latest release image. All data on the clock is lost.
3. The clock opens an open Wi-Fi network `awtrixng-<id>`. Join it from the Mac's idle Wi-Fi
   interface (`networksetup -setairportnetwork en1 awtrixng-<id>`) or a phone.
4. `./apply --host 192.168.4.1 --wifi` — writes hostname, auth and the Wi-Fi credentials
   (`WIFI_SSID` / `WIFI_PASSWORD` from `.env`), reboots, and waits for the clock at its LAN
   address (`ULANZI_IP`). Then run `./apply` once more for settings, icons, scripts and
   rotation, which the setup mode refuses.

> **⚠️ Tripwire — esptool at 921600 or 460800 baud fails on this clock's CH340 bridge**
> (`Unable to verify flash chip connection` / `Serial data stream stopped`). `flash`
> defaults to 115200; a full write takes about 105 s.

## Tripwires

> **⚠️ Tripwire — Berry scripts draw icons 8×8 only, and GIF black as black.** `icon(name, x, y)`
> decodes into a fixed 8×8 buffer (`src/media/ScriptIcon.h`, four-entry cache), so a 32×8 GIF
> drawn from a script shows its top-left corner, and a moving icon carries an opaque box.
> Only the payload renderer used by notifications and pushed apps draws a 32-px GIF
> full-width. Anything that has to move over other content is pixel data in the script,
> written by [`sprites/extract`](../sprites/extract). Re-check on a firmware upgrade; if `icon()` learns widths and
> transparency, the sprite strings can go back to being GIFs.

> **⚠️ Tripwire — Berry needs `import string`** for `string.format` / `string.byte`; the
> module is not preloaded, and the compiler reports it as `'string' undeclared` at the
> first use.

> **⚠️ Tripwire — Hub downloads need an account.** `https://awtrix.de/icons/<name>.gif`
> answers 401 anonymously, and 404 for any name that is not the exact lowercase slug
> (`mario&luigi` is `mario-luigi`). Fetch with the Hub connection key from
> awtrix.de account settings and commit the GIF to [`icons/`](../icons/):
>
> ```bash
> curl -H "Authorization: Bearer $AWTRIX_HUB_TOKEN" -o icons/<name>.gif https://awtrix.de/icons/<name>.gif
> ```
>
> The browser-side `# @icons` install is not reproducible.
