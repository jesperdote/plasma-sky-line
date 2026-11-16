.pragma library
// Sun and moon maths. The sunrise/sunset formulas follow Vladimir Agafonkin's
// SunCalc (BSD-2-Clause), which is based on https://aa.quae.nl/en/reken/zonpositie.html

var rad = Math.PI / 180
var dayMs = 86400000
var J1970 = 2440588
var J2000 = 2451545
var J0 = 0.0009
var obliquity = rad * 23.4397

function toDays(date) { return date.valueOf() / dayMs - 0.5 + J1970 - J2000 }
function fromJulian(j) { return new Date((j + 0.5 - J1970) * dayMs) }

function meanAnomaly(d) { return rad * (357.5291 + 0.98560028 * d) }
function eclipticLongitude(M) {
    var C = rad * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M))
    return M + C + rad * 102.9372 + Math.PI
}
function declination(l) { return Math.asin(Math.sin(obliquity) * Math.sin(l)) }
function transitJ(ds, M, L) { return J2000 + ds + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L) }

// Sunrise, solar noon and sunset for the local day that contains `date`.
// Returns null near the poles on days the sun doesn't rise or set.
function sunTimes(date, lat, lon) {
    var noonLocal = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12)
    var lw = rad * -lon
    var phi = rad * lat
    var d = toDays(noonLocal)
    var n = Math.round(d - J0 - lw / (2 * Math.PI))
    var ds = J0 + lw / (2 * Math.PI) + n
    var M = meanAnomaly(ds)
    var L = eclipticLongitude(M)
    var dec = declination(L)
    var jNoon = transitJ(ds, M, L)
    var h0 = rad * -0.833 // sun's upper edge on the horizon, with refraction
    var cosW = (Math.sin(h0) - Math.sin(phi) * Math.sin(dec)) / (Math.cos(phi) * Math.cos(dec))
    if (cosW < -1 || cosW > 1)
        return null
    var w = Math.acos(cosW)
    var jSet = transitJ(J0 + (w + lw) / (2 * Math.PI) + n, M, L)
    var jRise = jNoon - (jSet - jNoon)
    return { rise: fromJulian(jRise), noon: fromJulian(jNoon), set: fromJulian(jSet) }
}

// Moon phase from the mean synodic month, counted from the new moon of 2000-01-06 18:14 UTC.
var synodic = 29.530588853
var newMoonRef = Date.UTC(2000, 0, 6, 18, 14)
var phaseNames = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                  "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
var phaseEmoji = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]

function moon(date) {
    var age = ((date.valueOf() - newMoonRef) / dayMs) % synodic
    if (age < 0)
        age += synodic
    var idx = Math.floor((age / synodic) * 8 + 0.5) % 8
    var lit = (1 - Math.cos(2 * Math.PI * age / synodic)) / 2
    return { name: phaseNames[idx], emoji: phaseEmoji[idx], illumination: lit, age: age }
}

function hours(date) { return date.getHours() + date.getMinutes() / 60 + date.getSeconds() / 3600 }

function pad(n) { return (n < 10 ? "0" : "") + n }
function hhmm(date) { return pad(date.getHours()) + ":" + pad(date.getMinutes()) }

// Sky colour stops along the 24 hours, keyed to today's sunrise and sunset.
function skyStops(rise, set) {
    var night = "#6E73A8", pink = "#F5BDE6", peach = "#F5A97F", blue = "#8AADF4", noonBlue = "#91D7E3", lilac = "#C6A0F6"
    var noon = (rise + set) / 2
    var s = [[0, night], [rise - 1, night], [rise - 0.25, pink], [rise + 0.5, peach], [rise + 2, blue],
             [noon, noonBlue], [set - 2, blue], [set - 0.5, peach], [set + 0.25, lilac], [set + 1, night], [24, night]]
    return s.filter(function (p) { return p[0] >= 0 && p[0] <= 24 })
}

