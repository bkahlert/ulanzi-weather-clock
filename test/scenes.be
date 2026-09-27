import targets
# --- render every scene at six steps, plus a clipped frame and a full draw() sweep
import art
FONT = art["font"]
app.weather_page.label = "12"
app.weather_page.classic_label = "12F"
app.weather_page.tcol = 0xFFFF28
var i = 0
var cases = [["clear day", 0, true], ["clear night", 0, false], ["partly cloudy", 2, true], ["partly, night", 2, false],
             ["overcast", 3, true], ["fog", 45, true], ["drizzle", 55, true], ["rain", 63, true],
             ["showers", 81, true], ["snow", 73, true], ["thunder", 95, true]]
var out = {}
for c : cases
  app.weather_page.code = c[1]
  app.weather_page.isday = c[2]
  var frames = []
  var st = 0
  while st < 6
    _now = st * 250
    fb_clear()
    app.page(true, app.full)
    frames.push(FB.copy())
    st += 1
  end
  out[c[0]] = frames
end
# clipped at column 9: dots and rects stop there exactly; a glyph straddling the edge may spill
# up to two columns (the firmware draws it whole; in a wipe the sprite's box overwrites those)
app.weather_page.code = 63
fb_clear()
app.page(true, targets["Direct"](9, 32))
var leak = 0
i = 0
while i < 256 if FB[i] != 0 && i % 32 < 7 leak += 1 end i += 1 end
print("clipped frame lit pixels left of x=7:", leak)
# the layout: the time on columns 15-31 rows 2-6 on both pages (plus the stale dot at (31,0)); the
# muted weather page dark on column 14, its scene dimmed, the temperature where the card has its
# day with the degree pixel beside the digits' top row; the calendar page dark on columns 12-14
var bad = 0
def lit(x, y) return FB[y * 32 + x] != 0 end
app.weather_page.code = 2
app.weather_page.isday = true
_now = 0
fb_clear()
app.page(true, app.full)
if FB[2 * 32 + 12] != app.weather_page.tcol print("degree pixel missing at (12,2)") bad += 1 end
var dimmed = app.weather_page.shade(0xFFC800)
var found = false
i = 0
while i < 256 if FB[i] == dimmed found = true end i += 1 end
if !found print("no sun pixel at the backdrop's brightness") bad += 1 end
i = 0
while i < 256
  var x = i % 32
  var y = i / 32
  if FB[i] != 0 && x >= 16 && (y < 2 || y > 6) && !(x == 31 && y == 0) print("weather page lit outside the time at", x, y) bad += 1 end
  if FB[i] != 0 && x == 14 print("weather page lit in the gutter at", x, y) bad += 1 end
  i += 1
end
if !lit(15, 2) || !lit(29, 6) print("time missing on the weather page") bad += 1 end
fb_clear()
app.page(false, app.full)
if FB[3] != 0x720000 || FB[11] != 0x720000 || FB[2] != 0 || FB[12] != 0 print("calendar card not on columns 3-11 at the backdrop brightness") bad += 1 end
if FB[2 * 32 + 3] != 0x727272 print("card body not at the backdrop brightness") bad += 1 end
i = 0
while i < 256
  var x = i % 32
  var y = i / 32
  if FB[i] != 0 && x >= 12 && x <= 14 print("calendar page lit in the gutter at", x, y) bad += 1 end
  if FB[i] != 0 && x >= 16 && (y < 2 || y > 6) && !(x == 31 && y == 0) print("calendar page lit outside the time at", x, y) bad += 1 end
  i += 1
end
if !lit(15, 2) || !lit(29, 6) print("time missing on the calendar page") bad += 1 end
# the temperature label at its widths, without a scene, on rows 2-6: the digits centred on the
# card's columns like the day (two digits at 4-10, one at 6-8), the mark two columns after them;
# never past 13, shifted left when it would be; the F glyph while the label is two characters
var wp = app.weather_page
wp.code = -1
wp.age = 0
def temp_span()
  var lo = 99
  var hi = -1
  var k = 2 * 32
  while k < 7 * 32
    if FB[k] != 0 && k % 32 < 15
      if k % 32 < lo lo = k % 32 end
      if k % 32 > hi hi = k % 32 end
    end
    k += 1
  end
  return [lo, hi]
