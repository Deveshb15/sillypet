import Foundation

enum SpriteType: String, CaseIterable, Codable, Identifiable {
    case dog
    case cat
    case rabbit
    case fox
    case penguin
    case hamster
    case owl
    case frog
    case duck
    case panda

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dog: return "Shiba Inu"
        case .cat: return "Cat"
        case .rabbit: return "Rabbit"
        case .fox: return "Fox"
        case .penguin: return "Penguin"
        case .hamster: return "Hamster"
        case .owl: return "Owl"
        case .frog: return "Frog"
        case .duck: return "Duck"
        case .panda: return "Panda"
        }
    }

    static var saved: SpriteType? {
        guard let raw = UserDefaults.standard.string(forKey: "selectedSpriteType") else { return nil }
        return SpriteType(rawValue: raw)
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "selectedSpriteType")
    }
}

struct SpriteSet {
    let colorMap: [Character: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)]
    let idle: [[String]]
    let walk: [[String]]
    let run: [[String]]
    let sit: [[String]]
    let sleep: [[String]]
    let celebrate: [[String]]
    let alert: [[String]]
}
