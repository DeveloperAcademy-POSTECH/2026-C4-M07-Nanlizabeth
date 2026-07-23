import Foundation

enum Logger {
    static func item(_ category: String, _ message: String) -> AppLogItem {
        AppLogItem(date: Date(), category: category, message: message)
    }
}
