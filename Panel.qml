import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "delay.lumen"
  ipcTarget: "delay.lumen"

  property string activeMode: "standard"
  property int temperature: 6500
  property int saturation: 100
  property int standardTemperature: 6500
  property int standardSaturation: 100
  property int redLightTemperature: 1000
  property int redLightSaturation: 100
  property int candleTemperature: 1800
  property int candleSaturation: 90
  property int blackWhiteTemperature: 6500
  property int blackWhiteSaturation: 0
  property int standardBrightness: -1
  property int redLightBrightness: -1
  property int candleBrightness: -1
  property int blackWhiteBrightness: -1
  property int colorInkTemperature: 6500
  property int colorInkSaturation: 40
  property int colorInkBrightness: -1
  property int vividTemperature: 6500
  property int vividSaturation: 160
  property int vividBrightness: -1
  property int currentBrightness: -1
  property string editingPreset: ""
  property string editPresetName: ""
  property int editTemperature: 6500
  property int editSaturation: 100
  property int editBrightness: 50
  property bool editBrightnessAuto: true
  property var customModes: []
  property string panelPage: "main"
  property string presetReturnPage: "main"
  property string managementAction: ""
  property string pendingCustomPreset: ""
  property bool scheduleEnabled: false
  property string scheduleTime1: "08:00"
  property string scheduleTime1Draft: ""
  property string schedulePreset1: "standard"
  property string scheduleTime2: "20:00"
  property string scheduleTime2Draft: ""
  property string schedulePreset2: "red-light"
  property bool scheduleDirty: false
  property string pendingMode: ""
  property string errorMessage: ""
  property int selectedIndex: modeIndex(activeMode)
  property string focusSection: "modes"
  property bool cursorActive: false

  readonly property string helperPath: decodeURIComponent(
    Qt.resolvedUrl("lumen").toString().replace(/^file:\/\//, ""))
  readonly property bool busy: pendingMode !== "" || managementProcess.running || scheduleProcess.running
  readonly property bool animationEnabled: setting("animationEnabled", true) !== false
  readonly property string hiddenPresets: String(setting("hiddenPresets", "") || "")
  readonly property bool brightnessAvailable: currentBrightness >= 1
  readonly property bool presetTransitionActive: isPresetId(pendingMode)
  readonly property string clockTimePattern: configuredClockTimePattern()
  readonly property bool uses12HourTime: clockTimePattern.indexOf("AP") >= 0
    || clockTimePattern.indexOf("ap") >= 0
  readonly property var builtinModes: [
    {
      id: "standard",
      name: "Standard",
      description: "Neutral daylight at 6500 K",
      temperature: root.standardTemperature,
      saturation: root.standardSaturation,
      brightness: root.standardBrightness,
      icon: "󰍹"
    },
    {
      id: "red-light",
      name: "Red Light",
      description: "Very warm light at 1000 K",
      temperature: root.redLightTemperature,
      saturation: root.redLightSaturation,
      brightness: root.redLightBrightness,
      icon: "󰌵"
    },
    {
      id: "candle",
      name: "Candle",
      description: "Warm candlelight at 1800 K",
      temperature: root.candleTemperature,
      saturation: root.candleSaturation,
      brightness: root.candleBrightness,
      icon: "󰗢"
    },
    {
      id: "black-white",
      name: "Black & White",
      description: "Neutral grayscale",
      temperature: root.blackWhiteTemperature,
      saturation: root.blackWhiteSaturation,
      brightness: root.blackWhiteBrightness,
      icon: "󱎖"
    },
    {
      id: "color-ink",
      name: "Color Ink",
      description: "Muted color paper display",
      temperature: root.colorInkTemperature,
      saturation: root.colorInkSaturation,
      brightness: root.colorInkBrightness,
      icon: "󰃣"
    },
    {
      id: "vivid",
      name: "Vivid",
      description: "Rich, highly saturated color",
      temperature: root.vividTemperature,
      saturation: root.vividSaturation,
      brightness: root.vividBrightness,
      icon: "󰏘"
    }
  ]
  readonly property var allModes: builtinModes.concat(customModes)
  readonly property var modes: allModes.filter(function(mode) { return !isPresetHidden(mode.id) })
  readonly property var presetOptions: allModes.map(function(mode) {
    return { value: mode.id, label: mode.name }
  })

  function isPresetHidden(mode) {
    return hiddenPresets.split(",").indexOf(mode) >= 0
  }

  function togglePresetVisibility(mode) {
    var ids = hiddenPresets === "" ? [] : hiddenPresets.split(",").filter(function(id) { return id !== "" })
    var index = ids.indexOf(mode)
    if (index >= 0) ids.splice(index, 1)
    else {
      if (modes.length <= 1) return
      ids.push(mode)
    }
    settings = Object.assign({}, settings, { hiddenPresets: ids.join(",") })
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, settings)
  }

  function isPresetId(mode) {
    for (var i = 0; i < allModes.length; i++) if (allModes[i].id === mode) return true
    return false
  }

  function modeIndex(mode) {
    for (var i = 0; i < modes.length; i++) if (modes[i].id === mode) return i
    return 0
  }

  function preset(mode) {
    for (var i = 0; i < allModes.length; i++) if (allModes[i].id === mode) return allModes[i]
    return builtinModes[0]
  }

  function refresh() {
    if (!customListProcess.running) customListProcess.running = true
    if (!scheduleStateProcess.running) scheduleStateProcess.running = true
    if (!stateProcess.running) stateProcess.running = true
  }

  function openSettings() {
    panelPage = "settings"
    editingPreset = ""
    focusSection = "settings"
  }

  function openSchedule() {
    syncScheduleDrafts()
    scheduleDirty = false
    panelPage = "schedule"
    focusSection = "schedule"
  }

  function configuredClockTimePattern() {
    if (bar && typeof bar.layoutEntries === "function") {
      var sections = ["left", "center", "right"]
      for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
        var entries = bar.layoutEntries(sections[sectionIndex])
        for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
          var entry = entries[entryIndex]
          var id = typeof entry === "string" ? entry : String(entry.id || "")
          if (id === "omarchy.clock")
            return String((typeof entry === "object" && entry.format) || "dddd HH:mm")
        }
      }
    }
    return Qt.locale().timeFormat(Locale.ShortFormat)
  }

  function formatScheduleTime(value) {
    var fields = String(value || "").split(":")
    if (fields.length !== 2) return String(value || "")
    var hour = Number(fields[0])
    var minute = Number(fields[1])
    if (!isFinite(hour) || !isFinite(minute)) return String(value || "")
    var paddedMinute = (minute < 10 ? "0" : "") + minute
    if (!uses12HourTime)
      return (hour < 10 ? "0" : "") + hour + ":" + paddedMinute
    var displayHour = hour % 12
    if (displayHour === 0) displayHour = 12
    var suffix = hour >= 12 ? Qt.locale().pmText : Qt.locale().amText
    return displayHour + ":" + paddedMinute + " " + suffix
  }

  function syncScheduleDrafts() {
    scheduleTime1Draft = formatScheduleTime(scheduleTime1)
    scheduleTime2Draft = formatScheduleTime(scheduleTime2)
  }

  function parseScheduleTime(value) {
    var text = String(value || "").trim().replace(/\s/g, "")
    var upper = text.toUpperCase()
    var locale = Qt.locale()
    var am = String(locale.amText || "AM").replace(/\s/g, "").toUpperCase()
    var pm = String(locale.pmText || "PM").replace(/\s/g, "").toUpperCase()
    var meridiem = ""
    if (am !== "" && upper.endsWith(am)) {
      meridiem = "am"
      text = text.slice(0, text.length - am.length)
    } else if (pm !== "" && upper.endsWith(pm)) {
      meridiem = "pm"
      text = text.slice(0, text.length - pm.length)
    } else if (upper.endsWith("AM")) {
      meridiem = "am"
      text = text.slice(0, -2)
    } else if (upper.endsWith("PM")) {
      meridiem = "pm"
      text = text.slice(0, -2)
    }

    var match = text.match(/^(\d{1,2}):(\d{2})$/)
    if (!match) return ""
    var hour = Number(match[1])
    var minute = Number(match[2])
    if (minute < 0 || minute > 59) return ""
    if (meridiem !== "") {
      if (hour < 1 || hour > 12) return ""
      hour = (hour % 12) + (meridiem === "pm" ? 12 : 0)
    } else if (hour < 0 || hour > 23 || uses12HourTime) {
      return ""
    }
    return (hour < 10 ? "0" : "") + hour + ":" + (minute < 10 ? "0" : "") + minute
  }

  function goBack() {
    if (panelPage === "preset") {
      editingPreset = ""
      panelPage = presetReturnPage
      focusSection = panelPage === "settings" ? "settings" : "modes"
    } else if (panelPage === "schedule") openSettings()
    else {
      panelPage = "main"
      focusSection = "modes"
      selectedIndex = modeIndex(activeMode)
    }
  }

  function chooseMode(mode) {
    if (busy || !isPresetId(mode)) return
    errorMessage = ""
    pendingMode = mode
    var command = [helperPath, "set", mode]
    var window = barButton.QsWindow.window
    if (animationEnabled && window && window.contentItem && window.screen
        && window.screen.width > 0 && window.screen.height > 0) {
      var origin = barButton.mapToItem(
        window.contentItem, barButton.width / 2, barButton.height / 2)
      command = command.concat([
        "--ripple", String(origin.x), String(origin.y),
        String(window.screen.width), String(window.screen.height)
      ])
    }
    actionProcess.command = command
    actionProcess.running = true
  }

  function toggleAnimation() {
    settings = Object.assign({}, settings, { animationEnabled: !animationEnabled })
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, settings)
  }

  function chooseSelected() {
    if (focusSection === "back") {
      closePresetSettings()
      return
    }
    if (focusSection === "modes" && selectedIndex >= 0 && selectedIndex < modes.length)
      chooseMode(modes[selectedIndex].id)
  }

  function openPresetSettings(preset, returnPage) {
    if (busy) return
    presetReturnPage = returnPage || "main"
    panelPage = "preset"
    editingPreset = preset
    var values = root.preset(preset)
    editPresetName = values.name
    editTemperature = values.temperature
    editSaturation = values.saturation
    editBrightnessAuto = values.brightness < 1
    editBrightness = values.brightness >= 1 ? values.brightness
      : (brightnessAvailable ? currentBrightness : 50)
    focusSection = "temperature"
  }

  function closePresetSettings() {
    goBack()
  }

  function addCustomPreset(name) {
    var clean = String(name || "").trim()
    if (clean === "" || managementProcess.running) return
    managementAction = "add"
    managementProcess.command = [helperPath, "add-preset", clean]
    managementProcess.running = true
  }

  function renameEditingPreset(name) {
    var clean = String(name || "").trim()
    if (clean === "" || editingPreset.indexOf("custom-") !== 0 || managementProcess.running) return
    managementAction = "rename"
    managementProcess.command = [helperPath, "rename-preset", editingPreset, clean]
    managementProcess.running = true
  }

  function deleteEditingPreset() {
    if (editingPreset.indexOf("custom-") !== 0 || managementProcess.running) return
    managementAction = "delete"
    managementProcess.command = [helperPath, "delete-preset", editingPreset]
    managementProcess.running = true
  }

  function saveSchedule() {
    if (scheduleProcess.running) return
    var firstTime = parseScheduleTime(scheduleTime1Draft)
    var secondTime = parseScheduleTime(scheduleTime2Draft)
    if (firstTime === "" || secondTime === "") {
      errorMessage = uses12HourTime
        ? "Enter times like 8:00 AM or 8:00 PM."
        : "Enter times in 24-hour format, like 08:00 or 20:00."
      return
    }
    errorMessage = ""
    scheduleEnabled = true
    scheduleTime1 = firstTime
    scheduleTime2 = secondTime
    scheduleProcess.command = [helperPath, "schedule-set", "1",
      firstTime, schedulePreset1, secondTime, schedulePreset2]
    scheduleProcess.running = true
  }

  function disableSchedule() {
    if (scheduleProcess.running) return
    errorMessage = ""
    scheduleEnabled = false
    scheduleDirty = true
    scheduleProcess.command = [helperPath, "schedule-set", "0",
      scheduleTime1, schedulePreset1, scheduleTime2, schedulePreset2]
    scheduleProcess.running = true
  }

  function saveEditingPreset(nextTemperature, nextSaturation, nextBrightness) {
    if (busy || editingPreset === "") return
    editTemperature = Math.max(1000, Math.min(7000, Math.round(nextTemperature / 100) * 100))
    editSaturation = Math.max(0, Math.min(200, Math.round(nextSaturation / 5) * 5))
    errorMessage = ""
    pendingMode = "settings"
    var brightness = nextBrightness === undefined
      ? (editBrightnessAuto ? "auto" : String(editBrightness))
      : String(nextBrightness)
    actionProcess.command = [helperPath, "set-preset", editingPreset,
      String(editTemperature), String(editSaturation), brightness]
    actionProcess.running = true
  }

  function setTemperature(value) {
    if (busy) return
    var next = Math.max(1000, Math.min(7000, Math.round(value / 100) * 100))
    saveEditingPreset(next, editSaturation)
  }

  function setSaturation(value) {
    if (busy) return
    var next = Math.max(0, Math.min(200, Math.round(value / 5) * 5))
    saveEditingPreset(editTemperature, next)
  }

  function setBrightness(value) {
    if (busy || !brightnessAvailable) return
    var next = Math.max(1, Math.min(100, Math.round(value)))
    editBrightness = next
    editBrightnessAuto = false
    saveEditingPreset(editTemperature, editSaturation, next)
  }

  function previewBrightness(value) {
    if (busy || !brightnessAvailable) return
    editBrightness = Math.max(1, Math.min(100, Math.round(value)))
    editBrightnessAuto = false
  }

  function toggleBrightnessAuto() {
    if (busy || !brightnessAvailable) return
    if (editBrightnessAuto) {
      editBrightnessAuto = false
      editBrightness = currentBrightness
      saveEditingPreset(editTemperature, editSaturation, currentBrightness)
    } else {
      editBrightnessAuto = true
      editBrightness = currentBrightness
      saveEditingPreset(editTemperature, editSaturation, "auto")
    }
  }

  function restoreEditingPreset() {
    if (busy || editingPreset === "") return
    var defaults = {
      "standard": [6500, 100],
      "red-light": [1000, 100],
      "candle": [1800, 90],
      "black-white": [6500, 0],
      "color-ink": [6500, 40],
      "vivid": [6500, 160]
    }[editingPreset]
    editTemperature = defaults[0]
    editSaturation = defaults[1]
    editBrightnessAuto = true
    if (brightnessAvailable) editBrightness = currentBrightness
    errorMessage = ""
    pendingMode = "restore"
    actionProcess.command = [helperPath, "reset-preset", editingPreset]
    actionProcess.running = true
  }

  Component.onCompleted: refresh()

  onOpenedChanged: {
    if (opened) {
      editingPreset = ""
      panelPage = "main"
      cursorActive = false
      focusSection = "modes"
      selectedIndex = modeIndex(activeMode)
      refresh()
    }
  }

  Process {
    id: stateProcess
    command: [root.helperPath, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var fields = String(text || "").trim().split(/\s+/)
        var mode = fields[0]
        if (root.isPresetId(mode) || mode === "custom") {
          root.activeMode = mode
          if (!root.cursorActive) {
            root.focusSection = "modes"
            root.selectedIndex = root.modeIndex(mode)
          }
        }
        var kelvin = parseInt(fields[1], 10)
        if (isFinite(kelvin)) root.temperature = Math.max(1000, Math.min(7000, kelvin))
        var saturationPercent = parseInt(fields[2], 10)
        if (isFinite(saturationPercent)) root.saturation = Math.max(0, Math.min(200, saturationPercent))
        var liveBrightness = parseInt(fields[3], 10)
        if (isFinite(liveBrightness)) root.currentBrightness = liveBrightness
        var standardKelvin = parseInt(fields[4], 10)
        var standardSat = parseInt(fields[5], 10)
        var standardBrightness = fields[6] === "auto" ? -1 : parseInt(fields[6], 10)
        var redKelvin = parseInt(fields[7], 10)
        var redSat = parseInt(fields[8], 10)
        var redBrightness = fields[9] === "auto" ? -1 : parseInt(fields[9], 10)
        if (isFinite(standardKelvin)) root.standardTemperature = standardKelvin
        if (isFinite(standardSat)) root.standardSaturation = standardSat
        if (isFinite(redKelvin)) root.redLightTemperature = redKelvin
        if (isFinite(redSat)) root.redLightSaturation = redSat
        if (isFinite(standardBrightness)) root.standardBrightness = standardBrightness
        if (isFinite(redBrightness)) root.redLightBrightness = redBrightness
        var candleKelvin = parseInt(fields[10], 10)
        var candleSat = parseInt(fields[11], 10)
        var candleBrightness = fields[12] === "auto" ? -1 : parseInt(fields[12], 10)
        var blackWhiteKelvin = parseInt(fields[13], 10)
        var blackWhiteSat = parseInt(fields[14], 10)
        var blackWhiteBrightness = fields[15] === "auto" ? -1 : parseInt(fields[15], 10)
        if (isFinite(candleKelvin)) root.candleTemperature = candleKelvin
        if (isFinite(candleSat)) root.candleSaturation = candleSat
        if (isFinite(blackWhiteKelvin)) root.blackWhiteTemperature = blackWhiteKelvin
        if (isFinite(blackWhiteSat)) root.blackWhiteSaturation = blackWhiteSat
        if (isFinite(candleBrightness)) root.candleBrightness = candleBrightness
        if (isFinite(blackWhiteBrightness)) root.blackWhiteBrightness = blackWhiteBrightness
        var colorInkKelvin = parseInt(fields[16], 10)
        var colorInkSat = parseInt(fields[17], 10)
        var colorInkBrightness = fields[18] === "auto" ? -1 : parseInt(fields[18], 10)
        var vividKelvin = parseInt(fields[19], 10)
        var vividSat = parseInt(fields[20], 10)
        var vividBrightness = fields[21] === "auto" ? -1 : parseInt(fields[21], 10)
        if (isFinite(colorInkKelvin)) root.colorInkTemperature = colorInkKelvin
        if (isFinite(colorInkSat)) root.colorInkSaturation = colorInkSat
        if (isFinite(colorInkBrightness)) root.colorInkBrightness = colorInkBrightness
        if (isFinite(vividKelvin)) root.vividTemperature = vividKelvin
        if (isFinite(vividSat)) root.vividSaturation = vividSat
        if (isFinite(vividBrightness)) root.vividBrightness = vividBrightness
        if (root.editingPreset !== "" && root.editBrightnessAuto && root.brightnessAvailable)
          root.editBrightness = root.currentBrightness
      }
    }
  }

  Process {
    id: customListProcess
    command: [root.helperPath, "custom-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result = []
        var lines = String(text || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          if (lines[i] === "") continue
          var fields = lines[i].split("\t")
          if (fields.length < 5) continue
          var brightness = fields[4] === "auto" ? -1 : parseInt(fields[4], 10)
          result.push({
            id: fields[0], name: Qt.atob(fields[1]), description: "Custom display preset",
            temperature: parseInt(fields[2], 10), saturation: parseInt(fields[3], 10),
            brightness: brightness, icon: "󰓎", custom: true
          })
        }
        root.customModes = result
        if (!stateProcess.running) stateProcess.running = true
        if (root.pendingCustomPreset !== "" && root.isPresetId(root.pendingCustomPreset)) {
          var target = root.pendingCustomPreset
          root.pendingCustomPreset = ""
          root.openPresetSettings(target, "settings")
        }
      }
    }
  }

  Process {
    id: managementProcess
    stdout: StdioCollector { id: managementOutput; waitForEnd: true }
    stderr: StdioCollector { id: managementError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorMessage = String(managementError.text || "Unable to update preset").trim()
      } else {
        var id = String(managementOutput.text || "").trim()
        if (root.managementAction === "add") root.pendingCustomPreset = id
        else if (root.managementAction === "delete") root.goBack()
        if (root.managementAction === "add") customPresetNameField.text = ""
      }
      root.managementAction = ""
      customListProcess.running = true
      scheduleStateProcess.running = true
    }
  }

  Process {
    id: scheduleStateProcess
    command: [root.helperPath, "schedule-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var fields = String(text || "").trim().split(/\s+/)
        if (fields.length < 5) return
        if (root.panelPage === "schedule" && root.scheduleDirty) return
        root.scheduleEnabled = fields[0] === "1"
        root.scheduleTime1 = fields[1]
        root.schedulePreset1 = fields[2]
        root.scheduleTime2 = fields[3]
        root.schedulePreset2 = fields[4]
        if (root.panelPage !== "schedule"
            || (!scheduleTime1Field.activeFocus && !scheduleTime2Field.activeFocus))
          root.syncScheduleDrafts()
      }
    }
  }

  Process {
    id: scheduleProcess
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: scheduleError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.errorMessage = String(scheduleError.text || "Unable to save schedule").trim()
      else {
        root.scheduleDirty = false
        scheduleCheckProcess.running = true
      }
      scheduleStateProcess.running = true
    }
  }

  Process {
    id: scheduleCheckProcess
    command: [root.helperPath, "schedule-check"]
    stdout: StdioCollector { waitForEnd: true }
    onExited: root.refresh()
  }

  Process {
    id: actionProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var mode = String(text || "").trim()
        if (root.isPresetId(mode) || mode === "custom") root.activeMode = mode
      }
    }
    stderr: StdioCollector {
      id: actionError
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.errorMessage = String(actionError.text || "Unable to change display mode").trim()
      root.pendingMode = ""
      root.refresh()
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: if (!scheduleCheckProcess.running) scheduleCheckProcess.running = true
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: "󰗢"
    tooltipText: "Lumen · " + (root.isPresetId(root.activeMode)
      ? root.preset(root.activeMode).name : root.temperature + " K · " + root.saturation + "%")

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.chooseMode("standard")
      else if (mouseButton === Qt.LeftButton) root.toggle()
    }

    // A visible scene-graph node must change to keep time-based screen shaders
    // advancing. The 0.1% scale pulse is imperceptible but cannot be culled as
    // hidden damage, unlike an occluded repaint sentinel.
    SequentialAnimation on scale {
      running: root.presetTransitionActive
      loops: Animation.Infinite
      NumberAnimation { from: 1.0; to: 0.999; duration: 16 }
      NumberAnimation { from: 0.999; to: 1.0; duration: 16 }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: scheduleTime1Field.activeFocus || scheduleTime2Field.activeFocus
        || customPresetNameField.activeFocus || editPresetNameField.activeFocus

      onMoveRequested: function(dx, dy) {
        root.cursorActive = true
        if (root.focusSection === "temperature") {
          if (dx !== 0) root.setTemperature(root.editTemperature + dx * 100)
          else if (dy < 0) root.focusSection = "back"
          else if (dy > 0) root.focusSection = "saturation"
          return
        }
        if (root.focusSection === "saturation") {
          if (dx !== 0) root.setSaturation(root.editSaturation + dx * 5)
          else if (dy < 0) root.focusSection = "temperature"
          else if (dy > 0 && root.brightnessAvailable) root.focusSection = "brightness"
          return
        }
        if (root.focusSection === "brightness") {
          if (dx !== 0) root.setBrightness(root.editBrightness + dx * 5)
          else if (dy < 0) root.focusSection = "saturation"
          return
        }
        if (root.focusSection === "back") {
          if (dy > 0 && root.panelPage === "preset") root.focusSection = "temperature"
          return
        }
        if (root.panelPage !== "main") return
        if (dx > 0) {
          root.openPresetSettings(root.modes[root.selectedIndex].id)
          root.focusSection = "temperature"
        }
        else if (dy < 0)
          root.selectedIndex = Math.max(0, root.selectedIndex - 1)
        else if (dy > 0 && root.selectedIndex < root.modes.length - 1)
          root.selectedIndex++
        else if (dy > 0 && root.editingPreset !== "")
          root.focusSection = "temperature"
      }
      onActivateRequested: root.chooseSelected()
      onCloseRequested: {
        if (root.panelPage !== "main") root.goBack()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Row {
          visible: root.panelPage === "main"
          width: parent.width
          spacing: Style.space(12)

          Text {
            textFormat: Text.PlainText
            text: "󰗢"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - parent.children[0].implicitWidth
              - mainSettingsButton.width - parent.spacing * 2
            spacing: Style.space(2)

            Text {
              text: "Lumen"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: "DISPLAY MODE"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }

          PanelActionButton {
            id: mainSettingsButton
            anchors.verticalCenter: parent.verticalCenter
            size: Style.space(32)
            iconText: ""
            tooltipText: "Lumen settings"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            enabled: !root.busy
            onClicked: root.openSettings()
          }
        }

        Row {
          visible: root.panelPage !== "main"
          width: parent.width
          spacing: Style.space(10)

          PanelActionButton {
            id: backButton
            anchors.verticalCenter: parent.verticalCenter
            size: Style.space(32)
            iconText: "󰁍"
            tooltipText: "Back"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            hasCursor: root.cursorActive && root.focusSection === "back"
            enabled: !root.busy
            onHovered: function(hovered) {
              if (hovered) {
                root.cursorActive = true
                root.focusSection = "back"
              }
            }
            onClicked: root.goBack()
          }

          Column {
            width: parent.width - backButton.width - parent.spacing
            spacing: Style.space(2)

            Text {
              text: root.panelPage === "settings" ? "Settings"
                : (root.panelPage === "schedule" ? "Schedule" : root.preset(root.editingPreset).name)
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: root.panelPage === "settings" ? "LUMEN"
                : (root.panelPage === "schedule" ? "DAILY PRESETS" : "PRESET SETTINGS")
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          visible: root.panelPage === "main"
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.modes

            Item {
              required property var modelData
              required property int index
              width: parent.width
              height: presetButton.implicitHeight

              HoverHandler {
                id: presetHover
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.focusSection = "modes"
                  root.selectedIndex = parent.index
                }
              }

              Button {
                id: presetButton
                anchors.fill: parent
                text: modelData.name
                iconText: modelData.icon
                leftAlign: true
                bordered: true
                active: root.activeMode === modelData.id
                hasCursor: root.cursorActive && root.focusSection === "modes"
                  && root.selectedIndex === index
                enabled: !root.busy
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                rightPadding: settingsButton.size + Style.space(8)
                verticalPadding: Style.spacing.controlPaddingY + Style.space(3)
                onClicked: root.chooseMode(modelData.id)
                onHovered: function(hovered) {
                  if (hovered) {
                    root.cursorActive = true
                    root.focusSection = "modes"
                    root.selectedIndex = index
                  }
                }
              }

              PanelActionButton {
                id: settingsButton
                anchors.right: parent.right
                anchors.rightMargin: Style.space(5)
                anchors.verticalCenter: parent.verticalCenter
                size: parent.height - Style.space(8)
                iconText: ""
                tooltipText: "Edit " + modelData.name
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                bordered: false
                visible: presetHover.hovered || root.editingPreset === modelData.id
                hasCursor: root.editingPreset === modelData.id
                enabled: !root.busy
                onClicked: root.openPresetSettings(modelData.id)
              }
            }
          }
        }

        Column {
          visible: root.panelPage === "settings"
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "ADD CUSTOM PRESET"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: customPresetNameField
              width: parent.width - addCustomButton.width - parent.spacing
              placeholderText: "Preset name"
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily
              enabled: !root.busy
              onAccepted: root.addCustomPreset(text)
            }

            PanelActionButton {
              id: addCustomButton
              size: customPresetNameField.implicitHeight
              iconText: "󰐕"
              tooltipText: "Add preset"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              enabled: customPresetNameField.text.trim() !== "" && !root.busy
              onClicked: root.addCustomPreset(customPresetNameField.text)
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          PanelSectionHeader {
            text: "ACTIVE PRESETS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Repeater {
            model: root.allModes

            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width - visibilitySwitch.width
                  - (modelData.custom ? manageCustomButton.width + parent.spacing * 2 : parent.spacing)
                text: modelData.icon + "  " + modelData.name
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }

              PanelActionButton {
                id: manageCustomButton
                visible: modelData.custom === true
                size: Style.space(26)
                iconText: ""
                tooltipText: "Edit " + modelData.name
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: root.openPresetSettings(modelData.id, "settings")
              }

              ToggleSwitch {
                id: visibilitySwitch
                checked: !root.isPresetHidden(modelData.id)
                trackHeight: Style.space(16)
                cursorPad: Style.space(2)
                foreground: root.bar.foreground
                busy: root.busy
                onToggled: root.togglePresetVisibility(modelData.id)
              }
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Button {
            width: parent.width
            text: root.scheduleEnabled ? "Daily Schedule · On" : "Daily Schedule · Off"
            iconText: "󰔠"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            enabled: !root.busy
            onClicked: root.openSchedule()
          }

          PanelSeparator { foreground: root.bar.foreground }

          Row {
            width: parent.width

            Text {
              text: "Animate preset changes"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - parent.children[0].implicitWidth - settingsAnimationSwitch.width; height: 1 }
            ToggleSwitch {
              id: settingsAnimationSwitch
              anchors.verticalCenter: parent.verticalCenter
              checked: root.animationEnabled
              trackHeight: Style.space(16)
              cursorPad: Style.space(2)
              foreground: root.bar.foreground
              busy: root.busy
              onToggled: root.toggleAnimation()
            }
          }
        }

        Column {
          visible: root.panelPage === "schedule"
          width: parent.width
          spacing: Style.space(10)

          Row {
            width: parent.width
            Text {
              text: "Enable daily schedule"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - parent.children[0].implicitWidth - scheduleEnabledSwitch.width; height: 1 }
            ToggleSwitch {
              id: scheduleEnabledSwitch
              anchors.verticalCenter: parent.verticalCenter
              checked: root.scheduleEnabled
              trackHeight: Style.space(16)
              cursorPad: Style.space(2)
              foreground: root.bar.foreground
              onToggled: {
                if (root.scheduleEnabled) root.disableSchedule()
                else {
                  root.scheduleEnabled = true
                  root.scheduleDirty = true
                }
              }
            }
          }

          PanelSectionHeader {
            text: "FIRST SWITCH"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }
          Row {
            width: parent.width
            spacing: Style.space(6)
            TextField {
              id: scheduleTime1Field
              width: root.uses12HourTime ? Style.space(112) : Style.space(78)
              text: root.scheduleTime1Draft
              placeholderText: root.uses12HourTime ? "8:00 AM" : "08:00"
              inputMethodHints: root.uses12HourTime ? Qt.ImhNone : Qt.ImhTime
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily
              onTextChanged: {
                root.scheduleTime1Draft = text
                if (activeFocus) root.scheduleDirty = true
              }
              onActiveFocusChanged: if (activeFocus)
                Qt.callLater(function() { scheduleTime1Field.selectAll() })
            }
            Dropdown {
              width: parent.width - scheduleTime1Field.width - parent.spacing
              showLabel: false
              value: root.schedulePreset1
              options: root.presetOptions
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onChanged: function(value) {
                root.schedulePreset1 = value
                root.scheduleDirty = true
              }
            }
          }

          PanelSectionHeader {
            text: "SECOND SWITCH"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }
          Row {
            width: parent.width
            spacing: Style.space(6)
            TextField {
              id: scheduleTime2Field
              width: root.uses12HourTime ? Style.space(112) : Style.space(78)
              text: root.scheduleTime2Draft
              placeholderText: root.uses12HourTime ? "8:00 PM" : "20:00"
              inputMethodHints: root.uses12HourTime ? Qt.ImhNone : Qt.ImhTime
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily
              onTextChanged: {
                root.scheduleTime2Draft = text
                if (activeFocus) root.scheduleDirty = true
              }
              onActiveFocusChanged: if (activeFocus)
                Qt.callLater(function() { scheduleTime2Field.selectAll() })
            }
            Dropdown {
              width: parent.width - scheduleTime2Field.width - parent.spacing
              showLabel: false
              value: root.schedulePreset2
              options: root.presetOptions
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onChanged: function(value) {
                root.schedulePreset2 = value
                root.scheduleDirty = true
              }
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: root.uses12HourTime
              ? "Use your system's 12-hour time format. Scheduled changes run once at each daily switch."
              : "Use your system's 24-hour time format. Scheduled changes run once at each daily switch."
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Button {
            width: parent.width
            text: "Save & Activate Schedule"
            iconText: "󰆓"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            enabled: !root.busy
            onClicked: root.saveSchedule()
          }
        }

        PanelSeparator {
          visible: root.editingPreset !== ""
          foreground: root.bar.foreground
        }

        Column {
          visible: root.editingPreset !== ""
          width: parent.width
          spacing: Style.space(6)

          Column {
            visible: root.editingPreset.indexOf("custom-") === 0
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "PRESET NAME"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(6)
              TextField {
                id: editPresetNameField
                width: parent.width - savePresetNameButton.width - parent.spacing
                text: root.editPresetName
                foreground: root.bar.foreground
                font.family: root.bar.fontFamily
                enabled: !root.busy
                onTextChanged: root.editPresetName = text
                onAccepted: root.renameEditingPreset(text)
              }
              PanelActionButton {
                id: savePresetNameButton
                size: editPresetNameField.implicitHeight
                iconText: "󰆓"
                tooltipText: "Save name"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                bordered: true
                enabled: root.editPresetName.trim() !== "" && !root.busy
                onClicked: root.renameEditingPreset(root.editPresetName)
              }
            }

            PanelSeparator { foreground: root.bar.foreground }
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(temperatureHeader.implicitHeight, temperatureValue.implicitHeight)

            PanelSectionHeader {
              id: temperatureHeader
              text: root.preset(root.editingPreset).name.toUpperCase() + " · TEMPERATURE"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: temperatureValue
              textFormat: Text.PlainText
              text: Math.round(temperatureSlider.dragging ? temperatureSlider.liveValue : root.editTemperature) + " K"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          CursorSurface {
            width: parent.width
            height: temperatureSlider.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.focusSection === "temperature"
            foreground: root.bar.foreground
            outline: true

            PanelSlider {
              id: temperatureSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 1000
              maximum: 7000
              step: 100
              value: root.editTemperature
              integer: true
              tickCount: 7
              enabled: !root.busy
              onReleased: function(value) { root.setTemperature(value) }
            }

            HoverHandler {
              onHoveredChanged: if (hovered) {
                root.cursorActive = true
                root.focusSection = "temperature"
              }
            }
          }

          Row {
            width: parent.width

            Text {
              text: "WARM · 1000 K"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { width: parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth; height: 1 }
            Text {
              text: "7000 K · COOL"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        PanelSeparator {
          visible: root.editingPreset !== ""
          foreground: root.bar.foreground
        }

        Column {
          visible: root.editingPreset !== ""
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            implicitHeight: Math.max(saturationHeader.implicitHeight, saturationValue.implicitHeight)

            PanelSectionHeader {
              id: saturationHeader
              text: "SATURATION"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: saturationValue
              textFormat: Text.PlainText
              text: Math.round(saturationSlider.dragging ? saturationSlider.liveValue : root.editSaturation) + "%"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          CursorSurface {
            width: parent.width
            height: saturationSlider.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.focusSection === "saturation"
            foreground: root.bar.foreground
            outline: true

            PanelSlider {
              id: saturationSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 0
              maximum: 200
              step: 5
              value: root.editSaturation
              integer: true
              tickCount: 5
              enabled: !root.busy
              onReleased: function(value) { root.setSaturation(value) }
            }

            HoverHandler {
              onHoveredChanged: if (hovered) {
                root.cursorActive = true
                root.focusSection = "saturation"
              }
            }
          }

          Row {
            width: parent.width

            Text {
              text: "GRAYSCALE · 0%"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { width: parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth; height: 1 }
            Text {
              text: "200% · VIVID"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Item {
            width: parent.width
            implicitHeight: Math.max(brightnessHeader.implicitHeight, brightnessValue.implicitHeight)

            PanelSectionHeader {
              id: brightnessHeader
              text: "BRIGHTNESS"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: brightnessValue
              textFormat: Text.PlainText
              text: !root.brightnessAvailable ? "UNAVAILABLE"
                : (root.editBrightnessAuto ? "AUTO · " : "")
                  + Math.round(brightnessSlider.dragging
                    ? brightnessSlider.liveValue : root.editBrightness) + "%"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: "AUTO"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }

            Item {
              width: parent.width - parent.children[0].implicitWidth
                - brightnessAutoSwitch.width - parent.spacing * 2
              height: 1
            }

            ToggleSwitch {
              id: brightnessAutoSwitch
              anchors.verticalCenter: parent.verticalCenter
              checked: root.editBrightnessAuto
              trackHeight: Style.space(16)
              cursorPad: Style.space(2)
              foreground: root.bar.foreground
              busy: root.busy
              enabled: root.brightnessAvailable && !root.busy
              onToggled: root.toggleBrightnessAuto()

              PanelToolTip {
                visible: brightnessAutoSwitch.containsMouse
                text: root.editBrightnessAuto
                  ? "Use a brightness override" : "Restore display brightness"
                fontFamily: root.bar.fontFamily
              }
            }
          }

          CursorSurface {
            width: parent.width
            height: brightnessSlider.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.focusSection === "brightness"
            foreground: root.bar.foreground
            outline: true

            PanelSlider {
              id: brightnessSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 1
              maximum: 100
              step: 1
              value: root.editBrightness
              integer: true
              tickCount: 5
              enabled: root.brightnessAvailable && !root.busy
              onMoved: function(value) { root.previewBrightness(value) }
              onReleased: function(value) { root.setBrightness(value) }
            }

            HoverHandler {
              onHoveredChanged: if (hovered) {
                root.cursorActive = true
                root.focusSection = "brightness"
              }
            }
          }

          Row {
            width: parent.width

            Text {
              text: "DIM · 1%"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { width: parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth; height: 1 }
            Text {
              text: "100% · BRIGHT"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Button {
            width: parent.width
            text: "Restore Defaults"
            iconText: "󰑐"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            enabled: !root.busy
            onClicked: root.restoreEditingPreset()
          }

          Button {
            visible: root.editingPreset.indexOf("custom-") === 0
            width: parent.width
            text: "Delete Custom Preset"
            iconText: "󰆴"
            bordered: true
            foreground: root.bar.urgent
            fontFamily: root.bar.fontFamily
            enabled: !root.busy
            onClicked: root.deleteEditingPreset()
          }
        }

        Text {
          visible: root.busy || root.errorMessage !== ""
          width: parent.width
          wrapMode: Text.Wrap
          text: root.busy
            ? (managementProcess.running ? "Updating presets…"
              : (scheduleProcess.running ? "Saving schedule…"
                : ((root.pendingMode === "settings" || root.pendingMode === "restore")
                  ? "Saving preset…" : "Applying " + root.pendingMode.replace("-", " ") + "…")))
            : root.errorMessage
          color: root.errorMessage !== "" ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          visible: root.panelPage === "main"
          width: parent.width
          wrapMode: Text.Wrap
          text: "Right-click the bar icon to return to Standard."
          color: Qt.darker(root.bar.foreground, 1.55)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
