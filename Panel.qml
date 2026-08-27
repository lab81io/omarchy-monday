import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// monday.com in the Omarchy bar: an open-work count on the bar itself, and a
// two-tab popup — the items assigned to you, bucketed by how late they are,
// and a status rollup per watched board.
Panel {
  id: root
  moduleName: "lab81io.monday"
  ipcTarget: "lab81io.monday"
  manageIpc: false

  property string tab: "work"
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Quickshell hands QML file:// URLs; the helper needs a plain path.
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return url.replace(/\/$/, "")
  }

  readonly property var workRows: Model.rowsFor(monday.items)
  readonly property var flatItems: Model.flatten(Model.groupItems(monday.items))
  readonly property int overdue: Model.overdueCount(monday.items)
  readonly property int cursorCount: tab === "work" ? flatItems.length : (monday.boards ? monday.boards.length : 0)
  readonly property color barTint: overdue > 0 ? (bar ? bar.urgent : Color.urgent) : barForeground
  readonly property string barCount: monday.needsToken ? "—" : Model.barLabel(monday.items)

  function switchTab(next) {
    if (next === tab) return
    tab = next
    cursorIndex = 0
    if (panelFlick) panelFlick.contentY = 0
  }

  function clampCursor() {
    if (cursorCount === 0) {
      cursorIndex = 0
      return
    }
    cursorIndex = Math.max(0, Math.min(cursorCount - 1, cursorIndex))
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    if (dx !== 0) {
      switchTab(dx > 0 ? "boards" : "work")
      return
    }
    if (dy === 0 || cursorCount === 0) return
    cursorIndex = Math.max(0, Math.min(cursorCount - 1, cursorIndex + dy))
    scrollCursorIntoView()
  }

  function activateCursor() {
    if (cursorCount === 0) return
    clampCursor()
    if (tab === "work") monday.openItem(flatItems[cursorIndex])
    else monday.openBoard(monday.boards[cursorIndex])
  }

  function setCursor(index) {
    cursorActive = true
    cursorIndex = index
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function scrollCursorIntoView() {
    var host = tab === "work" ? workColumn : boardColumn
    if (!host) return
    for (var i = 0; i < host.children.length; i++) {
      var child = host.children[i]
      if (child && child.cursorSlot === root.cursorIndex) {
        scrollItemIntoView(child)
        return
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    if (panelFlick) panelFlick.contentY = 0
    monday.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: monday
    settings: root.settings
    pluginDir: root.pluginDir
  }

  Connections {
    target: monday
    function onRefreshed() { root.clampCursor() }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { monday.refresh(); return "ok" }
    function count(): string { return String(monday.openCount) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : Math.max(Style.space(28), barContent.implicitWidth + Style.spaceReal(7) * 2)
    fixedHeight: vertical ? Math.max(Style.space(28), barContent.implicitHeight + Style.spaceReal(5) * 2) : -1
    tooltipText: monday.needsToken
      ? "monday.com — no API token set"
      : (monday.failed ? "monday.com — " + monday.lastError : "monday.com — " + Model.summaryLine(monday.items))

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) monday.refresh()
      else if (buttonCode === Qt.MiddleButton) monday.openUrl("https://monday.com/")
      else root.toggle()
    }

    Grid {
      id: barContent
      anchors.centerIn: parent
      columns: button.vertical ? 1 : 2
      rows: button.vertical ? 2 : 1
      columnSpacing: Style.space(5)
      rowSpacing: Style.space(1)
      horizontalItemAlignment: Grid.AlignHCenter
      verticalItemAlignment: Grid.AlignVCenter

      MondayIcon {
        iconSize: Style.space(12)
        color: root.barTint
        opacity: monday.needsToken || monday.failed ? 0.45 : 1.0
      }

      Text {
        text: root.barCount
        color: root.barTint
        font.family: root.fontFamily
        font.pixelSize: button.vertical ? Style.font.caption : Style.font.body
        renderType: Text.NativeRendering
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(580))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = String(t).toLowerCase()
        if (key === "r") monday.refresh()
        else if (key === "1") root.switchTab("work")
        else if (key === "2") root.switchTab("boards")
        else if (key === "o") root.activateCursor()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "monday.com"
            meta: monday.needsToken
              ? "No API token"
              : (monday.loading && !monday.loadedOnce ? "Loading…" : Model.summaryLine(monday.items))
            detail: monday.loadedOnce ? "Updated " + monday.updatedLabel() : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              MondayIcon {
                iconSize: Style.font.display
                color: root.overdue > 0 ? root.urgent : root.foreground
              }
            }
            trailingControl: Component {
              PanelActionButton {
                iconText: "󰑐"
                tooltipText: "Refresh"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !monday.loading
                onClicked: monday.refresh()
              }
            }
          }

          Text {
            visible: monday.failed
            width: parent.width
            text: monday.needsToken
              ? "Add a monday.com API token to ~/.config/omarchy/monday/token, then press r."
              : monday.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }

          ButtonGroup {
            id: tabs
            options: [
              { value: "work", label: "My work" },
              { value: "boards", label: "Boards" }
            ]
            value: root.tab
            foreground: root.foreground
            background: bar ? bar.background : Color.background
            accent: Color.accent
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            focusable: false
            onChanged: function(value) { root.switchTab(value) }
          }

          // ---- My work ----------------------------------------------------

          Text {
            visible: root.tab === "work" && monday.loadedOnce && root.flatItems.length === 0 && !monday.failed
            width: parent.width
            text: "Nothing open assigned to you."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            id: workColumn
            visible: root.tab === "work" && root.flatItems.length > 0
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: root.workRows
              delegate: Loader {
                required property var modelData
                readonly property int cursorSlot: modelData.kind === "item" ? modelData.index : -1
                width: workColumn.width
                sourceComponent: modelData.kind === "header" ? headerComponent : itemComponent

                Component {
                  id: headerComponent
                  Item {
                    implicitHeight: headerLabel.implicitHeight + Style.space(10)
                    PanelSectionHeader {
                      id: headerLabel
                      anchors.left: parent.left
                      anchors.bottom: parent.bottom
                      anchors.leftMargin: Style.space(10)
                      text: modelData.title + "  (" + modelData.count + ")"
                      foreground: modelData.title === "OVERDUE" ? root.urgent : root.foreground
                      fontFamily: root.fontFamily
                    }
                  }
                }

                Component {
                  id: itemComponent
                  ItemRow {
                    item: modelData.item
                    rowIndex: modelData.index
                  }
                }
              }
            }
          }

          // ---- Boards -----------------------------------------------------

          Text {
            visible: root.tab === "boards" && monday.loadedOnce && (!monday.boards || monday.boards.length === 0)
            width: parent.width
            text: "No boards being watched."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            id: boardColumn
            visible: root.tab === "boards" && monday.boards && monday.boards.length > 0
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: monday.boards
              delegate: BoardRow {
                required property var modelData
                required property int index
                readonly property int cursorSlot: index
                width: boardColumn.width
                board: modelData
                rowIndex: index
              }
            }
          }

          Text {
            visible: monday.loadedOnce
            width: parent.width
            text: "r refresh · ←/→ tabs · ↑/↓ move · ⏎ open in browser"
            color: Qt.darker(root.foreground, 1.9)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component ItemRow: CursorSurface {
    id: itemRow
    property var item: null
    property int rowIndex: 0

    readonly property string dueText: item ? Model.dueLabel(item.due) : ""
    readonly property bool late: item ? (Model.dayDelta(item.due) !== null && Model.dayDelta(item.due) < 0) : false

    hasCursor: root.cursorActive && root.tab === "work" && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: itemContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(itemRow.rowIndex)
      onClicked: monday.openItem(itemRow.item)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      // The board's own label colour, so a status reads the same here as it
      // does in monday itself.
      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        width: Style.space(8)
        height: Style.space(8)
        radius: width / 2
        color: itemRow.item && itemRow.item.statusColor ? itemRow.item.statusColor : root.dim
      }

      ColumnLayout {
        id: itemContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: itemRow.item ? String(itemRow.item.name) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: itemRow.item
            ? Model.elide(itemRow.item.board, 34) + (itemRow.item.status ? " · " + itemRow.item.status : "")
            : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        visible: itemRow.dueText !== ""
        text: itemRow.dueText
        color: itemRow.late ? root.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  component BoardRow: CursorSurface {
    id: boardRow
    property var board: null
    property int rowIndex: 0

    readonly property var counts: Model.boardCounts(board)

    hasCursor: root.cursorActive && root.tab === "boards" && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: boardContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(boardRow.rowIndex)
      onClicked: monday.openBoard(boardRow.board)
    }

    ColumnLayout {
      id: boardContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(4)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          text: boardRow.board ? String(boardRow.board.name) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          text: Model.boardSummary(boardRow.board)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // One rule per board, split into the real monday label colours in
      // proportion — the whole board's state readable at a glance.
      Row {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(3)
        visible: boardRow.counts.total > 0
        spacing: 0

        Repeater {
          model: boardRow.board ? boardRow.board.labels : []
          delegate: Rectangle {
            required property var modelData
            height: Style.space(3)
            width: boardRow.counts.total > 0
              ? Math.max(1, (boardRow.width - Style.space(20)) * (modelData.count / boardRow.counts.total))
              : 0
            color: modelData.color ? modelData.color : Qt.darker(root.foreground, 2.2)
            opacity: 0.85
          }
        }
      }
    }
  }
}
