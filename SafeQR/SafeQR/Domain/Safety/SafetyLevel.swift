import Foundation

enum SafetyLevel: Int16, CaseIterable, Comparable {
    case safe = 0
    case caution = 1
    case danger = 2
    
    var displayName: String {
        switch self {
        case .safe:
            return "安全"
        case .caution:
            return "注意"
        case .danger:
            return "危険"
        }
    }
    
    var description: String {
        switch self {
        case .safe:
            return "このリンクは安全と判定されました"
        case .caution:
            return "不審な可能性があります"
        case .danger:
            return "危険な可能性があります"
        }
    }
    
    var recommendedAction: String {
        switch self {
        case .safe:
            return ""
        case .caution:
            return "確認してから開いてください"
        case .danger:
            return "開かないことをおすすめします"
        }
    }
    
    // MARK: - Comparable
    
    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}