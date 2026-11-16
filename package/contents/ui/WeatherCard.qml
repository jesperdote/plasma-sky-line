// The weather card: everything about the weather here and now, the next hours and the week.
// Shown when hovering the weather icon, and as the popup when clicking it.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "sky.js" as Sky

ColumnLayout {
    id: card

    required property var sky                  // the PlasmoidItem: wx, aq, place, sun, moon...
    property bool compact: false               // true = the summary; false = the full card
    signal showMore()                          // "Show all details" clicked in the summary
    readonly property var wx: sky.wx
    readonly property var cur: wx ? wx.current : null
    readonly property var aq: sky.aq ? sky.aq.current : null
    readonly property bool use24: sky.use24
    readonly property bool imperial: sky.imperial
    readonly property string windUnit: imperial ? "mph" : "km/h"

    readonly property color fg: Kirigami.Theme.textColor
    readonly property color dim: Qt.alpha(Kirigami.Theme.textColor, 0.6)
    readonly property color tileBg: Qt.alpha(Kirigami.Theme.textColor, 0.06)
    readonly property real u: Kirigami.Units.gridUnit

    function deg(t) { return isNaN(t) || t === null || t === undefined ? "–" : Math.round(t) + "°" }

    spacing: Kirigami.Units.largeSpacing
    width: implicitWidth

    // Sets the card's width (a layout computes its own implicitWidth, so it can't be assigned).
    Item { Layout.preferredWidth: card.u * (card.compact ? 24 : 36); Layout.preferredHeight: 0 }

    // ---- No data yet ----
    Text {
        visible: !card.cur
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        text: sky.hasLocation ? "Loading the weather…" : "Set a location in the widget settings"
        color: card.dim
        font.pointSize: 11
    }

    // ---- Header: big icon, temperature, condition, place ----
    RowLayout {
        visible: !!card.cur
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Text {
            text: sky.weather.icon
            font.pixelSize: card.u * 3.6
        }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Text {
                    text: card.cur ? card.deg(card.cur.temperature_2m) : ""
                    color: card.fg
                    font.pointSize: 30
                    font.weight: Font.Light
                }
                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: sky.weather.text || (sky.isDay ? "Day" : "Night")
                        color: card.fg
                        font.pointSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: card.cur ? "Feels like " + card.deg(card.cur.apparent_temperature) : ""
                        color: card.dim
                        font.pointSize: 10
                    }
                }
            }
            Text {
                text: "📍 " + (sky.place || (sky.lat.toFixed(2) + ", " + sky.lon.toFixed(2)))
                color: card.fg
                font.pointSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: Qt.formatDateTime(sky.now, "dddd d MMMM") + " · " + Sky.clock(sky.now, card.use24)
                color: card.dim
                font.pointSize: 9
            }
        }
        ColumnLayout {
            visible: !!card.wx
            spacing: 0
            Layout.alignment: Qt.AlignTop
            Text {
                Layout.alignment: Qt.AlignRight
                text: card.wx ? "↑ " + card.deg(card.wx.daily.temperature_2m_max[0]) : ""
                color: "#F5A97F"
                font.pointSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignRight
                text: card.wx ? "↓ " + card.deg(card.wx.daily.temperature_2m_min[0]) : ""
                color: "#8AADF4"
                font.pointSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    // ---- Rain outlook banner (next 6 hours) ----
    Rectangle {
        visible: !!card.wx
        Layout.fillWidth: true
        implicitHeight: rainRow.implicitHeight + Kirigami.Units.largeSpacing * 1.5
        radius: Kirigami.Units.cornerRadius * 2
        readonly property var outlook: card.wx ? Sky.rainOutlook(card.wx.hourly.time, card.wx.hourly.precipitation_probability, card.use24, 6) : null
        color: Qt.alpha("#8AADF4", outlook && outlook.icon === "🌂" ? 0.10 : 0.22)
        RowLayout {
            id: rainRow
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing * 2
            Text { text: parent.parent.outlook ? parent.parent.outlook.icon : ""; font.pixelSize: card.u * 1.2 }
            Text {
                Layout.fillWidth: true
                text: parent.parent.outlook ? parent.parent.outlook.text : ""
                color: card.fg
                font.pointSize: 10
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    // ---- Summary (hover): the key numbers as chips, then a hint ----
    Flow {
        visible: card.compact && !!card.cur
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing * 1.5
        Repeater {
            model: {
                const c = card.cur
                if (!c)
                    return []
                const wd = Sky.windDir(c.wind_direction_10m)
                const uv = Sky.uvLevel(c.uv_index)
                const chips = [
                    { icon: "💧", text: c.relative_humidity_2m + "%" },
                    { icon: "🌬️", text: Math.round(c.wind_speed_10m) + " " + card.windUnit + " " + wd.arrow },
                    { icon: "😎", text: "UV " + Math.round(c.uv_index) + " " + uv.text, color: uv.color }
                ]
                if (card.aq && card.aq.us_aqi !== null) {
                    const a = Sky.aqiLevel(card.aq.us_aqi)
                    chips.push({ icon: "🍃", text: "AQI " + card.aq.us_aqi, color: a.color })
                }
                if (sky.sun) {
                    chips.push({ icon: "🌅", text: Sky.clock(sky.sun.rise, card.use24) })
                    chips.push({ icon: "🌇", text: Sky.clock(sky.sun.set, card.use24) })
                }
                chips.push({ icon: sky.moon.emoji, text: Math.round(sky.moon.illumination * 100) + "%" })
                return chips
            }
            delegate: Rectangle {
                required property var modelData
                implicitWidth: chipRow.implicitWidth + Kirigami.Units.largeSpacing * 1.2
                implicitHeight: chipRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: height / 2
                color: card.tileBg
                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    Text { text: modelData.icon; font.pixelSize: card.u * 0.9 }
                    Text {
                        text: modelData.text
                        color: modelData.color || card.fg
                        font.pointSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
    Text {
        visible: card.compact && !!card.cur
        Layout.alignment: Qt.AlignHCenter
        text: "Show hourly, 7 days and all details ▾"
        color: moreArea.containsMouse ? card.fg : card.dim
        font.pointSize: 8
        font.underline: moreArea.containsMouse
        MouseArea {
            id: moreArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.showMore()
        }
    }

    // ---- Detail tiles ----
    GridLayout {
        visible: !card.compact && !!card.cur
        Layout.fillWidth: true
        columns: 4
        columnSpacing: Kirigami.Units.smallSpacing * 2
        rowSpacing: Kirigami.Units.smallSpacing * 2

        Repeater {
            model: {
                const c = card.cur
                if (!c)
                    return []
                const d = card.wx.daily
                const kmh = card.imperial ? c.wind_speed_10m * 1.609 : c.wind_speed_10m
                const wd = Sky.windDir(c.wind_direction_10m)
                const uv = Sky.uvLevel(c.uv_index)
                const tiles = [
                    { icon: "🌡️", label: "Feels like", value: card.deg(c.apparent_temperature),
                      sub: "Dew point " + card.deg(c.dew_point_2m) },
                    { icon: "💧", label: "Humidity", value: c.relative_humidity_2m + "%",
                      sub: c.relative_humidity_2m >= 70 ? "Muggy" : c.relative_humidity_2m >= 40 ? "Comfortable" : "Dry" },
                    { icon: "🌬️", label: "Wind", value: Math.round(c.wind_speed_10m) + " " + card.windUnit + " " + wd.arrow,
                      sub: wd.name + " · gusts " + Math.round(c.wind_gusts_10m) },
                    { icon: "😎", label: "UV index", value: (Math.round(c.uv_index * 10) / 10) + " " + uv.text,
                      sub: "Max today " + Math.round(d.uv_index_max[0] * 10) / 10, subColor: uv.color },
                    { icon: "🌧️", label: "Rain today", value: d.precipitation_sum[0] + " " + card.wx.daily_units.precipitation_sum,
                      sub: c.precipitation > 0 ? "Now " + c.precipitation + " " + card.wx.current_units.precipitation + "/h" : "Dry right now" },
                    { icon: "☁️", label: "Cloud cover", value: c.cloud_cover + "%",
                      sub: c.cloud_cover < 20 ? "Clear sky" : c.cloud_cover < 60 ? "Some clouds" : "Overcast" },
                    { icon: "🧭", label: "Pressure", value: Math.round(c.pressure_msl) + " hPa",
                      sub: c.pressure_msl < 1005 ? "Low" : c.pressure_msl > 1020 ? "High" : "Normal" },
                    { icon: "👁️", label: "Visibility", value: card.imperial ? (c.visibility / 1609).toFixed(1) + " mi" : (c.visibility / 1000).toFixed(1) + " km",
                      sub: c.visibility >= 10000 ? "Clear" : c.visibility >= 4000 ? "Hazy" : "Poor" }
                ]
                if (card.aq && card.aq.us_aqi !== null) {
                    const a = Sky.aqiLevel(card.aq.us_aqi)
                    tiles.push({ icon: "🍃", label: "Air quality", value: card.aq.us_aqi + " " + a.text,
                                 sub: "PM2.5 " + Math.round(card.aq.pm2_5) + " · PM10 " + Math.round(card.aq.pm10), subColor: a.color })
                } else {
                    tiles.push({ icon: "🍃", label: "Air quality", value: "–", sub: "No data" })
                }
                if (sky.sun) {
                    const len = sky.setH - sky.riseH
                    tiles.push({ icon: "🌅", label: "Sunrise", value: Sky.clock(sky.sun.rise, card.use24),
                                 sub: "Noon " + Sky.clock(sky.sun.noon, card.use24) })
                    tiles.push({ icon: "🌇", label: "Sunset", value: Sky.clock(sky.sun.set, card.use24),
                                 sub: Math.floor(len) + "h " + Math.round((len % 1) * 60) + "m daylight" })
                } else {
                    tiles.push({ icon: "🌅", label: "Sunrise", value: "–", sub: "" })
                    tiles.push({ icon: "🌇", label: "Sunset", value: "–", sub: "" })
                }
                tiles.push({ icon: sky.moon.emoji, label: "Moon", value: Math.round(sky.moon.illumination * 100) + "% lit",
                             sub: sky.moon.name })
                return tiles
            }
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: tileCol.implicitHeight + Kirigami.Units.largeSpacing * 1.4
                radius: Kirigami.Units.cornerRadius * 2
                color: card.tileBg
                ColumnLayout {
                    id: tileCol
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing * 0.7
                    spacing: 1
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Text { text: modelData.icon; font.pixelSize: card.u * 0.95 }
                        Text { text: modelData.label; color: card.dim; font.pointSize: 8 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.value
                        color: card.fg
                        font.pointSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.sub
                        color: modelData.subColor || card.dim
                        font.pointSize: 8
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ---- Next 12 hours ----
    Text {
        visible: !card.compact && !!card.wx
        text: "Next 12 hours"
        color: card.dim
        font.pointSize: 9
        font.weight: Font.DemiBold
    }
    RowLayout {
        visible: !card.compact && !!card.wx
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: card.wx ? Math.min(12, card.wx.hourly.time.length) : 0
            delegate: ColumnLayout {
                required property int index
                readonly property var h: card.wx.hourly
                readonly property int pop: h.precipitation_probability[index] || 0
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: 2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: index === 0 ? "Now" : Sky.hourLabel(Sky.localTime(h.time[index]).getHours(), card.use24)
                    color: index === 0 ? card.fg : card.dim
                    font.pointSize: 8
                    font.weight: index === 0 ? Font.DemiBold : Font.Normal
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Sky.hourIcon(h.weather_code[index], h.is_day[index] === 1)
                    font.pixelSize: card.u * 1.25
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: card.deg(h.temperature_2m[index])
                    color: card.fg
                    font.pointSize: 9
                    font.weight: Font.DemiBold
                }
                // Rain chance as a small bar with the number under it.
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: card.u * 0.9
                    implicitHeight: card.u * 1.4
                    radius: 2
                    color: Qt.alpha("#8AADF4", 0.15)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * pop / 100
                        radius: 2
                        color: pop >= 50 ? "#8AADF4" : Qt.alpha("#8AADF4", 0.6)
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: pop + "%"
                    color: pop >= 30 ? "#8AADF4" : card.dim
                    font.pointSize: 7
                }
            }
        }
    }

    // ---- 7 days ----
    Text {
        visible: !card.compact && !!card.wx
        text: "7 days"
        color: card.dim
        font.pointSize: 9
        font.weight: Font.DemiBold
    }
    ColumnLayout {
        id: week
        visible: !card.compact && !!card.wx
        Layout.fillWidth: true
        spacing: 3
        readonly property var d: card.wx ? card.wx.daily : null
        readonly property real lo: d ? Math.min.apply(null, d.temperature_2m_min) : 0
        readonly property real hi: d ? Math.max.apply(null, d.temperature_2m_max) : 1

        Repeater {
            model: week.d ? week.d.time.length : 0
            delegate: RowLayout {
                required property int index
                readonly property var d: week.d
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 2
                Text {
                    Layout.preferredWidth: card.u * 3
                    text: index === 0 ? "Today" : Qt.formatDate(Sky.localTime(d.time[index] + "T12:00"), "ddd d")
                    color: index === 0 ? card.fg : card.dim
                    font.pointSize: 9
                    font.weight: index === 0 ? Font.DemiBold : Font.Normal
                }
                Text {
                    Layout.preferredWidth: card.u * 1.6
                    horizontalAlignment: Text.AlignHCenter
                    text: Sky.hourIcon(d.weather_code[index], true)
                    font.pixelSize: card.u * 1.15
                }
                Text {
                    Layout.preferredWidth: card.u * 3.2
                    text: "💧" + (d.precipitation_probability_max[index] || 0) + "%"
                    color: (d.precipitation_probability_max[index] || 0) >= 30 ? "#8AADF4" : card.dim
                    font.pointSize: 8
                }
                Text {
                    Layout.preferredWidth: card.u * 1.8
                    horizontalAlignment: Text.AlignRight
                    text: card.deg(d.temperature_2m_min[index])
                    color: card.dim
                    font.pointSize: 9
                }
                // The day's range on the week's scale, coloured cool to warm.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Qt.alpha(card.fg, 0.08)
                    }
                    Rectangle {
                        readonly property real span: Math.max(1, week.hi - week.lo)
                        x: parent.width * (d.temperature_2m_min[index] - week.lo) / span
                        width: Math.max(6, parent.width * (d.temperature_2m_max[index] - d.temperature_2m_min[index]) / span)
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#8AADF4" }
                            GradientStop { position: 0.5; color: "#EED49F" }
                            GradientStop { position: 1; color: "#F5A97F" }
                        }
                    }
                }
                Text {
                    Layout.preferredWidth: card.u * 1.8
                    text: card.deg(d.temperature_2m_max[index])
                    color: card.fg
                    font.pointSize: 9
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.preferredWidth: card.u * 3.6
                    horizontalAlignment: Text.AlignRight
                    text: "💨 " + Math.round(d.wind_speed_10m_max[index]) + " " + card.windUnit
                    color: card.dim
                    font.pointSize: 8
                }
            }
        }
    }

    Text {
        visible: !card.compact && !!card.cur
        Layout.alignment: Qt.AlignRight
        text: "Open-Meteo · updated " + (sky.updated ? Sky.clock(sky.updated, card.use24) : "–")
        color: card.dim
        font.pointSize: 7
    }
}