end
# label, Fahrenheit, first column, last column, F glyph expected
for c : [["9", false, 6, 10, false], ["19", false, 4, 12, false], ["-12", false, 1, 13, false],
         ["66", true, 2, 12, true], ["6", true, 4, 10, true], ["100", true, 1, 13, false], ["-12", true, 1, 13, false]]
  wp.label = c[0]
  wp.unit_f = c[1]
  fb_clear()
  app.page(true, app.full)
  var span = temp_span()
  if span[0] != c[2] || span[1] != c[3] print("label", c[0], c[1] ? "F" : "°", "spans", span, "expected", c[2], c[3]) bad += 1 end
  var hi = c[3]
  var f_glyph = lit(hi, 2) && lit(hi, 4) && lit(hi - 1, 4) && lit(hi - 2, 6)   # the F's top and middle bars, its stem
  var pixel = lit(hi, 2) && !lit(hi, 3) && !lit(hi - 1, 2)                     # the mark alone, a gap before it
  if c[4] != f_glyph || c[4] == pixel print("label", c[0], c[1] ? "F" : "°", "unit drawn wrong") bad += 1 end
  var top = 0
  var k = 0
  while k < 2 * 32 if FB[k] != 0 && k % 32 < 15 top += 1 end k += 1 end
  if top > 0 print("label", c[0], "lit above row 2") bad += 1 end
end
wp.unit_f = false
wp.label = "12"
wp.code = 2
# the muted scene's paces - drift 1.5 s, rain 0.6 s, snow 1.2 s - and its clip 14; the sun stands
# with its bright ring; thunder keeps its bolt, brightens the cloud for 300 ms every 10 s, never flashes
app.reload()
if wp.drift_ms != 1500 || wp.fall_ms != 600 || wp.snow_ms != 1200 || wp.clip != 14 print("muted paces / clip wrong:", wp.drift_ms, wp.fall_ms, wp.snow_ms, wp.clip) bad += 1 end
def same_rows(a, b, rows)
  var k = 0
  while k < rows * 32 if a[k] != b[k] return false end k += 1 end
  return true
