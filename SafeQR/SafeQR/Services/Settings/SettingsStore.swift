import Foundation

enum SafetyStrictness: String, CaseIterable {
    case low = "low"
    case standard = "standard"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "弱"
        case .standard:
            return "標準"
        case .high:
            return "強"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "警告を減らします"
        case .standard:
            return "推奨設定"
        case .high:
            return "より厳格にチェック"
        }
    }
    
    var scoreModifier: Int {
        switch self {
        case .low:
            return -1
        case .standard:
            return 0
        case .high:
            return 1
        }
    }
}

class SettingsStore {
    static let shared = SettingsStore()
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let safetyStrictness = "safetyStrictness"
        static let externalReputationEnabled = "externalReputationEnabled"
    }
    
    private init() {}
    
    var safetyStrictness: SafetyStrictness {
        get {
            let rawValue = userDefaults.string(forKey: Keys.safetyStrictness) ?? SafetyStrictness.standard.rawValue
            return SafetyStrictness(rawValue: rawValue) ?? .standard
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.safetyStrictness)
        }
    }
    
    var isExternalReputationEnabled: Bool {
        get {
            return userDefaults.bool(forKey: Keys.externalReputationEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.externalReputationEnabled)
        }
    }
}