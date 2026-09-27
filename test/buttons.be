# the buttons move the cycle: right to the next page, left to the previous one, wrapping at the
# clock's edges where the press is handed back (false); select switches the design
import art
FONT = art["font"]
_store["toWeather"] = "mario"
_store["toTime"] = "yoshi"
_now = 0
app.on_show()
var fails = 0
def expect(name, cond) if !cond print("FAIL:", name) fails += 1 end end
def phase() return _now - app.cycle.t0 end
var wipe_w = app.cycle.t_time
var page_w = wipe_w + app.cycle.w_weather
var wipe_t = page_w + app.cycle.t_weather
_now = 5000                      # on the calendar page
expect("right on the calendar page is taken", app.on_button("right"))
expect("right on the calendar page starts the weather wipe", phase() == wipe_w)
_now += 1000                     # 1 s into the weather wipe: the cycle stands on the weather
expect("right during the weather wipe is the edge", !app.on_button("right"))
expect("right during the weather wipe wraps to the calendar wipe", phase() == wipe_t)
_now += 500                      # in the calendar wipe: the cycle stands on the time
expect("right during the calendar wipe is taken", app.on_button("right"))
expect("right during the calendar wipe starts the weather wipe", phase() == wipe_w)
_now += app.cycle.w_weather + 2000   # 2 s into the weather page
expect("left on the weather page is taken", app.on_button("left"))
expect("left on the weather page starts the calendar wipe", phase() == wipe_t)
_now += app.cycle.w_time + 1000      # rolled over: 1 s into the calendar page of the next cycle
app.draw()
expect("draw rolled the cycle over", phase() == 1000)
expect("left on the calendar page is the edge", !app.on_button("left"))
expect("left on the calendar page wraps to the weather wipe", phase() == wipe_w)
_now += app.cycle.w_weather + 100    # on the weather page
expect("right on the weather page is the edge", !app.on_button("right"))
expect("right on the weather page wraps to the calendar wipe", phase() == wipe_t)
expect("the muted design to begin with", app.muted && app.time_page.muted && app.weather_page.muted && app.cycle.muted)
expect("select is taken", app.on_button("select"))
expect("select switches to the classic design", _store["design"] == "classic" && !app.muted && !app.time_page.muted && !app.cycle.muted)
expect("the cycle starts over", phase() == 0)
expect("classic transitions are wipes", app.cycle.w_weather != app.cycle.fade)
app.on_button("select")
expect("select switches back to muted", _store["design"] == "muted" && app.muted && app.cycle.w_weather == 700)
expect("the display is left alone", _display)
# the middle button through on_button_event: taken at its press; a short press switches the
# design on release; left and right are not taken there
expect("a left press event is not taken", !app.on_button_event("left", "press"))
expect("a select press event is taken", app.on_button_event("select", "press"))
app.on_button_event("select", "release")
expect("a short press switches the design on release", _store["design"] == "classic")
app.on_button_event("select", "press")
app.on_button_event("select", "release")
expect("and back", _store["design"] == "muted")
# a hold starts the demo: every scene five seconds each with its own temperature, the live
# weather kept aside; a second hold ends it early, a full lap ends it by itself
var wp = app.weather_page
wp.code = 63
wp.isday = true
wp.tcol = 0x123456
wp.label = "11"
wp.classic_label = "11F"
wp.unit_f = false
wp.traw = 11                     # a fetched reading: reload() rebuilds the label from it, and
_store["temp"] = 11              # the store holds what the fetch left, which the demo restores from
_store["col"] = 0x123456
_store["code"] = 63
_store["isday"] = true
def demo_on() return app.cycle.demo_t0 != nil end
def hold()
  app.on_button_event("select", "press")
  app.on_button_event("select", "long")
  app.on_button_event("select", "release")
end
_now = 100000
hold()
expect("a hold starts the demo", demo_on())
expect("the hold does not switch the design", _store["design"] == "muted")
fb_clear()
app.draw()
expect("scene 0 is a clear day at 27", wp.code == 0 && wp.isday && wp.label == "27" && wp.classic_label == "27F")
expect("scene 0 shows the sun's ring", FB[7] != 0)
expect("scene 0 shows its temperature", FB[2 * 32 + 5] == wp.tcol || FB[2 * 32 + 4] == wp.tcol)
_now += 5000
fb_clear()
app.draw()
expect("scene 1 is a clear night at 14", wp.code == 0 && !wp.isday && wp.label == "14")
app.on_button_event("select", "press")      # a short press during the demo: the other design, the scene kept
app.on_button_event("select", "release")
expect("a design switch during the demo", demo_on() && _store["design"] == "classic")
expect("reload put the live label back for a moment", wp.label == "11")
fb_clear()
app.draw()
expect("the next frame puts the scene back", wp.label == "14" && wp.code == 0 && !wp.isday)
app.on_button_event("select", "press")
app.on_button_event("select", "release")
expect("and back to muted, demo running", demo_on() && _store["design"] == "muted")
_now += 7 * 5000
fb_clear()
app.draw()
expect("scene 8 is snow at -12", wp.code == 73 && wp.label == "-12")
# left and right during the demo, long after the frozen cycle's own length: taken, nothing moves
expect("the demo has outlived a cycle", _now - app.cycle.t0 > app.cycle.total)
expect("left during the demo is taken", app.on_button("left") && demo_on())
expect("right during the demo is taken", app.on_button("right") && demo_on())
hold()
expect("a second hold ends the demo", !demo_on())
expect("the live weather is back", wp.code == 63 && wp.isday && wp.label == "11" && wp.classic_label == "11F" && wp.tcol == 0x123456)
expect("the cycle starts over after the demo", phase() == 0)
hold()
expect("the demo again", demo_on())
_now += 11 * 5000
fb_clear()
app.draw()
expect("a full lap ends the demo by itself", !demo_on() && wp.code == 63 && wp.label == "11")
expect("and the cycle starts over", phase() == 0)
print("button test:", fails == 0 ? "ok" : str(fails) + " failures")
if fails > 0 raise "test_failed", "buttons" end
