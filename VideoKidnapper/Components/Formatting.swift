import Foundation

/// "m:ss" formatting for timeline labels.
func formatTime(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", total / 60, total % 60)
}
