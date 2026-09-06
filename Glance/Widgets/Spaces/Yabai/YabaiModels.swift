import AppKit

struct YabaiWindow: WindowModel {
    let id: Int
    let title: String
    let appName: String?
    let isFocused: Bool
    let stackIndex: Int
    var appIcon: NSImage?
    let isHidden: Bool
    let isFloating: Bool
    let level: Int
    let subrole: String?
    var isUtilityPanel: Bool { level != 0 || subrole == "AXFloatingWindow" }
    let isSticky: Bool
    let spaceId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case spaceId = "space"
        case title
        case appName = "app"
        case isFocused = "has-focus"
        case stackIndex = "stack-index"
        case isHidden = "is-hidden"
        case isFloating = "is-floating"
        case level
        case subrole
        case isSticky = "is-sticky"
    }

    private static func resolvedTitle(from rawTitle: String?) -> String {
        let trimmed = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Unnamed" : trimmed
    }

    private static func icon(for appName: String?) -> NSImage? {
        guard let appName else { return nil }
        return IconCache.shared.icon(for: appName)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        spaceId = try container.decode(Int.self, forKey: .spaceId)
        title = Self.resolvedTitle(from: try container.decodeIfPresent(String.self, forKey: .title))
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        isFocused = try container.decode(Bool.self, forKey: .isFocused)
        stackIndex = try container.decodeIfPresent(Int.self, forKey: .stackIndex) ?? 0
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        isFloating = try container.decode(Bool.self, forKey: .isFloating)
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 0
        subrole = try container.decodeIfPresent(String.self, forKey: .subrole)
        isSticky = try container.decode(Bool.self, forKey: .isSticky)
        appIcon = Self.icon(for: appName)
    }
}

struct YabaiSpace: SpaceModel {
    typealias WindowType = YabaiWindow
    let display: Int
    let isVisible: Bool?
    var displayID: CGDirectDisplayID? = nil
    let id: Int
    var isFocused: Bool
    var windows: [YabaiWindow] = []

    enum CodingKeys: String, CodingKey {
        case display
        case isVisible = "is-visible"
        case id = "index"
        case isFocused = "has-focus"
    }
}

struct YabaiDisplay: Decodable {
    let id: CGDirectDisplayID
    let index: Int
}
