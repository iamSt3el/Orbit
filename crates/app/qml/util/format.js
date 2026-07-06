.pragma library

function formatBytes(bytes) {
    if (bytes < 1024) {
        return bytes + " B"
    }
    var units = ["KB", "MB", "GB", "TB", "PB"]
    var value = bytes
    var unitIndex = -1
    while (value >= 1024 && unitIndex < units.length - 1) {
        value /= 1024
        unitIndex++
    }
    return value.toFixed(value < 10 ? 1 : 0) + " " + units[unitIndex]
}

function formatItemCount(count) {
    return count + (count === 1 ? " item" : " items")
}

// "3.5 / 9.6 GB" — used and total share the total's unit so the pair
// reads as one fraction (the storage gauge cards' caption).
function formatBytesPair(used, total) {
    if (total < 1024) {
        return used + " / " + total + " B"
    }
    var units = ["KB", "MB", "GB", "TB", "PB"]
    var div = 1024
    var unitIndex = 0
    while (total / div >= 1024 && unitIndex < units.length - 1) {
        div *= 1024
        unitIndex++
    }
    return (used / div).toFixed(1) + " / " + (total / div).toFixed(1) + " " + units[unitIndex]
}

// Maps FileListModel's `iconKey` role (a coarse mime-type category —
// see fm_core::mime::icon_key_for) to a Material Symbols glyph name.
function iconForKey(iconKey, isDir) {
    if (isDir) {
        return "folder"
    }
    switch (iconKey) {
    case "pdf": return "picture_as_pdf"
    case "image": return "image"
    case "video": return "movie"
    case "audio": return "audio_file"
    case "text": return "description"
    case "archive": return "folder_zip"
    default: return "draft"
    }
}

// entryModified is the ISO 8601 string FileListModel hands to QML — the
// Date constructor parses that natively.
// Humanized modified timestamp (roadmap round-2 item 20) for the list
// rows: "Today 2:41 PM", "Yesterday 9:03 AM", weekday within a week,
// then month/day (with year only once it differs). PropertiesDialog
// keeps the exact formatModified below.
function humanizeModified(isoString) {
    var date = new Date(isoString)
    if (isNaN(date.getTime())) {
        return isoString
    }
    var now = new Date()
    var startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    var dayMs = 24 * 60 * 60 * 1000
    var time = Qt.formatDateTime(date, "h:mm AP")
    if (date >= startOfToday) {
        return "Today " + time
    }
    if (date >= new Date(startOfToday.getTime() - dayMs)) {
        return "Yesterday " + time
    }
    if (date >= new Date(startOfToday.getTime() - 6 * dayMs)) {
        return Qt.formatDateTime(date, "dddd") + " " + time
    }
    if (date.getFullYear() === now.getFullYear()) {
        return Qt.formatDateTime(date, "MMM d")
    }
    return Qt.formatDateTime(date, "MMM d, yyyy")
}

function formatModified(isoString) {
    var date = new Date(isoString)
    if (isNaN(date.getTime())) {
        return isoString
    }
    return Qt.formatDateTime(date, "MMM d, yyyy, h:mm AP")
}
