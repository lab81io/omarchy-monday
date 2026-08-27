import QtQuick
import Quickshell
import Quickshell.Io

// Owns the monday.com polling loop and the parsed state the panel renders.
// The helper does every bit of network and schema work; this side only cares
// about running it on a timer, holding the last good result, and telling the
// panel whether the current state is data, an error, or a missing token.
Item {
  id: root

  property var settings: ({})
  property string pluginDir: ""

  property var items: []
  property var boards: []
  property string userName: ""
  property bool loading: false
  property bool loadedOnce: false
  property string lastError: ""
  property string errorKind: ""
  property double lastUpdated: 0

  readonly property bool needsToken: errorKind === "auth"
  readonly property bool failed: lastError !== ""
  readonly property int openCount: items ? items.length : 0
  readonly property string helperPath: pluginDir === "" ? "" : pluginDir + "/bin/monday-fetch"

  signal refreshed()

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var parsed = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(parsed)) parsed = fallback
    return Math.max(min, Math.min(max, parsed))
  }

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 300, 60, 3600)

  function refresh() {
    if (fetchProcess.running || helperPath === "") return
    loading = true
    fetchProcess.command = ["python3", helperPath]
    fetchProcess.running = true
  }

  function apply(raw) {
    var parsed
    try {
      parsed = JSON.parse(String(raw || ""))
    } catch (e) {
      lastError = "Could not parse the monday helper output"
      errorKind = "parse"
      return
    }
    if (!parsed || parsed.ok !== true) {
      lastError = String((parsed && parsed.error) || "monday.com fetch failed")
      errorKind = String((parsed && parsed.kind) || "error")
      return
    }
    // Only a clean result replaces the visible data; a transient network blip
    // leaves yesterday's list on screen with an error line above it rather
    // than blanking the panel.
    items = parsed.items || []
    boards = parsed.boards || []
    userName = String((parsed.me && parsed.me.name) || "")
    lastError = ""
    errorKind = ""
    loadedOnce = true
    lastUpdated = Date.now()
    root.refreshed()
  }

  function openUrl(url) {
    var target = String(url || "")
    if (target === "") return
    Quickshell.execDetached(["omarchy-launch-browser", target])
  }

  function openItem(item) {
    if (item) openUrl(item.url)
  }

  function openBoard(board) {
    if (board) openUrl(board.url)
  }

  function updatedLabel() {
    if (!loadedOnce) return "Never"
    var seconds = Math.max(0, Math.round((Date.now() - lastUpdated) / 1000))
    if (seconds < 60) return "Just now"
    var minutes = Math.round(seconds / 60)
    if (minutes < 60) return minutes + "m ago"
    return Math.round(minutes / 60) + "h ago"
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: root.helperPath !== ""
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: fetchProcess
    running: false
    command: []
    stdout: StdioCollector { id: fetchStdout; waitForEnd: true }
    stderr: StdioCollector { id: fetchStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      var out = String(fetchStdout.text || "")
      if (exitCode === 0 && out.trim() !== "") {
        root.apply(out)
        return
      }
      var err = String(fetchStderr.text || "").trim()
      root.errorKind = "helper"
      root.lastError = err !== ""
        ? err.split("\n").pop().substring(0, 160)
        : "monday helper exited with code " + exitCode
    }
  }
}
