import QtQuick
import qs.Commons

// Three rounded strokes, in the spirit of the monday.com mark. Drawn rather
// than set in a Nerd Font glyph so it stays recognisable at bar size and does
// not depend on which patched font the user has picked.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  Row {
    anchors.centerIn: parent
    spacing: Math.max(1, root.iconSize * 0.13)

    Stroke { factor: 0.62 }
    Stroke { factor: 1.0 }
    Stroke { factor: 0.78 }
  }

  // Each stroke sits in a full-height slot so the Row can lay them out
  // side by side while the bars stay optically centred on one another.
  component Stroke: Item {
    property real factor: 1.0
    width: Math.max(2, root.iconSize * 0.17)
    height: root.iconSize

    Rectangle {
      anchors.centerIn: parent
      width: parent.width
      height: Math.max(4, root.iconSize * 0.78 * parent.factor)
      radius: width / 2
      color: root.color
    }
  }
}
