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

// entryModified is the ISO 8601 string FileListModel hands to QML — the
// Date constructor parses that natively.
function formatModified(isoString) {
    var date = new Date(isoString)
    if (isNaN(date.getTime())) {
        return isoString
    }
    return Qt.formatDateTime(date, "MMM d, yyyy, h:mm AP")
}
