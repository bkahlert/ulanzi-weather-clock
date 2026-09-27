# Ulanzi Weather Clock — agent guidance

Project context that is not obvious from the code. `CLAUDE.md` and `GEMINI.md` are links to this
file. The [README](README.md) is the user's entry; the reasoning lives in [docs/design.md](docs/design.md)
(how the show works), [docs/memory.md](docs/memory.md) (the heap rules that shaped the code),
[docs/operations.md](docs/operations.md) (installer, firmware, flash) and [docs/hub.md](docs/hub.md)
(the flow on awtrix.de).

## Shape

- **One app, seven modules.** [`scripts/clock.ax`](scripts/clock.ax) is the app; the other scripts are
  `# @module` files it imports. The panel recompiles the app on every settings save while the old copy
  still runs, on a 96 KB heap of which about 70 KB are taken at runtime; a module compiles once at boot
  with the heap empty. So the app holds the glue only, and drawing code, data and anything large go
  into a module. Pixel data is strings and `bytes`, not lists and maps, for the same reason.
- **Two modules are generated.** [`scripts/art.ax`](scripts/art.ax) comes from
  [`art/generate`](art/generate), [`scripts/sprites.ax`](scripts/sprites.ax) from
  [`sprites/extract`](sprites/extract), which also rewrites the sprite option lists in the app's header.
  Change the generator and run it with `--write`; never edit the output.
- **Comments are free.** `apply` and `bundle` upload the wire form: header lines kept, comments, blank
  lines and indentation stripped. The size that matters is the one `./apply --dry-run` prints as "on
  the wire".
- **Firmware floor: AWTRIX NG 1.1.2.** The hold on the middle button needs `on_button_event`, which
  1.1.2 introduced; `apply` warns on an older panel. Raise the floor in the README, the header of
  `clock.ax` and `docs/hub.md` together when a newer firmware becomes a requirement.

## Working on it

- **Tests:** `test/run`. Every module and the app run under [`test/harness.be`](test/harness.be)'s
  stubbed script API in a standalone Berry (built into `~/.cache/awtrix-berry` on first run). A test
  is a `test/*.be` file that fails by raising.
- **Visual changes are rendered before they are deployed.** `preview/render` draws the README's GIFs
  from the scripts as they are; look at the result, then go to the panel. The GIFs are deterministic,
  so a re-render after a non-visual change leaves `git status` clean.
- **On a panel:** copy `.env.example` to `.env` (gitignored, never committed), then `./apply --dry-run`
  and `./apply --only scripts`. Values that belong to one panel rather than to the script go into a
  directory of `<app>.json` files passed as `--config`, not into the header defaults.
- **Judge the heap after a clean reboot**, and verify a change to the app with three settings saves
  after a clean boot. A third save on a warm heap has answered 507; that is the known warm-heap
  refusal, not a fault in the change ([docs/memory.md](docs/memory.md)).
- **Scripts:** the Python ones are `uv run` scripts with a PEP 723 header and a usage docstring;
  [`flash`](flash) is Bash. Keep them self-contained.

## Release

1. Bump `# @version` in `scripts/clock.ax`; `bundle` names the zip after it.
2. `test/run`, then `preview/render` and commit the GIFs.
3. `./bundle`, then `gh release create v<version> dist/ulanzi-weather-clock-<version>.zip`.
4. Update the Hub flow (below). The README points at the releases page, not at a version, so it
   needs no edit per release.

## Upgrading the AWTRIX Hub flow

The clock is listed at <https://awtrix.de/flow/wQPSUfXDCHbe>. The Hub carries one script per flow,
so the flow holds `clock.ax` alone and its description sends people to the release bundle for the
installation; *Send to AWTRIX* on its own leaves a panel showing `ERR:`. Publish the GitHub release
first, then the flow, so the flow's code is never ahead of the bundle its text points to.

The Hub has no writing API. The flow is a form behind a GitHub or Discord sign-in, and the copy of
record for everything in it is [docs/hub.md](docs/hub.md): change the text there, then paste. On the
flow's page, *Edit flow*:

1. **Flow code:** paste `scripts/clock.ax` as released. The Hub stores what the form sends, CRLF
   line endings and no trailing newline, and prepends `# @hub <id> <sha256>` to every download;
   that line does not belong in the repository's copy.
2. **Release notes:** what changed; the Hub shows them and the release endpoint returns them.
3. **Description and setup:** paste the Description from `docs/hub.md` when it changed. Keep each
   paragraph on one line: the Hub renders every line break as a break.
4. **Cover:** only when the look changed. `preview/render hub` writes
   [`preview/hub.gif`](preview/hub.gif), the muted loop cut to nine seconds; the Hub takes ten
   seconds and 8192 KB at most.
5. **Save changes**, then check the release endpoint. `revision` counts up, `notes` are the release
   notes, and `sha256` is that of the stored code:

   ```sh
   curl -s https://awtrix.de/api/v1/scripts/wQPSUfXDCHbe/release
   perl -0pe 's/\n\z//; s/\n/\r\n/g' scripts/clock.ax | shasum -a 256
   ```

The other fields stay: System *AWTRIX NG Scripts*, AWTRIX version *AWTRIX NG*, Topic *Miscellaneous*
because the Hub has no clock topic (move it if one appears), no icons.

If an agent is to drive the form rather than the maintainer: a separate Chrome started with
`--remote-debugging-port` and its own `--user-data-dir`, the maintainer signed in there, and the
DevTools protocol (`Runtime.evaluate` to set the fields and dispatch `input` events,
`DOM.setFileInputFiles` for the cover, a trusted click on *Save changes*) has worked. Chrome refuses
JavaScript from AppleScript by default, and screenshots need Screen Recording for the terminal's app.
