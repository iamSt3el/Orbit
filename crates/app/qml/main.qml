import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import com.filemanager.app 1.0

Window {
    id: window
    width: 1000
    height: 650
    visible: true
    title: "File Manager"
    color: Color.scheme.surface

    property string _pendingDeleteName: ""
    property bool _pendingDeleteIsSelection: false

    // A same-named alias, not just "fileModel" — `fileModel` itself is an
    // id, not a property of Window, so `window.fileModel` doesn't exist
    // (silently evaluates to undefined). Any popup below that's created
    // via a Loader's sourceComponent AND declares its own `property var
    // fileModel` needs this alias (`window.fileListModel`) instead of the
    // bare `fileModel` id — the bare id resolves to that popup's own
    // not-yet-set property once it's instantiated from inside a Loader's
    // Component boundary, not the outer FileListModel, leaving it null.
    // (Confirmed: the un-Loader'd, statically-nested version of these
    // same popups did not have this problem — it's specific to crossing
    // a Loader/Component boundary.)
    property alias fileListModel: fileModel

    // viewMode and iconSizeLevel live on fileModel (persisted to
    // settings.json) rather than as plain window properties, so they
    // survive a restart — see FileListModel.saveSettings().
    readonly property var iconSizeProfiles: ({
        small: { listIcon: 18, listContainer: 32, gridIcon: 24, gridContainer: 44, gridCell: 104, gridMinWidth: 90 },
        medium: { listIcon: 22, listContainer: 40, gridIcon: 32, gridContainer: 56, gridCell: 132, gridMinWidth: 110 },
        large: { listIcon: 28, listContainer: 48, gridIcon: 40, gridContainer: 68, gridCell: 160, gridMinWidth: 132 }
    })
    readonly property var activeIconProfile: iconSizeProfiles[fileModel.iconSizeLevel] || iconSizeProfiles.medium

    FileListModel {
        id: fileModel

        Component.onCompleted: {
            // A singleton (Color.qml) can be instantiated before this
            // object exists, so it can't read the theme file itself —
            // read it here (Rust-side, not QML XHR — see
            // FileListModel.readThemeColorsFile()) now that fileModel
            // is ready.
            Color.applyCustomColors(fileModel.readThemeColorsFile())
            // CLI arg wins if given; otherwise resume wherever the last
            // session left off (if that's enabled in Settings); otherwise
            // fall back to home.
            var startPath = Qt.application.arguments.length > 1
                ? Qt.application.arguments[1]
                : (fileModel.resumeLastPath && fileModel.savedLastPath.length > 0 ? fileModel.savedLastPath : "/home")
            navigate(startPath)
        }
    }

    function parentPath(path) {
        var idx = path.lastIndexOf("/")
        if (idx <= 0) {
            return "/"
        }
        return path.substring(0, idx)
    }

    // Wheel notches deliver angleDelta in eighths of a degree — 120 units
    // is one physical "click" of a standard mouse wheel. Scrolling by a
    // fixed, larger-than-default number of pixels per notch here (instead
    // of relying on Flickable's own small default step) is what "increase
    // the scroll distance" means in practice.
    function applyWheelScroll(view, wheel) {
        var maxY = Math.max(0, view.contentHeight - view.height)
        view.contentY = Math.max(0, Math.min(maxY, view.contentY - (wheel.angleDelta.y / 120) * 180))
        wheel.accepted = true
    }

    // Popup helpers — every dialog/menu at the bottom of this file lives
    // behind a Loader that stays inactive (no instance, no cost) until one
    // of these is called, and tears itself back down again via each
    // component's `closed` signal. Callers throughout this file go through
    // these instead of touching a menu/dialog id directly, since that id
    // now only resolves to something real once its Loader is active.
    function openContextMenu(x, y) {
        contextMenuLoader.active = true
        contextMenuLoader.item.canPaste = fileModel.canPaste()
        contextMenuLoader.item.popup(x, y)
    }

    function openNewFolderDialog() {
        newFolderDialogLoader.active = true
        newFolderDialogLoader.item.open()
    }

    function openViewOptionsMenu(x, y) {
        viewOptionsMenuLoader.active = true
        viewOptionsMenuLoader.item.popup(x, y)
    }

    function openItemContextMenu(x, y, name, isDir, size, modified, mimeType, permissions) {
        itemContextMenuLoader.active = true
        itemContextMenuLoader.item.popup(x, y, name, isDir, size, modified, mimeType, permissions, fileModel.selectedCount())
    }

    function openRenameDialog(name) {
        renameDialogLoader.active = true
        renameDialogLoader.item.open(name)
    }

    function openPropertiesDialog(name, isDir, size, modified, mimeType, permissions) {
        propertiesDialogLoader.active = true
        propertiesDialogLoader.item.open(name, isDir, size, modified, mimeType, permissions)
    }

    function openDeleteConfirmDialog(name) {
        window._pendingDeleteName = name
        window._pendingDeleteIsSelection = false
        deleteConfirmDialogLoader.active = true
        deleteConfirmDialogLoader.item.open("Move \"" + name + "\" to Trash?")
    }

    function openDeleteSelectionConfirmDialog(count) {
        window._pendingDeleteIsSelection = true
        deleteConfirmDialogLoader.active = true
        deleteConfirmDialogLoader.item.open("Move " + count + " items to Trash?")
    }

    function openTrashContextMenu(x, y) {
        trashContextMenuLoader.active = true
        trashContextMenuLoader.item.popup(x, y)
    }

    function openEmptyTrashConfirmDialog() {
        emptyTrashConfirmDialogLoader.active = true
        emptyTrashConfirmDialogLoader.item.open("Permanently delete everything in Trash? This can't be undone.")
    }

    function openSettingsDialog() {
        settingsDialogLoader.active = true
        settingsDialogLoader.item.open()
    }

    // Invisible helper for "Copy Path" — TextEdit.copy() writes the current
    // selection straight to the system clipboard, no extra module needed.
    TextEdit {
        id: clipboardHelper
        visible: false
        function copyText(text) {
            clipboardHelper.text = text
            clipboardHelper.selectAll()
            clipboardHelper.copy()
        }
    }

    // Ctrl+A selects everything in the current folder. A window-level
    // Shortcut, not a Keys handler on the view — the view doesn't hold
    // keyboard focus today, and a Shortcut doesn't need it to. If a
    // TextInput has focus (rename dialog, search field) and the user
    // presses Ctrl+A meaning "select all text in this field," that
    // TextInput's own built-in handling takes the key first — Shortcut
    // only fires when nothing more specific already consumed it.
    Shortcut {
        sequence: StandardKey.SelectAll
        onActivated: fileModel.selectAll()
    }

    // Layout modeled on the user's quickshell "Nebula" settings app: a
    // single unified card (surfaceContainer) holding the sidebar and
    // content side by side with no gap between them — the sidebar's own
    // surfaceContainerHigh fill and independent corner radius is what
    // visually separates it, not a literal gutter. Unlike Nebula's
    // per-page dialog, there's no separate app-wide top bar: the "right
    // layout" (back button, path/search, theme toggle, list/grid switch)
    // lives inside the content pane as its own header, and the sidebar
    // gets its own header (title + settings entry point) instead.
    //
    // Built with RowLayout/ColumnLayout rather than plain Row/Column so
    // fill-space sizing (the content pane, the grid/list area, the header)
    // is handled by Layout.fillWidth/fillHeight instead of hand-computed
    // "parent.width - 200" arithmetic.
    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Shape.largeIncreased
            color: Color.scheme.surfaceContainer
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Sidebar {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 200
                    fileModel: fileModel
                    currentPath: fileModel.currentPath ? fileModel.currentPath : ""
                    onSettingsRequested: window.openSettingsDialog()
                    onTrashContextMenuRequested: (x, y) => window.openTrashContextMenu(x, y)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    TopAppBar {
                        id: contentHeader
                        Layout.fillWidth: true
                        // Fixed, not just preferred — without min/max
                        // pinned to the same value the header could be
                        // compressed by the layout, and the file view
                        // below (sized from contentHeader.height) would
                        // creep up underneath it.
                        Layout.preferredHeight: 56
                        Layout.minimumHeight: 56
                        Layout.maximumHeight: 56
                        title: fileModel.currentPath ? fileModel.currentPath : ""
                        showBackButton: fileModel.currentPath && fileModel.currentPath !== "/"
                        viewMode: fileModel.viewMode
                        fileModel: fileModel
                        onBackClicked: fileModel.navigate(window.parentPath(fileModel.currentPath))
                        onListViewRequested: {
                            fileModel.viewMode = "list"
                            fileModel.saveSettings()
                        }
                        onGridViewRequested: {
                            fileModel.viewMode = "grid"
                            fileModel.saveSettings()
                        }
                        onOptionsRequested: (x, y) => window.openViewOptionsMenu(x, y)
                    }

                    Item {
                        id: fileViewArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Component {
                            id: listComponent

                            ListView {
                                id: listView
                                anchors.fill: parent
                                anchors.margins: 4
                                anchors.rightMargin: 14
                                model: fileModel
                                spacing: 2
                                reuseItems: true
                                cacheBuffer: 400
                                acceptedButtons: Qt.NoButton
                                // Last plain- or Ctrl-clicked name, for
                                // Shift+click range math — transient UI
                                // state, not part of "what's selected"
                                // (that lives in fileModel), so it's kept
                                // here rather than in Rust.
                                property string selectionAnchor: ""
                                delegate: FileListItem {
                                    iconSize: window.activeIconProfile.listIcon
                                    iconContainerSize: window.activeIconProfile.listContainer
                                    onContextMenuRequested: (x, y) =>
                                        window.openItemContextMenu(x, y, name, isDir, size, modified, mimeType, permissions)
                                }

                                MouseArea {
                                    // Stacked below the delegates (which live inside
                                    // listView's contentItem) so a right-click over an
                                    // item reaches FileListItem's own MouseArea first;
                                    // this one only fires for clicks that miss every
                                    // delegate, i.e. genuinely empty space. Left-button
                                    // press-and-drag here rubber-band-selects; a plain
                                    // click (no drag) just clears the selection, and a
                                    // right-click clears it too before opening the
                                    // background context menu.
                                    id: listBackgroundArea
                                    z: -1
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: false

                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool dragging: false

                                    onWheel: (wheel) => window.applyWheelScroll(listView, wheel)

                                    onPressed: (mouse) => {
                                        if (mouse.button !== Qt.LeftButton) {
                                            return
                                        }
                                        listBackgroundArea.pressX = mouse.x
                                        listBackgroundArea.pressY = mouse.y
                                        listBackgroundArea.dragging = false
                                        if (!(mouse.modifiers & Qt.ControlModifier)) {
                                            fileModel.clearSelection()
                                        }
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!listBackgroundArea.pressed || !(listBackgroundArea.pressedButtons & Qt.LeftButton)) {
                                            return
                                        }
                                        var dx = mouse.x - listBackgroundArea.pressX
                                        var dy = mouse.y - listBackgroundArea.pressY
                                        // A small movement threshold before treating this
                                        // as a drag at all — otherwise every plain click
                                        // (which always has a tiny bit of jitter) would
                                        // flash the selection rectangle for one frame.
                                        if (!listBackgroundArea.dragging && Math.sqrt(dx * dx + dy * dy) < 6) {
                                            return
                                        }
                                        listBackgroundArea.dragging = true

                                        listSelectionRect.x = Math.min(listBackgroundArea.pressX, mouse.x)
                                        listSelectionRect.y = Math.min(listBackgroundArea.pressY, mouse.y)
                                        listSelectionRect.width = Math.abs(mouse.x - listBackgroundArea.pressX)
                                        listSelectionRect.height = Math.abs(mouse.y - listBackgroundArea.pressY)
                                        listSelectionRect.visible = true

                                        // listBackgroundArea's own coordinates are
                                        // viewport-relative; contentItem's children
                                        // (the delegates) are positioned in
                                        // content-relative coordinates — offset by the
                                        // current scroll position to compare them.
                                        var rectLeft = listSelectionRect.x + listView.contentX
                                        var rectTop = listSelectionRect.y + listView.contentY
                                        var rectRight = rectLeft + listSelectionRect.width
                                        var rectBottom = rectTop + listSelectionRect.height

                                        // Only currently-visible (already-instantiated)
                                        // delegates can be swept — no auto-scroll while
                                        // dragging near an edge (see this plan's Global
                                        // Constraints).
                                        var children = listView.contentItem.children
                                        for (var i = 0; i < children.length; i++) {
                                            var child = children[i]
                                            if (child.name === undefined) {
                                                continue
                                            }
                                            var overlaps = child.x < rectRight && (child.x + child.width) > rectLeft &&
                                                           child.y < rectBottom && (child.y + child.height) > rectTop
                                            if (overlaps) {
                                                fileModel.setSelected(child.name, true)
                                            }
                                        }
                                    }

                                    onReleased: {
                                        listSelectionRect.visible = false
                                        listBackgroundArea.dragging = false
                                    }

                                    onClicked: (mouse) => {
                                        if (listBackgroundArea.dragging) {
                                            return
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            fileModel.clearSelection()
                                            var scenePos = listBackgroundArea.mapToItem(null, mouse.x, mouse.y)
                                            window.openContextMenu(scenePos.x, scenePos.y)
                                        }
                                    }
                                }

                                Rectangle {
                                    id: listSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }

                                ScrollBar {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: -12
                                    flickable: listView
                                }
                            }
                        }

                        Component {
                            id: gridComponent

                            GridView {
                                id: gridView
                                anchors.fill: parent
                                anchors.margins: 4
                                anchors.rightMargin: 14
                                model: fileModel
                                property string selectionAnchor: ""
                                readonly property int minCellWidth: window.activeIconProfile.gridMinWidth
                                readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))
                                // Not Math.floor()'d — GridView's cellWidth accepts a
                                // fractional value fine, and truncating it here would
                                // leave up to (columns - 1) px of unfilled space on
                                // the right, which is exactly the bug this is fixing.
                                cellWidth: width / columns
                                cellHeight: window.activeIconProfile.gridCell
                                reuseItems: true
                                cacheBuffer: 400
                                acceptedButtons: Qt.NoButton
                                // GridView doesn't always relayout existing cells when
                                // cellWidth changes mid-flight (e.g. the panel resizing
                                // after the grid already has content) — force it so a
                                // resize can't leave the last recomputed cellWidth
                                // stale and the row short of the panel's right edge.
                                onWidthChanged: forceLayout()
                                delegate: FileGridItem {
                                    iconSize: window.activeIconProfile.gridIcon
                                    iconContainerSize: window.activeIconProfile.gridContainer
                                    onContextMenuRequested: (x, y) =>
                                        window.openItemContextMenu(x, y, name, isDir, size, modified, mimeType, permissions)
                                }

                                MouseArea {
                                    // See the matching comment in the ListView's
                                    // overlay above — kept below the delegates in
                                    // z-order so per-item right-clicks win. Same
                                    // left-button drag-select behavior as
                                    // listBackgroundArea.
                                    id: gridBackgroundArea
                                    z: -1
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: false

                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool dragging: false

                                    onWheel: (wheel) => window.applyWheelScroll(gridView, wheel)

                                    onPressed: (mouse) => {
                                        if (mouse.button !== Qt.LeftButton) {
                                            return
                                        }
                                        gridBackgroundArea.pressX = mouse.x
                                        gridBackgroundArea.pressY = mouse.y
                                        gridBackgroundArea.dragging = false
                                        if (!(mouse.modifiers & Qt.ControlModifier)) {
                                            fileModel.clearSelection()
                                        }
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!gridBackgroundArea.pressed || !(gridBackgroundArea.pressedButtons & Qt.LeftButton)) {
                                            return
                                        }
                                        var dx = mouse.x - gridBackgroundArea.pressX
                                        var dy = mouse.y - gridBackgroundArea.pressY
                                        if (!gridBackgroundArea.dragging && Math.sqrt(dx * dx + dy * dy) < 6) {
                                            return
                                        }
                                        gridBackgroundArea.dragging = true

                                        gridSelectionRect.x = Math.min(gridBackgroundArea.pressX, mouse.x)
                                        gridSelectionRect.y = Math.min(gridBackgroundArea.pressY, mouse.y)
                                        gridSelectionRect.width = Math.abs(mouse.x - gridBackgroundArea.pressX)
                                        gridSelectionRect.height = Math.abs(mouse.y - gridBackgroundArea.pressY)
                                        gridSelectionRect.visible = true

                                        var rectLeft = gridSelectionRect.x + gridView.contentX
                                        var rectTop = gridSelectionRect.y + gridView.contentY
                                        var rectRight = rectLeft + gridSelectionRect.width
                                        var rectBottom = rectTop + gridSelectionRect.height

                                        var children = gridView.contentItem.children
                                        for (var i = 0; i < children.length; i++) {
                                            var child = children[i]
                                            if (child.name === undefined) {
                                                continue
                                            }
                                            var overlaps = child.x < rectRight && (child.x + child.width) > rectLeft &&
                                                           child.y < rectBottom && (child.y + child.height) > rectTop
                                            if (overlaps) {
                                                fileModel.setSelected(child.name, true)
                                            }
                                        }
                                    }

                                    onReleased: {
                                        gridSelectionRect.visible = false
                                        gridBackgroundArea.dragging = false
                                    }

                                    onClicked: (mouse) => {
                                        if (gridBackgroundArea.dragging) {
                                            return
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            fileModel.clearSelection()
                                            var scenePos = gridBackgroundArea.mapToItem(null, mouse.x, mouse.y)
                                            window.openContextMenu(scenePos.x, scenePos.y)
                                        }
                                    }
                                }

                                Rectangle {
                                    id: gridSelectionRect
                                    visible: false
                                    color: Qt.alpha(Color.scheme.primary, 0.16)
                                    border.width: 1
                                    border.color: Color.scheme.primary
                                }

                                ScrollBar {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: -12
                                    flickable: gridView
                                }
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: fileModel.viewMode === "grid" ? gridComponent : listComponent
                        }
                    }
                }
            }
        }
    }

    // Menus and dialogs are anchored to the whole Window, not just
    // contentArea — their dimmed backdrop needs to cover the top bar and
    // sidebar too, not stop at the file listing's edge. Each lives behind
    // a Loader that's inactive (no instance at all) until one of the
    // window.openX() helpers above activates it, and deactivates itself
    // again via its `closed` signal — so the ~10 popups this app can show
    // cost nothing at startup or while none of them are open.
    Loader {
        id: contextMenuLoader
        anchors.fill: parent
        active: false
        sourceComponent: ContextMenu {
            onNewFolderRequested: window.openNewFolderDialog()
            onOpenTerminalRequested: fileModel.openTerminalHere()
            onPasteRequested: fileModel.pasteEntry()
            onSelectAllRequested: fileModel.selectAll()
            onClosed: Qt.callLater(() => contextMenuLoader.active = false)
        }
    }

    Loader {
        id: newFolderDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: NewFolderDialog {
            onAccepted: (name) => fileModel.createFolder(name)
            onClosed: Qt.callLater(() => newFolderDialogLoader.active = false)
        }
    }

    Loader {
        id: viewOptionsMenuLoader
        anchors.fill: parent
        active: false
        sourceComponent: ViewOptionsMenu {
            fileModel: window.fileListModel
            onIconSizeSelected: (level) => {
                fileModel.iconSizeLevel = level
                fileModel.saveSettings()
            }
            onClosed: Qt.callLater(() => viewOptionsMenuLoader.active = false)
        }
    }

    Loader {
        id: itemContextMenuLoader
        anchors.fill: parent
        active: false
        sourceComponent: ItemContextMenu {
            id: itemContextMenu
            onOpenRequested: (name) => {
                if (itemContextMenu.entryIsDir) {
                    fileModel.navigate(fileModel.currentPath + "/" + name)
                } else {
                    fileModel.openEntry(name)
                }
            }
            onRenameRequested: (name) => window.openRenameDialog(name)
            onDuplicateRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.duplicateSelection()
                } else {
                    fileModel.duplicateEntry(name)
                }
            }
            onCopyPathRequested: (name) => clipboardHelper.copyText(fileModel.entryAbsolutePath(name))
            onCopyRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.copySelection()
                } else {
                    fileModel.copyEntry(name)
                }
            }
            onCutRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.cutSelection()
                } else {
                    fileModel.cutEntry(name)
                }
            }
            onDeleteRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    window.openDeleteSelectionConfirmDialog(itemContextMenu.selectionCount)
                } else {
                    window.openDeleteConfirmDialog(name)
                }
            }
            onPropertiesRequested: (name, isDir, size, modified, mimeType, permissions) =>
                window.openPropertiesDialog(name, isDir, size, modified, mimeType, permissions)
            onClosed: Qt.callLater(() => itemContextMenuLoader.active = false)
        }
    }

    Loader {
        id: renameDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: RenameDialog {
            onAccepted: (oldName, newName) => fileModel.renameEntry(oldName, newName)
            onClosed: Qt.callLater(() => renameDialogLoader.active = false)
        }
    }

    Loader {
        id: propertiesDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: PropertiesDialog {
            fileModel: window.fileListModel
            onClosed: Qt.callLater(() => propertiesDialogLoader.active = false)
        }
    }

    Loader {
        id: deleteConfirmDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: ConfirmDialog {
            title: "Move to Trash"
            confirmLabel: "Delete"
            onConfirmed: {
                if (window._pendingDeleteIsSelection) {
                    fileModel.deleteSelection()
                } else {
                    fileModel.deleteEntry(window._pendingDeleteName)
                }
            }
            onClosed: Qt.callLater(() => deleteConfirmDialogLoader.active = false)
        }
    }

    Loader {
        id: trashContextMenuLoader
        anchors.fill: parent
        active: false
        sourceComponent: TrashContextMenu {
            onEmptyTrashRequested: window.openEmptyTrashConfirmDialog()
            onClosed: Qt.callLater(() => trashContextMenuLoader.active = false)
        }
    }

    Loader {
        id: emptyTrashConfirmDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: ConfirmDialog {
            title: "Empty Trash"
            confirmLabel: "Empty Trash"
            onConfirmed: fileModel.emptyTrash()
            onClosed: Qt.callLater(() => emptyTrashConfirmDialogLoader.active = false)
        }
    }

    Loader {
        id: settingsDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: SettingsDialog {
            fileModel: window.fileListModel
            onClosed: Qt.callLater(() => settingsDialogLoader.active = false)
        }
    }
}