// Open-Meteo WMO weather code -> emoji and words. Clear nights show the moon's phase.
function weather(code, isDay, moonEmoji) {
    if (code === 0) return { icon: isDay ? "☀️" : moonEmoji, text: "Clear" }
    if (code === 1) return { icon: isDay ? "🌤️" : moonEmoji, text: "Mostly clear" }
    if (code === 2) return { icon: isDay ? "⛅" : "☁️", text: "Partly cloudy" }
    if (code === 3) return { icon: "☁️", text: "Cloudy" }
    if (code === 45 || code === 48) return { icon: "🌫️", text: "Fog" }
    if (code >= 51 && code <= 57) return { icon: "🌦️", text: "Drizzle" }
    if (code >= 61 && code <= 67) return { icon: "🌧️", text: "Rain" }
    if (code >= 71 && code <= 77) return { icon: "🌨️", text: "Snow" }
    if (code >= 80 && code <= 82) return { icon: isDay ? "🌦️" : "🌧️", text: "Rain showers" }
    if (code === 85 || code === 86) return { icon: "🌨️", text: "Snow showers" }
    if (code >= 95) return { icon: "⛈️", text: "Thunderstorm" }
    return { icon: isDay ? "☀️" : moonEmoji, text: "" }
}

// Clock text in 24-hour ("08:45") or 12-hour ("8:45 AM") style.
function clock(date, use24) {
    if (use24)
        return hhmm(date)
    var h = date.getHours() % 12
    return (h === 0 ? 12 : h) + ":" + pad(date.getMinutes()) + (date.getHours() < 12 ? " AM" : " PM")
}

// Hour label on the scale: "08" or, 12-hour, a compact "8a" / "12p".
function hourLabel(h, use24) {
    if (use24)
        return pad(h)
    var h12 = h % 12 === 0 ? 12 : h % 12
    return h12 + (h % 24 < 12 ? "a" : "p")
}

// ---- Weather card helpers ----

// Open-Meteo's local times ("2026-11-16T14:00", no offset) as a Date in the laptop's zone.
function localTime(s) { return new Date(s) }

// The weather icon for an hour or a day; clear nights get a plain moon (the phase is in the header).
function hourIcon(code, isDay) { return weather(code, isDay, "🌙").icon }

// UV index -> level name and colour (WHO scale).
function uvLevel(uv) {
    if (uv < 3) return { text: "Low", color: "#A6DA95" }
    if (uv < 6) return { text: "Moderate", color: "#EED49F" }
    if (uv < 8) return { text: "High", color: "#F5A97F" }
    if (uv < 11) return { text: "Very high", color: "#ED8796" }
    return { text: "Extreme", color: "#C6A0F6" }
}

// US AQI -> level name and colour.
function aqiLevel(aqi) {
    if (aqi <= 50) return { text: "Good", color: "#A6DA95" }
    if (aqi <= 100) return { text: "Moderate", color: "#EED49F" }
    if (aqi <= 150) return { text: "Unhealthy for some", color: "#F5A97F" }
    if (aqi <= 200) return { text: "Unhealthy", color: "#ED8796" }
    if (aqi <= 300) return { text: "Very unhealthy", color: "#C6A0F6" }
    return { text: "Hazardous", color: "#B7375F" }
}

// Wind direction in degrees (where it blows FROM) -> compass point and an arrow showing where it blows TO.
var compass = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
var arrows = ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
function windDir(deg) {
    return { name: compass[Math.round(deg / 22.5) % 16], arrow: arrows[Math.round(deg / 45) % 8] }
}

// Beaufort-style words for a wind speed in km/h.
function windWords(kmh) {
    if (kmh < 2) return "Calm"
    if (kmh < 12) return "Light breeze"
    if (kmh < 29) return "Breeze"
    if (kmh < 50) return "Strong breeze"
    if (kmh < 75) return "Gale"
    return "Storm"
}

// Short rain outlook from the next hours' chances: "☔ 65% at 11 AM", "🌦 48% by 3 PM" or "No rain expected".
function rainOutlook(times, probs, use24, hoursAhead) {
    var n = Math.min(hoursAhead, probs.length)
    var peak = 0, peakAt = 0, first = -1
    for (var i = 0; i < n; i++) {
        var p = probs[i] || 0
        if (p > peak) { peak = p; peakAt = i }
        if (first < 0 && p >= 50) first = i
    }
    var at = function (i) { return clock(localTime(times[i]), use24) }
    if (first === 0) return { icon: "☔", text: (probs[0] || 0) + "% chance of rain now" }
    if (first > 0) return { icon: "☔", text: probs[first] + "% chance of rain at " + at(first) }
    if (peak >= 25) return { icon: "🌦️", text: "Up to " + peak + "% chance of rain by " + at(peakAt) }
    return { icon: "🌂", text: "No rain expected in the next " + n + " h" }
}
