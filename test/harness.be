# The AWTRIX NG script API, stubbed: a 32x8 framebuffer the tests read back, fixed clocks, the
# app's store and the device settings as maps, glyphs drawn from the art module's font the way
# the firmware draws them. Concatenated in front of clock.ax by test/run.
var FB = []
var _now = 0
def fb_clear() FB = [] var i = 0 while i < 256 FB.push(0) i += 1 end end
fb_clear()
def pixel(x, y, c) if x >= 0 && x < 32 && y >= 0 && y < 8 FB[y * 32 + x] = c end end
def rect_fill(x, y, w, h, c)
  var yy = y
  while yy < y + h
    var xx = x
    while xx < x + w pixel(xx, yy, c) xx += 1 end
    yy += 1
  end
end
def clear() fb_clear() end
def circle_fill(cx, cy, r, c) end
import string
var FONT = nil   # set by the test to the app's font, so text() draws like the firmware
var ADV = {":": 2, ".": 2}
def chars(s)
  var out = []
  var i = 0
  while i < size(s)
    var n = (string.byte(s[i]) & 0xE0) == 0xC0 ? 2 : 1
    out.push(s[i..i + n - 1])
    i += n
  end
  return out
end
def text_width(s)
  var w = 0
  for ch : chars(s) w += ADV.find(ch, 4) end
  return w
end
def text_ink_width(s) return text_width(s) - 1 end
def text(x, y, s, c)
  # baseline y: a glyph [w, rows above the baseline, rows top to bottom joined with "|"]
  for ch : chars(s)
    var g = FONT.find(ch)
    if g != nil
      var w = g[0]
      var rows = g[2]
      var h = (size(rows) + 1) / (w + 1)
      var top = y - g[1] - h
      var r = 0
      while r < h
        var k = 0
        while k < w
          if rows[r * (w + 1) + k] == "#" pixel(x + k, top + r, c) end
          k += 1
        end
        r += 1
      end
    end
    x += ADV.find(ch, 4)
  end
end
def icon(n, x, y) return false end
def now_ms() return _now end
def epoch_ms() return _now end
def hour() return 23 end
def minute() return 45 end
def day() return 19 end
def rgb(r, g, b) return (r << 16) | (g << 8) | b end
var store = module("store")
var _store = {"every": 15, "pace": 90, "timeSecs": 12, "weatherSecs": 8, "unit": "C", "lat": 52.5, "lon": 13.4, "anim": 250, "backdrop": 45, "design": "muted", "fade": 700, "dimming": 100, "toWeather": "random", "toTime": "random"}
store.get = def(k, d) if _store.find(k) != nil return _store[k] end return d end
store.set = def(k, v) _store[k] = v end
var settings = module("settings")
settings.get = def(k) return nil end
var http = module("http")
http.get = def(u, cb, o) end
var re = module("re")
re.search = def(p, s) return nil end
def num(s) return real(s) end
var _display = true
var display = module("display")
display.power = def(on) _display = on end
display.is_on = def() return _display end
