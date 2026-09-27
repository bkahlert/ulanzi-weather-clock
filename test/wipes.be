# Wipes: pixel-exact cut outside the sprite's box for every sprite in both directions, a full
# cycle drawn for every pairing of the two settings, 200 random cycles that use every sprite and
# never repeat one.
import art
FONT = art["font"]
_store["design"] = "classic"     # sprite wipes
app.weather_page.label = "17"
app.weather_page.classic_label = "17F"
app.weather_page.tcol = 0x6ED228
app.weather_page.code = 63
app.weather_page.isday = true
_now = 0
# reference renders of both full pages at a fixed instant
def page_fb(weather, t)
  _now = t
  fb_clear()
  if weather app.page(true, app.full) else app.page(false, app.full) end
  return FB.copy()
end
var out = {}
var bad = 0
def wipe(name, t0, ms, step, to_weather, w)
  var frames = []
  var e = 0
  while e < ms
    _now = t0 + e
    app.draw()
    frames.push(FB.copy())
    # pixel-exact cut: left of the sprite the arriving page, right of it the leaving page
    var sx = e / app.cycle.pace - w
    var nw = page_fb(to_weather, t0 + e)
    var od = page_fb(!to_weather, t0 + e)
    _now = t0 + e
    app.draw()
    var i = 0
    while i < 256
      var x = i % 32
      if x < sx && FB[i] != nw[i] bad += 1 end
      if x >= sx + w && FB[i] != od[i] bad += 1 end
      i += 1
    end
    e += step
  end
  out[name] = frames
end
# every sprite once in each direction, pixel-exact outside its box
for who : app.cycle.names
  _store["toWeather"] = who
  _store["toTime"] = who
  _now = 0
  app.on_show()
  var w = app.cycle.cast[who][3]
  wipe("time > weather (" + who + ")", app.cycle.t_time, app.cycle.w_weather, 270, true, w)
  wipe("weather > time (" + who + ")", app.cycle.t_time + app.cycle.w_weather + app.cycle.t_weather, app.cycle.w_time, 270, false, w)
end
print("pixels wrong outside the sprite box over all wipes:", bad)
# the muted design's cross-fade: the leaving page at e=0, halfway every pixel of the left block
# the blend of the two pages, the time untouched; then back to classic for the cycles below
_store["design"] = "muted"
_store["toWeather"] = "mario"
_store["toTime"] = "mario"
_now = 0
app.on_show()
var ft0 = app.cycle.t_time
var fms = app.cycle.w_weather
var fbad = 0
if fms != 700 || app.cycle.w_time != 700 print("fade length", fms, app.cycle.w_time) fbad += 1 end
var fob = page_fb(false, ft0)
var fnb = page_fb(true, ft0)
_now = ft0
fb_clear()
app.draw()
var i = 0
while i < 256                             # the left block still the leaving page, the right part the arriving one
  var want = i % 32 < 16 ? fob[i] : fnb[i]
  if FB[i] != want print("fade start pixel", i % 32, i / 32, "is", FB[i], "want", want) fbad += 1 end
  i += 1
end
fob = page_fb(false, ft0 + 350)          # the scene moves with time: references at the frame's instant
fnb = page_fb(true, ft0 + 350)
_now = ft0 + 350
fb_clear()
app.draw()
i = 0
while i < 256
  var want = i % 32 < 16 ? app.wiper.blend(fnb[i], fob[i], 30) : fnb[i]
  if FB[i] != want print("fade pixel", i % 32, i / 32, "is", FB[i], "want", want, "pages", fnb[i], fob[i]) fbad += 1 end
  i += 1
end
fob = page_fb(false, ft0 + 175)          # a quarter in: 15/60, linear
fnb = page_fb(true, ft0 + 175)
_now = ft0 + 175
fb_clear()
app.draw()
i = 0
while i < 256
  var want = i % 32 < 16 ? app.wiper.blend(fnb[i], fob[i], 15) : fnb[i]
  if FB[i] != want print("quarter fade pixel", i % 32, i / 32, "is", FB[i], "want", want) fbad += 1 end
  i += 1
end
print("fade frames wrong pixels:", fbad)
bad += fbad
_store["design"] = "classic"
_store["toWeather"] = "random"
_store["toTime"] = "random"
# a whole cycle at 45 ms without a runtime error, every setting pairing
var n = 0
var picks = app.cycle.names + ["none", "random"]
for tw : picks
  for tt : picks
    _store["toWeather"] = tw
    _store["toTime"] = tt
    _now = 0
    app.on_show()
    var e = 0
    while e < app.duration()
      _now = e
      app.draw()
      n += 1
      e += 45
    end
  end
end
print("draw() sweep ok:", n, "frames over", size(picks) * size(picks), "setting pairings")
# random: 200 cycles rolled over inside draw(); every sprite shows up, never twice in a row, cycle lengths follow the picks
_store["toWeather"] = "random"
_store["toTime"] = "random"
_now = 0
app.on_show()
var seen = {}
var repeats = 0
var last = nil
var cycles = 0
while cycles < 200
  var wa = app.cycle.who_weather
  var wt = app.cycle.who_time
  if wa == last repeats += 1 end
  if wt == wa repeats += 1 end
  last = wt
  seen[wa] = seen.find(wa, 0) + 1
  seen[wt] = seen.find(wt, 0) + 1
  if app.cycle.total != app.cycle.t_time + app.cycle.t_weather + app.cycle.wipe_ms(wa) + app.cycle.wipe_ms(wt) print("total mismatch") end
  _now = app.cycle.t0 + app.cycle.total   # jump to the end of this cycle: draw() rolls over and plans the next
  app.draw()
  cycles += 1
end
print("random over 200 cycles:", seen, "immediate repeats:", repeats)
# translucency: KITT's trail is its hue blended over the arriving page, its bright column the hue itself
import sprites
var kitt = sprites["cast"]["kitt"]
def palc(sp, ch) return sp[1][1].get(string.find(sp[1][0], ch) * 4, 4) end   # a palette letter's colour
# the decode against two colours read by hand from the module's bytes: the shared palette's first
# letter (opaque) and KITT's (translucent, 15/60), so the checks below rest on more than their own decoder
if palc(sprites["cast"]["mario"], "a") != 0x00E552 || palc(kitt, "a") != 0x0FAC00F6 raise "test_failed", "palette decode" end
_store["toWeather"] = "kitt"
_store["toTime"] = "kitt"
_now = 0
app.on_show()
var e = 14 * app.cycle.pace                 # the sprite's left edge at x = 14 - 4 = 10
var t = app.cycle.t_time + e
var nw = page_fb(true, t)
_now = t
app.draw()
var blends = 0
var r = 0
while r < 8
  var frame = kitt[0]
  var v_trail = palc(kitt, frame[r * 4])
  var v_bar = palc(kitt, frame[r * 4 + 3])
  var want = app.wiper.blend(v_trail & 0xFFFFFF, nw[r * 32 + 10], v_trail >> 24)
  if FB[r * 32 + 10] != want blends += 1 end
  if FB[r * 32 + 13] != v_bar blends += 1 end
  if (v_trail >> 24) != 15 || v_bar > 0xFFFFFF blends += 1 end
  r += 1
end
print("KITT trail blended over the arriving page, bar opaque; mismatches:", blends)
if bad > 0 || repeats > 0 || size(seen) != size(app.cycle.names) || blends > 0 raise "test_failed", "wipes" end
