import Foundation
import Combine

class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let usageLimitMinutes = "usageLimitMinutes"
        static let breakDurationMinutes = "breakDurationMinutes"
    }

    @Published var usageLimitMinutes: Int {
        didSet {
            defaults.set(usageLimitMinutes, forKey: Keys.usageLimitMinutes)
        }
    }

    @Published var breakDurationMinutes: Int {
        didSet {
            defaults.set(breakDurationMinutes, forKey: Keys.breakDurationMinutes)
        }
    }

    var usageLimitSeconds: Int {
        return usageLimitMinutes * 60
    }

    init() {
        // Load saved values or use defaults
        let savedUsageLimit = defaults.integer(forKey: Keys.usageLimitMinutes)
        self.usageLimitMinutes = savedUsageLimit > 0 ? savedUsageLimit : 60

        let savedBreakDuration = defaults.integer(forKey: Keys.breakDurationMinutes)
        self.breakDurationMinutes = savedBreakDuration > 0 ? savedBreakDuration : 5
    }
}
