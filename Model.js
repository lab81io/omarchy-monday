.pragma library

// Pure helpers for the monday plugin: bucketing by due date, label text, and
// the small bits of formatting the panel repeats. Kept out of Panel.qml so the
// grouping is evaluated against *today* on every render rather than frozen at
// fetch time — a popup left open overnight still says "Overdue" correctly.

var GROUPS = [
  { key: "overdue", title: "OVERDUE" },
  { key: "today", title: "TODAY" },
  { key: "week", title: "THIS WEEK" },
  { key: "later", title: "LATER" },
  { key: "none", title: "NO DATE" }
]

function startOfToday() {
  var now = new Date()
  return new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

function parseDue(iso) {
  if (!iso) return null
  var parts = String(iso).split("-")
  if (parts.length < 3) return null
  var year = parseInt(parts[0], 10)
  var month = parseInt(parts[1], 10)
  var day = parseInt(parts[2], 10)
  if (!isFinite(year) || !isFinite(month) || !isFinite(day)) return null
  return new Date(year, month - 1, day)
}

// Whole days from today. Negative is late, 0 is today.
function dayDelta(iso) {
  var due = parseDue(iso)
  if (!due) return null
  return Math.round((due.getTime() - startOfToday().getTime()) / 86400000)
}

function groupKey(item) {
  var delta = dayDelta(item ? item.due : "")
  if (delta === null) return "none"
  if (delta < 0) return "overdue"
  if (delta === 0) return "today"
  if (delta <= 7) return "week"
  return "later"
}

// [{ key, title, items }] with empty buckets dropped, in urgency order.
function groupItems(items) {
  var buckets = {}
  var i
  for (i = 0; i < GROUPS.length; i++) buckets[GROUPS[i].key] = []
  for (i = 0; i < (items || []).length; i++) {
    var item = items[i]
    buckets[groupKey(item)].push(item)
  }
  var out = []
  for (i = 0; i < GROUPS.length; i++) {
    var group = GROUPS[i]
    if (buckets[group.key].length > 0) {
      out.push({ key: group.key, title: group.title, items: buckets[group.key] })
    }
  }
  return out
}

// Flat list in the same order the groups render, so keyboard navigation can
// walk one index across section boundaries.
function flatten(groups) {
  var out = []
  for (var g = 0; g < groups.length; g++) {
    for (var i = 0; i < groups[g].items.length; i++) out.push(groups[g].items[i])
  }
  return out
}

var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function dueLabel(iso) {
  var delta = dayDelta(iso)
  if (delta === null) return ""
  if (delta < 0) return delta === -1 ? "1 day late" : (-delta) + " days late"
  if (delta === 0) return "Today"
  if (delta === 1) return "Tomorrow"
  var due = parseDue(iso)
  if (delta <= 7) return WEEKDAYS[due.getDay()]
  return due.getDate() + " " + MONTHS[due.getMonth()]
}

function overdueCount(items) {
  var count = 0
  for (var i = 0; i < (items || []).length; i++) {
    var delta = dayDelta(items[i].due)
    if (delta !== null && delta < 0) count += 1
  }
  return count
}

function dueTodayCount(items) {
  var count = 0
  for (var i = 0; i < (items || []).length; i++) {
    if (dayDelta(items[i].due) === 0) count += 1
  }
  return count
}

// Bar text: the open count, with a trailing "!" only when something is late.
function barLabel(items) {
  var total = (items || []).length
  if (total === 0) return "0"
  return overdueCount(items) > 0 ? total + "!" : String(total)
}

function summaryLine(items) {
  var total = (items || []).length
  if (total === 0) return "Nothing assigned to you"
  var late = overdueCount(items)
  var today = dueTodayCount(items)
  var parts = []
  if (late > 0) parts.push(late + " overdue")
  if (today > 0) parts.push(today + " due today")
  var noun = total === 1 ? "open item" : "open items"
  return parts.length > 0 ? total + " " + noun + " · " + parts.join(" · ") : total + " " + noun
}

function boardCounts(board) {
  var counts = (board && board.counts) || {}
  return {
    open: counts.open || 0,
    stuck: counts.stuck || 0,
    done: counts.done || 0,
    total: counts.total || 0
  }
}

function boardSummary(board) {
  var counts = boardCounts(board)
  if (counts.total === 0) return "No items"
  return counts.open + " open · " + counts.stuck + " stuck · " + counts.done + " done"
}

// Fraction complete, for the thin progress rule under each board row.
function boardProgress(board) {
  var counts = boardCounts(board)
  if (counts.total === 0) return 0
  return counts.done / counts.total
}

function elide(text, max) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  if (value.length <= max) return value
  return value.substring(0, Math.max(0, max - 1)) + "…"
}

// Flat render list mixing section headers with items, so the panel can drive
// one Repeater and one linear cursor index across section boundaries.
function rowsFor(items) {
  var groups = groupItems(items)
  var out = []
  var cursor = 0
  for (var g = 0; g < groups.length; g++) {
    out.push({ kind: "header", title: groups[g].title, count: groups[g].items.length, index: -1 })
    for (var i = 0; i < groups[g].items.length; i++) {
      out.push({ kind: "item", item: groups[g].items[i], index: cursor })
      cursor += 1
    }
  }
  return out
}

// Strip anything Qt's AutoText heuristic could latch onto as rich text.
// Panel.qml pins textFormat: Text.PlainText on everything it renders itself,
// but the bar tooltip is drawn by the shell's shared PanelToolTip, whose Text
// this plugin does not control — so text headed there is cleaned here instead.
function plain(text) {
  return String(text || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
}
