import Foundation

struct AppLogItem: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let category: String
    let message: String

    var timestamp: String {
        AppLogItem.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