end
wp.code = 0
_now = 1500
fb_clear()
app.page(true, app.full)
var sun_a = FB.copy()
_now = 3000
fb_clear()
app.page(true, app.full)
if !same_rows(FB, sun_a, 8) || !lit(7, 0) print("muted sun does not stand with its ring") bad += 1 end
wp.code = 95
_now = 5000
fb_clear()
app.page(true, app.full)
var storm_a = FB.copy()
if !lit(2, 4) || !lit(1, 6) print("muted bolt not standing at the cloud's left edge") bad += 1 end
_now = 7400
fb_clear()
app.page(true, app.full)
if !same_rows(FB, storm_a, 4) || !lit(2, 4) print("muted storm cloud not steady between strikes") bad += 1 end
_now = 100
fb_clear()
app.page(true, app.full)
if same_rows(FB, storm_a, 4) || !lit(2, 4) print("muted strike does not brighten the cloud") bad += 1 end
var white = 0
i = 0
while i < 4 * 32 if FB[i] == wp.shade(0xFFFFFF) && i % 32 < 14 white += 1 end i += 1 end
if white > 3 print("muted strike flashes white:", white, "pixels") bad += 1 end
_now = 400
fb_clear()
app.page(true, app.full)
if !same_rows(FB, storm_a, 4) print("muted strike lasts past 300 ms") bad += 1 end
wp.code = 2
# the muted brightness scales every colour the direct targets draw: the time's white and the
# card's head, itself already at the backdrop
_store["dimming"] = 50
app.reload()
_now = 2500
fb_clear()
app.page(false, app.full)
if FB[2 * 32 + 15] != 0x7F7F7F || FB[3] != 0x390000 print("muted brightness not applied", FB[2 * 32 + 15], FB[3]) bad += 1 end
_store["dimming"] = 100
# classic: the card at 0-8 in the device's own colours, the time at 12-28, the colon off in the
# second half of every two seconds and on in the first; the scene bright, the temperature with its
# unit centred over 17-31 and no time on the weather page
_store["design"] = "classic"
app.reload()
_now = 3500
fb_clear()
app.page(false, app.full)
if FB[0] != 0xFF0000 || FB[8] != 0xFF0000 || FB[9] != 0 || FB[2 * 32] != 0xFFFFFF print("classic card not at 0-8 in full colour") bad += 1 end
if !lit(12, 2) || lit(20, 3) || lit(29, 2) print("classic time not at 12-28 with the colon off at 3500 ms") bad += 1 end
fb_clear()
app.page(true, app.full)
found = false
i = 0
while i < 256 if FB[i] == 0xFFC800 found = true end i += 1 end
if !found || !lit(20, 2) || lit(16, 2) || lit(30, 4) print("classic weather page wrong: scene dim, or a time on it") bad += 1 end
# the classic temperature "12": digits at 19-25, the degree block at 27-28 on rows 2-3 with a dark
# column before it and nothing under it; Fahrenheit the F glyph at 27-29 in the same run
if !lit(27, 2) || !lit(28, 2) || !lit(27, 3) || !lit(28, 3) || lit(26, 2) || lit(29, 2) || lit(27, 4) || FB[2 * 32 + 27] != wp.tcol print("classic degree block wrong") bad += 1 end
wp.unit_f = true
fb_clear()
app.page(true, app.full)
if !lit(27, 2) || !lit(29, 2) || !lit(27, 4) || !lit(28, 4) || !lit(27, 6) || lit(29, 6) print("classic F glyph wrong") bad += 1 end
wp.unit_f = false
_now = 2500
fb_clear()
app.page(false, app.full)
if !lit(20, 3) print("classic colon not on at 2500 ms") bad += 1 end
# classic keeps its motion: every step anim ms, the sun's ring breathing dark, faint, bright, faint
# at two steps per state - beside the disc at (7,0) and (4,3), at its corner (5,1) - the disc itself
# unchanged; the flash white and the bolt at steps 4 and 5 of 8
if wp.drift_ms != 250 || wp.fall_ms != 250 || wp.snow_ms != 250 || wp.clip != 16 print("classic paces / clip wrong") bad += 1 end
wp.code = 0
var want = [0, 0x4D3C00, 0x8C6E00, 0x4D3C00]
var kk = 0
while kk < 4
  _now = kk * 500
  fb_clear()
  app.page(true, app.full)
  if FB[7] != want[kk] || FB[32 + 5] != want[kk] || FB[3 * 32 + 4] != want[kk] print("classic ring at", _now, "ms:", FB[7], "expected", want[kk]) bad += 1 end
  if FB[3 * 32 + 7] != 0xFFC800 || FB[32 + 7] != 0xFFC800 || lit(5, 0) print("classic disc changed at", _now) bad += 1 end
  kk += 1
end
_now = 250
fb_clear()
app.page(true, app.full)
if FB[7] != 0 print("classic ring not two steps per state") bad += 1 end
wp.code = 95
_now = 1100
fb_clear()
app.page(true, app.full)
var flashed = 0
i = 0
while i < 4 * 32 if FB[i] == 0xFFFFFF && i % 32 < 16 flashed += 1 end i += 1 end
if flashed < 10 || !lit(8, 4) print("classic strike: flash", flashed, "pixels, bolt", lit(8, 4)) bad += 1 end
_now = 1600
fb_clear()
app.page(true, app.full)
if lit(8, 4) print("classic bolt shown outside the strike") bad += 1 end
wp.code = 2
# the muted colon stands at the instant the classic one is off
_store["design"] = "muted"
app.reload()
_now = 3500
fb_clear()
app.page(false, app.full)
if !lit(23, 3) print("muted colon blinks") bad += 1 end
print("layout checks:", bad == 0 ? "ok" : str(bad) + " failures")
leak += bad
# full draw() sweep over one cycle: no runtime error allowed
app.on_show()
var e = 0
var frames_drawn = 0
while e < app.duration()
  _now = e
  app.draw()
  frames_drawn += 1
  e += 125
end
print("draw() sweep ok:", frames_drawn, "frames, cycle", app.duration(), "ms")
if leak > 0 raise "test_failed", "scenes" end
