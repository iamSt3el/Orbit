import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "util/format.js" as Format
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
    property string _pendingDeletePermanentlyName: ""
    property bool _pendingDeletePermanentlyIsSelection: false
    // Which pinned folder the open PinnedContextMenu acts on.
    property string _pendingUnpinPath: ""

    // True for the duration of a drag started by this app's own
    // FileListItem/FileGridItem (see their _startDrag()/Drag.onDragFinished).
    // DragEvent.keys turned out not to reliably carry the source's Drag.keys
    // across this platform's native drag-and-drop round-trip, so this plain
    // app-local flag is what DropAreas actually use to tell an internal drag
    // apart from a genuinely external one — not drop.keys.
    property bool _internalDragActive: false
    // Where the current internal drag started. Empty-space drops back
    // into this folder are no-ops; anywhere else (after spring-loading
    // into a subfolder mid-drag) they're a move into the current folder.
    property string _internalDragSourceDir: ""

    // Every file drag runs through this one persistent item instead of
    // the delegate that initiated it. A delegate is destroyed whenever
    // the listing changes under it — spring-loaded folder navigation
    // mid-drag, a watcher refresh removing the dragged row — and
    // deleting the Drag.Automatic source while the native drag loop is
    // running crashes Qt ("QObject: shared QObject was deleted
    // directly", then SIGSEGV). This proxy's lifetime matches the
    // window's, so no listing change can pull it out from under an
    // active drag.
    Item {
        id: dragProxy
        width: 1
        height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.keys: ["text/uri-list", "application/x-filemanager-internal"]
        Drag.onDragFinished: {
            dragProxy.Drag.active = false
            window._internalDragActive = false
            window._internalDragSourceDir = ""
        }
    }

    // Called by FileListItem/FileGridItem's _startDrag() once their
    // grabToImage snapshot is ready — mime data and image must both be
    // set before Drag.active starts the native drag.
    function startInternalDrag(urisJoined, imageUrl) {
        window._internalDragActive = true
        window._internalDragSourceDir = fileModel.currentPath
        dragProxy.Drag.mimeData = { "text/uri-list": urisJoined }
        dragProxy.Drag.imageSource = imageUrl
        dragProxy.Drag.active = true
    }

    // Shared by the two view-background DropAreas and the edge
    // auto-scroll strips: a drop on empty space imports/moves into the
    // current folder. An internal drag dropped back into the folder it
    // STARTED from is a no-op, not an import — dropped anywhere else
    // (after spring-loading into a subfolder mid-drag) it's a move.
    // window._internalDragActive / _internalDragSourceDir, not drop.keys,
    // which doesn't reliably carry the source's Drag.keys across this
    // platform's native drag-and-drop round-trip.
    function handleEmptySpaceDrop(drop) {
        if (!drop.hasUrls) {
            return
        }
        if (window._internalDragActive && window._internalDragSourceDir === fileModel.currentPath) {
            drop.accepted = false
            return
        }
        var isMove = window._internalDragActive || drop.proposedAction === Qt.MoveAction
        drop.acceptProposedAction()
        var paths = []
        for (var i = 0; i < drop.urls.length; i++) {
            // decodeURIComponent: QUrl.toString() is percent-encoded, so a
            // dropped "my photo.jpg" otherwise arrives as a literal
            // "my%20photo.jpg" path and every operation on it fails.
            paths.push(decodeURIComponent(drop.urls[i].toString().replace("file://", "")))
        }
        fileModel.dropPaths(paths.join("\n"), fileModel.currentPath, isMove)
    }

    // Preview pane visibility (round-2 item 22) — session-only state,
    // toggled by F9 or the header's info button.
    property bool previewVisible: false

    // Direction of the most recent navigation — "forward" (into a child),
    // "back" (up to an ancestor), or "neutral" (sidebar jump, path edit).
    // Derived from path prefixes in fileModel.onCurrentPathChanged and
    // consumed by viewEntrance when the listing lands; Rust deliberately
    // has no direction concept.
    property string _lastPath: ""
    property string _navDirection: "neutral"

    // Keyboard focus lives on fileViewArea (see its Keys handler). Every
    // dialog/menu steals focus while open; hand it back the moment the
    // last popup closes so arrows/type-ahead keep working without an
    // extra click.
    onAnyPopupOpenChanged: if (!anyPopupOpen) fileViewArea.forceActiveFocus()

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
        large: { listIcon: 28, listContainer: 48, gridIcon: 40, gridContainer: 68, gridCell: 160, gridMinWidth: 132 },
        extraLarge: { listIcon: 36, listContainer: 56, gridIcon: 48, gridContainer: 80, gridCell: 188, gridMinWidth: 150 }
    })
    readonly property var activeIconProfile: iconSizeProfiles[fileModel.iconSizeLevel] || iconSizeProfiles.medium

    FileListModel {
        id: fileModel

        // Reactive, not one-shot — themeColorsText is kept live by a
        // background watcher (FileListModel.startThemeColorsWatch()), so
        // editing colors.json while the app is running re-applies the
        // theme automatically, not just at startup.
        onThemeColorsTextChanged: Color.applyCustomColors(fileModel.themeColorsText)

        onCurrentPathChanged: {
            var oldPath = window._lastPath
            var newPath = fileModel.currentPath
            if (oldPath.length === 0) {
                window._navDirection = "neutral"
            } else if (newPath.startsWith(oldPath === "/" ? "/" : oldPath + "/")) {
                window._navDirection = "forward"
            } else if (oldPath.startsWith(newPath === "/" ? "/" : newPath + "/")) {
                window._navDirection = "back"
            } else {
                window._navDirection = "neutral"
            }
            window._lastPath = newPath
        }

        Component.onCompleted: {
            // A singleton (Color.qml) can be instantiated before this
            // object exists, so it can't read the theme file itself —
            // this is Rust-side file I/O (see FileListModel.
            // startThemeColorsWatch()), not QML XHR, now that fileModel
            // is ready.
            fileModel.startThemeColorsWatch()
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

    // Ctrl+wheel steps the icon size through the four levels (round-2
    // item 19), persisted like the ViewOptionsMenu path.
    readonly property var _iconSizeOrder: ["small", "medium", "large", "extraLarge"]
    function stepIconSize(up) {
        var idx = window._iconSizeOrder.indexOf(fileModel.iconSizeLevel)
        if (idx < 0) {
            idx = 1
        }
        var next = Math.max(0, Math.min(window._iconSizeOrder.length - 1, idx + (up ? 1 : -1)))
        if (window._iconSizeOrder[next] !== fileModel.iconSizeLevel) {
            fileModel.iconSizeLevel = window._iconSizeOrder[next]
            fileModel.saveSettings()
        }
    }

    // Wheel notches deliver angleDelta in eighths of a degree — 120 units
    // is one physical "click" of a standard mouse wheel. Scrolling by a
    // fixed, larger-than-default number of pixels per notch here (instead
    // of relying on Flickable's own small default step) is what "increase
    // the scroll distance" means in practice.
    function applyWheelScroll(view, wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            window.stepIconSize(wheel.angleDelta.y > 0)
            wheel.accepted = true
            return
        }
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

    function openNewFileDialog() {
        newFileDialogLoader.active = true
        newFileDialogLoader.item.open()
    }

    function openViewOptionsMenu(x, y) {
        viewOptionsMenuLoader.active = true
        viewOptionsMenuLoader.item.popup(x, y)
    }

    function openItemContextMenu(x, y, name, isDir, size, modified, mimeType, permissions) {
        itemContextMenuLoader.active = true
        itemContextMenuLoader.item.popup(x, y, name, isDir, size, modified, mimeType, permissions, fileModel.selectedCount(), fileModel.currentPath === fileModel.trashPath)
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

    function openDeletePermanentlyConfirmDialog(name) {
        window._pendingDeletePermanentlyName = name
        window._pendingDeletePermanentlyIsSelection = false
        deletePermanentlyConfirmDialogLoader.active = true
        deletePermanentlyConfirmDialogLoader.item.open("Permanently delete \"" + name + "\"? This can't be undone.")
    }

    function openDeletePermanentlySelectionConfirmDialog(count) {
        window._pendingDeletePermanentlyIsSelection = true
        deletePermanentlyConfirmDialogLoader.active = true
        deletePermanentlyConfirmDialogLoader.item.open("Permanently delete " + count + " items? This can't be undone.")
    }

    function openTrashContextMenu(x, y) {
        trashContextMenuLoader.active = true
        trashContextMenuLoader.item.popup(x, y)
    }

    function openOpenWithDialog(name) {
        openWithDialogLoader.active = true
        openWithDialogLoader.item.open(name)
    }

    function openPinnedContextMenu(x, y, path) {
        window._pendingUnpinPath = path
        pinnedContextMenuLoader.active = true
        pinnedContextMenuLoader.item.popup(x, y)
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

    // True while any popup/dialog/menu Loader is active — every shortcut
    // below no-ops while this is true, so e.g. Delete can't act on the
    // background selection while Properties or a context menu is showing
    // on top of it. Checked here (rather than in each Loader individually)
    // so there's one place to update if a new popup is added later.
    readonly property bool anyPopupOpen:
        contextMenuLoader.active || newFolderDialogLoader.active ||
        newFileDialogLoader.active ||
        viewOptionsMenuLoader.active || itemContextMenuLoader.active ||
        renameDialogLoader.active || propertiesDialogLoader.active ||
        deleteConfirmDialogLoader.active || trashContextMenuLoader.active ||
        pinnedContextMenuLoader.active || openWithDialogLoader.active ||
        emptyTrashConfirmDialogLoader.active || settingsDialogLoader.active ||
        deletePermanentlyConfirmDialogLoader.active

    Shortcut {
        sequences: [StandardKey.Delete]
        onActivated: {
            if (window.anyPopupOpen) return
            if (fileModel.selectedCount() > 0) {
                fileModel.deleteSelection()
            }
        }
    }

    Shortcut {
        sequence: "F2"
        onActivated: {
            if (window.anyPopupOpen) return
            if (fileModel.selectedCount() === 1) {
                window.openRenameDialog(fileModel.singleSelectedName())
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Copy]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.copySelection()
        }
    }

    Shortcut {
        sequences: [StandardKey.Cut]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.cutSelection()
        }
    }

    Shortcut {
        sequences: [StandardKey.Paste]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.pasteEntry()
        }
    }

    Shortcut {
        sequences: [StandardKey.Undo]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.undo()
        }
    }

    // StandardKey.Redo covers both Ctrl+Shift+Z and Ctrl+Y per platform.
    Shortcut {
        sequences: [StandardKey.Redo]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.redo()
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.openSelectedEntry()
        }
    }

    // Backspace/Alt+Up go UP the tree; Alt+Left/Right walk the browser
    // history (roadmap item 14) — the two axes are distinct on purpose.
    Shortcut {
        sequences: ["Backspace", "Alt+Up"]
        onActivated: {
            if (window.anyPopupOpen) return
            if (fileModel.currentPath !== "/") {
                fileModel.navigate(window.parentPath(fileModel.currentPath))
            }
        }
    }

    Shortcut {
        sequences: ["Alt+Left"]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.goBack()
        }
    }

    Shortcut {
        sequences: ["Alt+Right"]
        onActivated: {
            if (window.anyPopupOpen) return
            fileModel.goForward()
        }
    }

    Shortcut {
        sequence: "F9"
        onActivated: {
            if (window.anyPopupOpen) return
            window.previewVisible = !window.previewVisible
        }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: {
            if (window.anyPopupOpen) return
            // FabMenu can't own its own Cancel Shortcut — two enabled
            // shortcuts on one sequence are ambiguous in Qt and neither
            // fires — so the window-level one dismisses it first.
            if (fabMenu.expanded) {
                fabMenu.dismiss()
            } else {
                fileModel.clearSelection()
            }
        }
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
    // Mouse thumb buttons = history back/forward. Declared before (so
    // stacked below) the main layout: every other MouseArea in the app
    // accepts only Left/Right buttons, letting thumb-button presses fall
    // through to this catch-all wherever they land.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onClicked: (mouse) => {
            if (window.anyPopupOpen) return
            if (mouse.button === Qt.BackButton) {
                fileModel.goBack()
            } else {
                fileModel.goForward()
            }
        }
    }

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
                    onPinnedContextMenuRequested: (x, y, path) => window.openPinnedContextMenu(x, y, path)
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
                        viewOptionsOpen: viewOptionsMenuLoader.active
                        canGoBack: fileModel.canGoBack
                        canGoForward: fileModel.canGoForward
                        previewOpen: window.previewVisible
                        onPreviewToggled: window.previewVisible = !window.previewVisible
                        onBackClicked: fileModel.goBack()
                        onForwardClicked: fileModel.goForward()
                        onUpClicked: fileModel.navigate(window.parentPath(fileModel.currentPath))
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

                    // Current-folder headline (roadmap item 12) — the
                    // folder's display name at Expressive type scale,
                    // crossfading old→new on navigate. No horizontal
                    // motion here: the view host below already carries
                    // the directional slide; doubling it would be noise.
                    // The Nebula-style 56px app-bar row above stays as
                    // designed.
                    Item {
                        id: folderHeadline
                        Layout.fillWidth: true
                        // Collapses as the view scrolls (round-2 item 17,
                        // the M3 large-top-app-bar behavior): full 44px at
                        // rest, folded away over the first ~88px of scroll.
                        readonly property real _collapse: {
                            var v = viewLoader.item
                            if (!v) {
                                return 0
                            }
                            return Math.max(0, Math.min(1, v.contentY / 88))
                        }
                        Layout.preferredHeight: 44 * (1 - _collapse)
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                        Layout.leftMargin: 16
                        opacity: 1 - _collapse
                        clip: true

                        readonly property string folderName: {
                            var p = fileModel.currentPath ? fileModel.currentPath : ""
                            if (p.length === 0 || p === "/") return "Root"
                            if (p === fileModel.trashPath) return "Trash"
                            return p.substring(p.lastIndexOf("/") + 1)
                        }
                        onFolderNameChanged: {
                            _headlineOld.text = _headlineNew.text
                            _headlineNew.text = folderName
                            _headlineSwap.restart()
                        }
                        Component.onCompleted: _headlineNew.text = folderName

                        Text {
                            id: _headlineOld
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0
                            color: Color.scheme.surfaceText
                            font.family: Type.headlineSmall.family
                            font.weight: Type.headlineSmall.weight
                            font.pixelSize: Type.headlineSmall.size
                        }

                        Text {
                            id: _headlineNew
                            anchors.verticalCenter: parent.verticalCenter
                            color: Color.scheme.surfaceText
                            font.family: Type.headlineSmall.family
                            font.weight: Type.headlineSmall.weight
                            font.pixelSize: Type.headlineSmall.size
                        }

                        ParallelAnimation {
                            id: _headlineSwap
                            NumberAnimation {
                                target: _headlineOld
                                property: "opacity"
                                from: 1
                                to: 0
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                            NumberAnimation {
                                target: _headlineNew
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                        }
                    }

                    Item {
                        id: fileViewArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Keyboard navigation (roadmap item 7). This Item
                        // holds keyboard focus for the whole view area —
                        // delegates and background areas hand focus back
                        // here on click, and onAnyPopupOpenChanged (on the
                        // Window) restores it after dialogs. Arrows move
                        // the Rust-side cursor; Shift extends the
                        // selection; typing does type-ahead find. Enter
                        // needs nothing here — the cursor row is selected,
                        // and the existing Return shortcut opens the
                        // selection.
                        focus: true

                        property string _typeAheadBuffer: ""

                        Timer {
                            id: _typeAheadReset
                            interval: 1000
                            onTriggered: fileViewArea._typeAheadBuffer = ""
                        }

                        function _scrollToCursor() {
                            if (viewLoader.item && fileModel.cursorRow >= 0) {
                                viewLoader.item.scrollToRow(fileModel.cursorRow)
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (window.anyPopupOpen || !viewLoader.item) {
                                return
                            }
                            var extend = (event.modifiers & Qt.ShiftModifier) !== 0
                            var rowStep = viewLoader.item.keyRowStep
                            var handled = true
                            switch (event.key) {
                            case Qt.Key_Up:
                                fileModel.moveCursor(-rowStep, extend)
                                break
                            case Qt.Key_Down:
                                fileModel.moveCursor(rowStep, extend)
                                break
                            case Qt.Key_Left:
                                // Grid only — in list view Left/Right stay
                                // unhandled (Alt+Left etc. keep working).
                                if (viewLoader.item.keyColStep === 1) {
                                    fileModel.moveCursor(-1, extend)
                                } else {
                                    handled = false
                                }
                                break
                            case Qt.Key_Right:
                                if (viewLoader.item.keyColStep === 1) {
                                    fileModel.moveCursor(1, extend)
                                } else {
                                    handled = false
                                }
                                break
                            case Qt.Key_Home:
                                // ±2^30, not INT_MAX — moveCursor clamps in
                                // i64 so the edges are just huge deltas.
                                fileModel.moveCursor(-1073741824, extend)
                                break
                            case Qt.Key_End:
                                fileModel.moveCursor(1073741824, extend)
                                break
                            default:
                                handled = false
                                // Type-ahead: printable single characters
                                // only — control keys (Backspace = go up,
                                // Delete = trash, Enter = open) must keep
                                // their existing shortcuts.
                                if (event.text.length === 1
                                        && event.text.charCodeAt(0) >= 32
                                        && event.text.charCodeAt(0) !== 127
                                        && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                                    var attempt = fileViewArea._typeAheadBuffer + event.text
                                    var row = fileModel.typeAhead(attempt)
                                    if (row < 0 && attempt.length > 1) {
                                        // Dead-end buffer: restart from just
                                        // the new character, the usual
                                        // desktop-FM behavior.
                                        attempt = event.text
                                        row = fileModel.typeAhead(attempt)
                                    }
                                    fileViewArea._typeAheadBuffer = attempt
                                    _typeAheadReset.restart()
                                    handled = true
                                }
                            }
                            if (handled) {
                                fileViewArea._scrollToCursor()
                                event.accepted = true
                            }
                        }

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
                                // The keyboard cursor is model-side
                                // (fileModel.cursorRow), not the view's
                                // currentIndex — keep ListView's own key
                                // handling out of the way.
                                keyNavigationEnabled: false
                                readonly property int keyRowStep: 1
                                readonly property int keyColStep: 0
                                function scrollToRow(row) { positionViewAtIndex(row, ListView.Contain) }
                                // Last plain- or Ctrl-clicked name, for
                                // Shift+click range math — transient UI
                                // state, not part of "what's selected"
                                // (that lives in fileModel), so it's kept
                                // here rather than in Rust.
                                property string selectionAnchor: ""

                                // Watcher-driven diff inserts/removes (and
                                // this app's own single-item operations)
                                // animate; `populate` is deliberately unset so
                                // navigating into a directory never animates
                                // hundreds of rows at once. The remove
                                // transition runs while the delegate is being
                                // destroyed — it touches only opacity/scale,
                                // never model roles.
                                add: Transition {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                    SpringAnimation { property: "scale"; from: 0.8; to: 1; spring: Motion.springStandard.spring; damping: Motion.springStandard.damping }
                                }
                                remove: Transition {
                                    NumberAnimation { property: "opacity"; to: 0; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
                                    NumberAnimation { property: "scale"; to: 0.9; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
                                }
                                displaced: Transition {
                                    SpringAnimation { properties: "x,y"; spring: Motion.springStandard.spring; damping: Motion.springStandard.damping }
                                    // An interrupted add must not strand a
                                    // row half-faded/half-scaled.
                                    NumberAnimation { property: "opacity"; to: 1; duration: 100 }
                                    NumberAnimation { property: "scale"; to: 1; duration: 100 }
                                }

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
                                    // Names this drag gesture itself has selected so far —
                                    // distinct from the selection as a whole, so that an
                                    // item swept into the rect and then swept back out
                                    // gets deselected again, without touching any
                                    // pre-existing (e.g. Ctrl-drag-additive) selection the
                                    // rectangle never covered.
                                    property var sweptNames: ({})

                                    // Rubber-band auto-scroll (round-2 item
                                    // 21): dragging the selector near the
                                    // top/bottom edge scrolls the view.
                                    property real _autoScrollDir: 0
                                    Timer {
                                        interval: 16
                                        repeat: true
                                        running: listBackgroundArea.dragging && listBackgroundArea._autoScrollDir !== 0
                                        onTriggered: {
                                            var maxY = Math.max(0, listView.contentHeight - listView.height)
                                            listView.contentY = Math.max(0, Math.min(maxY, listView.contentY + listBackgroundArea._autoScrollDir * 8))
                                        }
                                    }

                                    onWheel: (wheel) => window.applyWheelScroll(listView, wheel)

                                    onPressed: (mouse) => {
                                        fileViewArea.forceActiveFocus()
                                        if (mouse.button !== Qt.LeftButton) {
                                            return
                                        }
                                        listBackgroundArea.pressX = mouse.x
                                        listBackgroundArea.pressY = mouse.y
                                        listBackgroundArea.dragging = false
                                        listBackgroundArea.sweptNames = ({})
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
                                        listBackgroundArea._autoScrollDir =
                                            mouse.y < 40 ? -1 : (mouse.y > listBackgroundArea.height - 40 ? 1 : 0)

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
                                            // Any overlap counts — a row touched by the
                                            // selector's edge is selected, and the
                                            // sweptNames bookkeeping below un-selects it
                                            // again the moment it's no longer touched.
                                            var contained = child.x < rectRight && (child.x + child.width) > rectLeft &&
                                                            child.y < rectBottom && (child.y + child.height) > rectTop
                                            if (contained && !listBackgroundArea.sweptNames[child.name]) {
                                                listBackgroundArea.sweptNames[child.name] = true
                                                fileModel.setSelected(child.name, true)
                                            } else if (!contained && listBackgroundArea.sweptNames[child.name]) {
                                                delete listBackgroundArea.sweptNames[child.name]
                                                fileModel.setSelected(child.name, false)
                                            }
                                        }
                                    }

                                    onReleased: {
                                        listSelectionRect.visible = false
                                        listBackgroundArea.dragging = false
                                        listBackgroundArea._autoScrollDir = 0
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

                                // Accepts drops landing on empty space (not on a
                                // specific folder row, which FileListItem's own
                                // DropArea already handles) — see
                                // window.handleEmptySpaceDrop for the semantics.
                                // z: -1 keeps this behind the delegates (see
                                // listBackgroundArea's matching comment) so a
                                // drop landing on a folder row goes to that
                                // row's own DropArea, not this one.
                                DropArea {
                                    z: -1
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]
                                    onDropped: (drop) => window.handleEmptySpaceDrop(drop)
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
                                // See the ListView's matching comment.
                                keyNavigationEnabled: false
                                readonly property int keyRowStep: columns
                                readonly property int keyColStep: 1
                                function scrollToRow(row) { positionViewAtIndex(row, GridView.Contain) }
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

                                // See the matching comment on the ListView's
                                // transitions — identical treatment for cells.
                                add: Transition {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                    SpringAnimation { property: "scale"; from: 0.8; to: 1; spring: Motion.springStandard.spring; damping: Motion.springStandard.damping }
                                }
                                remove: Transition {
                                    NumberAnimation { property: "opacity"; to: 0; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
                                    NumberAnimation { property: "scale"; to: 0.9; duration: Motion.emphasizedAccelerate.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccelerate.bezier }
                                }
                                displaced: Transition {
                                    SpringAnimation { properties: "x,y"; spring: Motion.springStandard.spring; damping: Motion.springStandard.damping }
                                    NumberAnimation { property: "opacity"; to: 1; duration: 100 }
                                    NumberAnimation { property: "scale"; to: 1; duration: 100 }
                                }

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
                                    // See the matching comment in listBackgroundArea.
                                    property var sweptNames: ({})

                                    // See listBackgroundArea's matching
                                    // auto-scroll comment.
                                    property real _autoScrollDir: 0
                                    Timer {
                                        interval: 16
                                        repeat: true
                                        running: gridBackgroundArea.dragging && gridBackgroundArea._autoScrollDir !== 0
                                        onTriggered: {
                                            var maxY = Math.max(0, gridView.contentHeight - gridView.height)
                                            gridView.contentY = Math.max(0, Math.min(maxY, gridView.contentY + gridBackgroundArea._autoScrollDir * 8))
                                        }
                                    }

                                    onWheel: (wheel) => window.applyWheelScroll(gridView, wheel)

                                    onPressed: (mouse) => {
                                        fileViewArea.forceActiveFocus()
                                        if (mouse.button !== Qt.LeftButton) {
                                            return
                                        }
                                        gridBackgroundArea.pressX = mouse.x
                                        gridBackgroundArea.pressY = mouse.y
                                        gridBackgroundArea.dragging = false
                                        gridBackgroundArea.sweptNames = ({})
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
                                        gridBackgroundArea._autoScrollDir =
                                            mouse.y < 40 ? -1 : (mouse.y > gridBackgroundArea.height - 40 ? 1 : 0)

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
                                            // Any overlap counts — a cell touched by the
                                            // selector's edge is selected, and the
                                            // sweptNames bookkeeping below un-selects it
                                            // again the moment it's no longer touched.
                                            var contained = child.x < rectRight && (child.x + child.width) > rectLeft &&
                                                            child.y < rectBottom && (child.y + child.height) > rectTop
                                            if (contained && !gridBackgroundArea.sweptNames[child.name]) {
                                                gridBackgroundArea.sweptNames[child.name] = true
                                                fileModel.setSelected(child.name, true)
                                            } else if (!contained && gridBackgroundArea.sweptNames[child.name]) {
                                                delete gridBackgroundArea.sweptNames[child.name]
                                                fileModel.setSelected(child.name, false)
                                            }
                                        }
                                    }

                                    onReleased: {
                                        gridSelectionRect.visible = false
                                        gridBackgroundArea.dragging = false
                                        gridBackgroundArea._autoScrollDir = 0
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

                                // See the matching comment on listView's DropArea.
                                DropArea {
                                    z: -1
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]
                                    onDropped: (drop) => window.handleEmptySpaceDrop(drop)
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

                        DecorativeShapesBackground {}

                        Loader {
                            id: viewLoader
                            anchors.fill: parent
                            sourceComponent: fileModel.viewMode === "grid" ? gridComponent : listComponent
                            transform: Translate { id: viewSlide }
                            // List↔grid toggle (and first load): the fresh
                            // view crossfades/scales in instead of snapping.
                            // At startup this can overlap viewEntrance below;
                            // both settle at opacity 1 / scale 1, so the race
                            // is harmless.
                            onLoaded: viewSwapEntrance.restart()
                        }

                        // One-shot entrance when a navigation's listing
                        // lands (isListing flips false) — content slides in
                        // from the right going deeper, from the left going
                        // up, plain fade for sidebar jumps. Screen-level
                        // motion: bezier pairs, not springs. Watcher
                        // refreshes never touch isListing, so they never
                        // move the view.
                        ParallelAnimation {
                            id: viewEntrance
                            NumberAnimation {
                                target: viewSlide
                                property: "x"
                                from: window._navDirection === "forward" ? 24
                                    : window._navDirection === "back" ? -24 : 0
                                to: 0
                                duration: Motion.emphasizedDecelerate.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.emphasizedDecelerate.bezier
                            }
                            NumberAnimation {
                                target: viewLoader
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Motion.emphasizedDecelerate.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.emphasizedDecelerate.bezier
                            }
                        }

                        ParallelAnimation {
                            id: viewSwapEntrance
                            NumberAnimation {
                                target: viewLoader
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                            NumberAnimation {
                                target: viewLoader
                                property: "scale"
                                from: 0.96
                                to: 1
                                duration: Motion.standard.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard.bezier
                            }
                        }

                        Connections {
                            target: fileModel
                            function onIsListingChanged() {
                                if (!fileModel.isListing) {
                                    viewEntrance.restart()
                                }
                            }
                        }

                        // Drag-hover auto-scroll strips (round-2 item 21):
                        // parking a DnD drag at the view's top/bottom edge
                        // scrolls it, so a long list is reachable mid-drag.
                        // They're DropAreas (only DropAreas see drags), so a
                        // release inside a strip routes through the same
                        // empty-space import handler instead of being lost.
                        DropArea {
                            id: _dragScrollTop
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            keys: ["text/uri-list"]
                            onDropped: (drop) => window.handleEmptySpaceDrop(drop)

                            Timer {
                                interval: 16
                                repeat: true
                                running: _dragScrollTop.containsDrag
                                onTriggered: {
                                    var v = viewLoader.item
                                    if (v) {
                                        v.contentY = Math.max(0, v.contentY - 10)
                                    }
                                }
                            }
                        }

                        DropArea {
                            id: _dragScrollBottom
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            keys: ["text/uri-list"]
                            onDropped: (drop) => window.handleEmptySpaceDrop(drop)

                            Timer {
                                interval: 16
                                repeat: true
                                running: _dragScrollBottom.containsDrag
                                onTriggered: {
                                    var v = viewLoader.item
                                    if (v) {
                                        var maxY = Math.max(0, v.contentHeight - v.height)
                                        v.contentY = Math.min(maxY, v.contentY + 10)
                                    }
                                }
                            }
                        }

                        // Loading state — a navigation listing that's
                        // actually taking a while shows the shape-morph
                        // loader centered in the otherwise-empty view,
                        // disambiguating "still listing" from "empty
                        // folder". The 150ms gate keeps fast local listings
                        // from flashing it. isListing is only ever true for
                        // navigate() listings, never watcher refreshes, so
                        // this can't appear over existing rows.
                        ShapeLoader {
                            anchors.centerIn: parent
                            size: 48
                            color: Color.scheme.primary
                            visible: fileModel.isListing && _listingSpinnerGate.elapsed
                                && fileModel.viewMode === "grid"
                            running: visible
                        }

                        // Skeleton placeholder rows (round-2 item 18) — the
                        // list-mode loading state: content-shaped and
                        // breathing, which reads as "rows are coming" better
                        // than a centered spinner. Same 150ms gate.
                        Column {
                            visible: fileModel.isListing && _listingSpinnerGate.elapsed
                                && fileModel.viewMode === "list"
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10
                            clip: true

                            SequentialAnimation on opacity {
                                running: parent.visible
                                loops: Animation.Infinite
                                NumberAnimation { from: 1; to: 0.45; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.45; to: 1; duration: 600; easing.type: Easing.InOutQuad }
                            }

                            Repeater {
                                model: 8

                                delegate: Item {
                                    id: skelRow
                                    required property int index
                                    width: parent.width
                                    height: 50
                                    // Rows fade toward the bottom, hinting
                                    // at a list rather than a fixed block.
                                    opacity: 1 - index * 0.11

                                    Rectangle {
                                        id: skelIcon
                                        x: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 36
                                        height: 36
                                        radius: Shape.medium
                                        color: Color.scheme.surfaceContainerHigh
                                    }

                                    Rectangle {
                                        anchors.left: skelIcon.right
                                        anchors.leftMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        // Varied bar widths so it reads as
                                        // filenames, not a table.
                                        width: parent.width * (0.22 + 0.13 * (skelRow.index % 3))
                                        height: 12
                                        radius: Shape.full
                                        color: Color.scheme.surfaceContainerHigh
                                    }
                                }
                            }
                        }

                        Timer {
                            id: _listingSpinnerGate
                            property bool elapsed: false
                            interval: 150
                            running: fileModel.isListing
                            onRunningChanged: if (running) elapsed = false
                            onTriggered: elapsed = true
                        }

                        // Empty state — only after a listing has actually
                        // landed empty (never while the spinner could
                        // show), keyed off the live view's row count.
                        EmptyState {
                            anchors.centerIn: parent
                            visible: (!fileModel.isListing && viewLoader.item)
                                ? viewLoader.item.count === 0 : false
                            // window.fileListModel, not the bare fileModel
                            // id — this component declares its own
                            // `property var fileModel` (see the alias
                            // comment at the top of this file).
                            fileModel: window.fileListModel
                            onNewFolderRequested: window.openNewFolderDialog()
                        }

                        FabMenu {
                            id: fabMenu
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 20
                            // window.fileListModel, not the bare fileModel
                            // id — this component declares its own
                            // `property var fileModel` (see the alias
                            // comment at the top of this file).
                            fileModel: window.fileListModel
                            onNewFolderRequested: window.openNewFolderDialog()
                            onNewFileRequested: window.openNewFileDialog()
                            onPasteRequested: fileModel.pasteEntry()
                        }

                        // Contextual floating toolbar for bulk actions —
                        // springs up while 2+ items are selected. Not a
                        // popup: deliberately absent from anyPopupOpen.
                        SelectionToolbar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16
                            // window.fileListModel, not the bare fileModel
                            // id — this component declares its own
                            // `property var fileModel` (see the alias
                            // comment at the top of this file).
                            fileModel: window.fileListModel
                            onDeleteRequested: (count) => window.openDeleteSelectionConfirmDialog(count)
                            onDeletePermanentlyRequested: (count) => window.openDeletePermanentlySelectionConfirmDialog(count)
                        }
                    }

                    // Status line (round-2 item 16): a quiet summary of
                    // what the view shows and what's selected.
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        Layout.minimumHeight: 24
                        Layout.maximumHeight: 24

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            color: Color.scheme.surfaceVariantText
                            font.family: Type.labelMedium.family
                            font.weight: Type.labelMedium.weight
                            font.pixelSize: Type.labelMedium.size
                            text: {
                                var t = Format.formatItemCount(fileModel.displayedCount)
                                if (fileModel.displayedTotalBytes > 0) {
                                    t += " · " + Format.formatBytes(fileModel.displayedTotalBytes)
                                }
                                if (fileModel.selectionCount > 0) {
                                    t += " · " + fileModel.selectionCount + " selected"
                                }
                                return t
                            }
                        }
                    }
                }

                // Preview/details pane (round-2 item 22) — F9 or the
                // header's info button.
                PreviewPane {
                    visible: window.previewVisible
                    Layout.fillHeight: true
                    Layout.preferredWidth: 260
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    Layout.rightMargin: 10
                    // window.fileListModel, not the bare fileModel id —
                    // this component declares its own `property var
                    // fileModel` (see the alias comment above).
                    fileModel: window.fileListModel
                    entryName: fileModel && fileModel.selectionCount === 1
                        ? fileModel.singleSelectedName() : ""
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
        id: newFileDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: NewFileDialog {
            onAccepted: (name) => fileModel.createFile(name)
            onClosed: Qt.callLater(() => newFileDialogLoader.active = false)
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
            onOpenWithRequested: (name) => window.openOpenWithDialog(name)
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
            onRestoreRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    fileModel.restoreSelection()
                } else {
                    fileModel.restoreEntry(name)
                }
            }
            onDeletePermanentlyRequested: (name) => {
                if (itemContextMenu.selectionCount > 1) {
                    window.openDeletePermanentlySelectionConfirmDialog(itemContextMenu.selectionCount)
                } else {
                    window.openDeletePermanentlyConfirmDialog(name)
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
        id: deletePermanentlyConfirmDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: ConfirmDialog {
            title: "Delete Permanently"
            confirmLabel: "Delete Permanently"
            onConfirmed: {
                if (window._pendingDeletePermanentlyIsSelection) {
                    fileModel.deletePermanentlySelection()
                } else {
                    fileModel.deletePermanentlyEntry(window._pendingDeletePermanentlyName)
                }
            }
            onClosed: Qt.callLater(() => deletePermanentlyConfirmDialogLoader.active = false)
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
        id: openWithDialogLoader
        anchors.fill: parent
        active: false
        sourceComponent: OpenWithDialog {
            fileModel: window.fileListModel
            onClosed: Qt.callLater(() => openWithDialogLoader.active = false)
        }
    }

    Loader {
        id: pinnedContextMenuLoader
        anchors.fill: parent
        active: false
        sourceComponent: PinnedContextMenu {
            onUnpinRequested: fileModel.unpinFolder(window._pendingUnpinPath)
            onClosed: Qt.callLater(() => pinnedContextMenuLoader.active = false)
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

    Connections {
        target: fileModel
        function onErrorOccurred(message) { snackbar.show(message) }
        function onOperationCompleted(description, canUndo) {
            snackbar.show(description, canUndo ? "Undo" : "")
        }
    }

    Snackbar {
        id: snackbar
        onActionClicked: fileModel.undo()
    }
}
