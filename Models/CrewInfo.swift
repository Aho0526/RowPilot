import Foundation

/// ボートタイプ（主要5艇種）
enum BoatType: String, Codable, CaseIterable, Identifiable {
    case doubleSculls = "2x"    // ダブルスカル
    case pair = "2-"            // ペア
    case singleSculls = "1x"    // シングル
    case coxedQuad = "4x+"      // 舵手付きクォード
    case four = "4-"            // フォア
    case eight = "8+"           // エイト
    
    var id: String { rawValue }
    
    /// 表示名
    var displayName: String {
        switch self {
        case .doubleSculls: return "ダブルスカル"
        case .pair:         return "ペア"
        case .singleSculls: return "シングル"
        case .coxedQuad:    return "舵手付きクォード"
        case .four:         return "フォア"
        case .eight:        return "エイト"
        }
    }
    
    /// SF Symbolsアイコン名
    var iconName: String {
        switch self {
        case .doubleSculls: return "person.2.fill"
        case .pair:         return "person.2.fill"
        case .singleSculls: return "person.fill"
        case .coxedQuad:    return "person.3.sequence.fill"
        case .four:         return "person.3.fill"
        case .eight:        return "person.3.sequence.fill"
        }
    }
    
    /// 漕手の数
    var rowerCount: Int {
        switch self {
        case .doubleSculls: return 2
        case .pair:         return 2
        case .singleSculls: return 1
        case .coxedQuad:    return 4
        case .four:         return 4
        case .eight:        return 8
        }
    }
    
    /// コックスの有無
    var hasCoxswain: Bool {
        switch self {
        case .coxedQuad, .eight: return true
        default: return false
        }
    }
    
    /// 合計人数（漕手 + コックス）
    var totalSeats: Int {
        rowerCount + (hasCoxswain ? 1 : 0)
    }
    
    /// スカル艇かどうか
    var isScull: Bool {
        switch self {
        case .doubleSculls, .coxedQuad, .singleSculls: return true
        default: return false
        }
    }
    
    /// 座席ラベル（バウ→ストローク順、コックスは最後）
    var seatLabels: [String] {
        var labels: [String] = []
        for i in 1...rowerCount {
            if i == 1 {
                labels.append("Bow")
            } else if i == rowerCount {
                labels.append("Stroke")
            } else {
                labels.append("\(i)")
            }
        }
        if hasCoxswain {
            labels.append("Cox")
        }
        return labels
    }
}

/// クルー情報
struct CrewInfo: Codable, Equatable {
    var boatType: BoatType
    var members: [String]  // 座席順に格納。空文字 = 未入力
    
    /// 空のメンバー配列で初期化
    init(boatType: BoatType) {
        self.boatType = boatType
        self.members = Array(repeating: "", count: boatType.totalSeats)
    }
    
    init(boatType: BoatType, members: [String]) {
        self.boatType = boatType
        // メンバー数が座席数と合わない場合は調整
        if members.count == boatType.totalSeats {
            self.members = members
        } else {
            var adjusted = members
            while adjusted.count < boatType.totalSeats {
                adjusted.append("")
            }
            self.members = Array(adjusted.prefix(boatType.totalSeats))
        }
    }
    
    /// 入力済みのメンバー数
    var filledCount: Int {
        members.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
    
    /// 全座席が入力済みか
    var isComplete: Bool {
        filledCount == members.count
    }
}
