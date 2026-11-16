# Changelog

All notable changes to Sky Line. Versions follow [semantic versioning](https://semver.org/);
each one is a GitHub release with the installable `.plasmoid` file.

## [1.2.0] - 2026-11-16

### Added
- Weather popup: click the widget to open it, on a solid background.
  - **Summary** (default): conditions, temperature, feels-like, today's high and low, place name,
    date, a rain outlook for the next 6 hours, and chips for humidity, wind, UV index, air
    quality, sunrise, sunset and the moon.
  - **Full details** ("Show all details" in the summary, or the new *full details* setting):
    tiles for feels-like and dew point, humidity, wind (speed, direction, gusts), UV index, rain
    today, cloud cover, pressure, visibility, air quality (US AQI, PM2.5, PM10), sunrise, sunset
    and daylight, and the moon; the next 12 hours with rain-chance bars; 7 days with each day's
    low-high range on the week's scale.
- Air quality from Open-Meteo's air-quality API.
- Place name: a location command can print `lat,lon|Place name`; otherwise it is looked up with
  BigDataCloud's free reverse geocoding (only when the location moves by about a kilometre).

### Changed
- The hover tooltips are gone: the day/time/date tooltip on the weather icon and the text tooltip
  on the line. Everything they showed is in the popup.
- The "day, time and date on hover" setting is replaced by "clicking shows full weather details".

### Fixed
- No failed weather requests at startup while a location command's coordinates arrive.

## [1.1.1] - 2026-11-13

### Changed
- Licence changed to GPL-3.0-or-later.

## [1.1.0] - 2026-11-13

### Added
- Hovering the weather icon shows the day, time and date on one line (`Sat | 05:58 | 11:14:26`),
  with a setting to turn it off.
- Standalone repository with install steps and a release workflow that builds the `.plasmoid`.

## [1.0.0] - 2026-11-11

### Added
- First release: today's 24 hours across the panel, coloured like the sky, with daylight hours
  thicker and sunrise and sunset marked on the scale.
- The current weather (Open-Meteo) as an emoji above the current time; on clear nights, the moon
  in tonight's phase. The time and temperature can sit beside it.
- Location as fixed coordinates or a command that prints `lat,lon`.
- Settings for the clock (24 or 12 hours), °C or °F, hour labels, sunrise/sunset times, fading
  the past hours, and the sizes of the icon, labels, time and line.

[1.2.0]: https://github.com/jesperdote/plasma-sky-line/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/jesperdote/plasma-sky-line/releases/tag/v1.1.1
