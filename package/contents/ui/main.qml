// Sky Line: the 24 hours of today spread across the panel, coloured like the sky,
// with sunrise and sunset marked. Above the current time sits an emoji for the
// weather right now (sun, clouds, rain, storm...), or tonight's moon on clear nights.
// Clicking it opens a weather summary, or the full weather card (a setting).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "sky.js" as Sky

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    // Build the full card up front, so the first click opens it without a delay.
    preloadFullRepresentation: true
    Layout.fillWidth: true

    // Location: from the command if one is set, else the fixed one.
    property real cmdLat: NaN
    property real cmdLon: NaN
    readonly property bool useCmd: Plasmoid.configuration.locationCommand !== "" && !isNaN(cmdLat) && !isNaN(cmdLon)
    readonly property real lat: useCmd ? cmdLat : Plasmoid.configuration.latitude
    readonly property real lon: useCmd ? cmdLon : Plasmoid.configuration.longitude
    readonly property bool hasLocation: !isNaN(lat) && !isNaN(lon) && (lat !== 0 || lon !== 0)

    property date now: new Date()
    property var sun: hasLocation ? Sky.sunTimes(now, lat, lon) : null
    property var moon: Sky.moon(now)

    readonly property real riseH: sun ? Sky.hours(sun.rise) : 6
    readonly property real setH: sun ? Sky.hours(sun.set) : 18
    readonly property real nowH: Sky.hours(now)
    readonly property bool isDay: nowH >= riseH && nowH < setH

    // Weather from Open-Meteo (free, no key), every 15 minutes: current conditions, the next
    // 24 hours and 7 days for the weather card, plus air quality from its sister API.
    property int weatherCode: -1
    property real temperature: NaN
    readonly property var weather: Sky.weather(weatherCode, isDay, moon.emoji)
    readonly property bool imperial: Plasmoid.configuration.fahrenheit
    property var wx: null          // forecast reply (current, hourly, daily)
    property var aq: null          // air-quality reply (current)
    property date updated
    property string place: ""      // from the location command ("lat,lon|Place") or a reverse lookup
    property string cmdPlace: ""

    function getJson(url, done) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (xhr.status !== 200) {
                console.warn("Sky Line:", url.split("?")[0], "answered", xhr.status)
                return
            }
            try {
                done(JSON.parse(xhr.responseText))
            } catch (e) {
                console.warn("Sky Line: bad reply from", url.split("?")[0], e)
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function fetchWeather() {
        if (!hasLocation)
            return
        const at = "latitude=" + lat.toFixed(4) + "&longitude=" + lon.toFixed(4) + "&timezone=auto"
        getJson("https://api.open-meteo.com/v1/forecast?" + at
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,is_day,weather_code,"
                + "cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,uv_index,visibility"
                + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day&forecast_hours=24"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,"
                + "precipitation_sum,uv_index_max,wind_speed_10m_max&forecast_days=7"
                + (imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch" : ""),
                d => {
                    root.wx = d
                    root.weatherCode = d.current.weather_code
                    root.temperature = d.current.temperature_2m
                    root.updated = new Date()
                })
        getJson("https://air-quality-api.open-meteo.com/v1/air-quality?" + at + "&current=us_aqi,pm2_5,pm10",
                d => root.aq = d)
    }

    // Place name: the location command's label if it gives one, else a reverse lookup
    // (BigDataCloud's free client endpoint, no key) when the spot moves by more than ~1 km.
    property string placeKey: ""
    function fetchPlace() {
        if (cmdPlace !== "") {
            place = cmdPlace
            return
        }
        if (!hasLocation)
            return
        const key = lat.toFixed(2) + "," + lon.toFixed(2)
        if (key === placeKey)
            return
        placeKey = key
        getJson("https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=" + lat.toFixed(4)
                + "&longitude=" + lon.toFixed(4) + "&localityLanguage=en",
                d => {
                    const town = d.city || d.locality || ""
                    root.place = [town, d.principalSubdivision, d.countryCode]
                        .filter((p, i, a) => p && a.indexOf(p) === i).join(", ")
                })
    }
    onLatChanged: { fetchWeather(); fetchPlace() }
    onLonChanged: { fetchWeather(); fetchPlace() }
    onCmdPlaceChanged: fetchPlace()

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            // "lat,lon", optionally followed by "|Place name".
            const m = String(data["stdout"] || "").trim().match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)(?:\s*\|\s*(.+))?/)
            if (m) {
                root.cmdLon = parseFloat(m[2])
                root.cmdLat = parseFloat(m[1])
                root.cmdPlace = (m[3] || "").trim()
            }
            disconnectSource(source)
        }
    }
    function refreshLocation() {
        const cmd = Plasmoid.configuration.locationCommand
        if (cmd !== "")
            runner.connectSource(cmd)
    }
    Connections {
        target: Plasmoid.configuration
        function onLocationCommandChanged() { root.refreshLocation() }
        function onFahrenheitChanged() { root.fetchWeather() }
    }
    Component.onCompleted: { refreshLocation(); fetchWeather(); fetchPlace() }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }
    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root.refreshLocation()
    }

    // No hover tooltip: everything is in the popup that a click opens.
    toolTipMainText: ""
    toolTipSubText: ""
    readonly property bool use24: Plasmoid.configuration.use24h

    // The popup: summary by default, the full card with the "full details" setting. "Show all
    // details" in the summary expands it until the popup closes.
    property bool showAll: false
    onExpandedChanged: if (!expanded) showAll = false
    fullRepresentation: Rectangle {
        readonly property real pad: Kirigami.Units.largeSpacing * 1.5
        implicitWidth: inner.implicitWidth + 2 * pad
        implicitHeight: inner.implicitHeight + 2 * pad
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.maximumWidth: implicitWidth
        Layout.maximumHeight: implicitHeight
        // Solid, theme-coloured (Plasma's popups are see-through).
        radius: Kirigami.Units.cornerRadius * 2
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 1)
        WeatherCard {
            id: inner
            sky: root
            compact: !Plasmoid.configuration.fullDetails && !root.showAll
            onShowMore: root.showAll = true
            x: parent.pad
            y: parent.pad
        }
    }

    compactRepresentation: Item {
        id: view
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 40

        readonly property var cfg: Plasmoid.configuration
        readonly property font small: Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: Math.max(5, cfg.labelSize) })
        readonly property font timeFont: Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: Math.max(5, cfg.timeSize) })
        readonly property real lw: Math.max(1, cfg.lineWidth)
        readonly property real side: Kirigami.Units.largeSpacing * 2
        readonly property real lineY: height - tickMetrics.height - 3 - lw / 2
        readonly property real span: width - 2 * side
        function xAt(h) { return side + (h / 24) * span }
        readonly property real nowX: xAt(root.nowH)

        TextMetrics { id: tickMetrics; font: view.small; text: root.use24 ? "00" : "12a" }

        onWidthChanged: line.requestPaint()
        onHeightChanged: line.requestPaint()
        Connections {
            target: root
            function onNowChanged() { line.requestPaint() }
            function onSunChanged() { line.requestPaint() }
        }
        Connections {
            target: Plasmoid.configuration
            function onValueChanged() { line.requestPaint() }
        }

        Canvas {
            id: line
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (!root.hasLocation)
                    return
                const v = view
                const grad = ctx.createLinearGradient(v.xAt(0), 0, v.xAt(24), 0)
                for (const [h, c] of Sky.skyStops(root.riseH, root.setH))
                    grad.addColorStop(h / 24, c)

                // The whole day, thin; daylight hours thicker. With "dim past", the part
                // before now is drawn faint (two passes, each clipped to its side of now).
                const passes = v.cfg.dimPast ? [[0, v.nowX, 0.3], [v.nowX, width, 1]] : [[0, width, 1]]
                for (const [x0, x1, a] of passes) {
                    ctx.save()
                    ctx.beginPath()
                    ctx.rect(x0, 0, x1 - x0, height)
                    ctx.clip()
                    ctx.strokeStyle = grad
                    ctx.lineCap = "round"
                    ctx.globalAlpha = 0.55 * a
                    ctx.lineWidth = Math.max(1, v.lw / 2)
                    ctx.beginPath()
                    ctx.moveTo(v.xAt(0), v.lineY)
                    ctx.lineTo(v.xAt(24), v.lineY)
                    ctx.stroke()
                    ctx.globalAlpha = a
                    ctx.lineWidth = v.lw
                    ctx.beginPath()
                    ctx.moveTo(v.xAt(root.riseH), v.lineY)
                    ctx.lineTo(v.xAt(root.setH), v.lineY)
                    ctx.stroke()
                    ctx.restore()
                }

                // Hour ticks.
                ctx.globalAlpha = 0.7
                ctx.lineWidth = 1
                ctx.strokeStyle = "#A5ADCB"
                ctx.beginPath()
                for (let h = 0; h <= 24; h++) {
                    ctx.moveTo(v.xAt(h), v.lineY + v.lw / 2 + 1)
                    ctx.lineTo(v.xAt(h), v.lineY + v.lw / 2 + 3)
                }
                ctx.stroke()

                // Now: a bright dot on the line.
                ctx.globalAlpha = 1
                ctx.fillStyle = "#ffffff"
                ctx.beginPath()
                ctx.arc(v.nowX, v.lineY, v.lw / 2 + 2, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        // Hour labels, hidden where the sunrise/sunset times sit.
        Repeater {
            model: 25
            delegate: Text {
                readonly property real h: index
                readonly property real cx: view.xAt(h)
                readonly property bool nearSunTime: sunTimes.visible
                         && (Math.abs(cx - view.xAt(root.riseH)) < tickMetrics.width * 1.8
                             || Math.abs(cx - view.xAt(root.setH)) < tickMetrics.width * 1.8)
                visible: root.hasLocation && h % Math.max(1, view.cfg.labelEvery) === 0 && !nearSunTime
                text: Sky.hourLabel(h, root.use24)
                font: view.small
                color: "#A5ADCB"
                opacity: view.cfg.dimPast && h < root.nowH - 0.5 ? 0.35 : 0.8
                x: Math.max(0, Math.min(view.width - width, cx - width / 2))
                y: view.lineY + view.lw / 2 + 2
            }
        }

        // Sunrise and sunset times on the scale.
        Item { id: sunTimes; visible: root.sun !== null && view.cfg.showSunTimes }
        Text {
            visible: sunTimes.visible
            text: root.sun ? "↑" + Sky.clock(root.sun.rise, root.use24) : ""
            font: view.small
            color: "#F5A97F"
            x: view.xAt(root.riseH) - width / 2
            y: view.lineY + view.lw / 2 + 2
        }
        Text {
            visible: sunTimes.visible
            text: root.sun ? "↓" + Sky.clock(root.sun.set, root.use24) : ""
            font: view.small
            color: "#C6A0F6"
            x: view.xAt(root.setH) - width / 2
            y: view.lineY + view.lw / 2 + 2
        }

        // The weather right now, sitting above the current time.
        Text {
            id: icon
            visible: root.hasLocation
            text: root.weather.icon
            // An emoji glyph draws smaller than its pixel size, so "fit" uses the full height above the line.
            font.pixelSize: view.cfg.iconSize > 0 ? view.cfg.iconSize : Math.max(12, view.lineY + 2)
            x: view.nowX - width / 2
            y: view.lineY - view.lw / 2 - height + Math.round(height * 0.12)
        }
        // A click anywhere on the line opens the weather popup (and closes it again).
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
        Text {
            readonly property var parts: [view.cfg.showTime ? Sky.clock(root.now, root.use24) : "",
                                          view.cfg.showTemp && !isNaN(root.temperature) ? Math.round(root.temperature) + "°" : ""]
                                         .filter(p => p !== "")
            visible: root.hasLocation && parts.length > 0
            text: parts.join("  ")
            font: view.timeFont
            color: root.isDay ? "#FFD27A" : "#E2E4F6"
            readonly property bool roomRight: icon.x + icon.width + 4 + width < view.width
            x: roomRight ? icon.x + icon.width + 4 : icon.x - width - 4
            y: icon.y + (icon.height - height) / 2
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasLocation
            text: "Sky Line: set a location in the settings"
            font: view.small
            color: "#A5ADCB"
        }
    }

}
