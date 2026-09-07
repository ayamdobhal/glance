import AppKit

// Minimal host dependencies: exercise the real yabai models/provider against
// controlled query responses without requiring a running window manager.
protocol WindowModel: Identifiable, Equatable, Codable {}
protocol SpaceModel: Identifiable, Equatable, Codable {}
protocol SpacesProvider {}
protocol SwitchableSpacesProvider {}
final class IconCache {
    static let shared = IconCache()
    func icon(for name: String) -> NSImage? { nil }
}
final class ConfigManager {
    static let shared = ConfigManager()
    let config = Configuration()
    struct Configuration { let yabai = Yabai(); struct Yabai { let path = "/unused" } }
}
struct SpacesCommandRunner {
    let toolName: String
    let executableURL: URL
    static var responses: [String: Data] = [:]
    func decode<T: Decodable>(_ type: T.Type, arguments: [String]) -> T? {
        guard let data = Self.responses[arguments.last!] else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    func run(arguments: [String]) {}
}

@main struct DisplaySmoke {
    static func main() throws {
        func response(_ key: String, _ value: Any) throws {
            SpacesCommandRunner.responses[key] = try JSONSerialization.data(withJSONObject: value)
        }
        try response("--displays", [["index": 1, "id": 900], ["index": 2, "id": 42]])
        try response("--spaces", [
            ["index": 1, "display": 1, "has-focus": true, "is-visible": true],
            ["index": 7, "display": 2, "has-focus": false, "is-visible": true],
            ["index": 8, "display": 2, "has-focus": false, "is-visible": false]
        ])
        func window(_ id: Int, _ space: Int, _ level: Int, _ subrole: String) -> [String: Any] {
            ["id": id, "space": space, "app": "Test", "title": "", "has-focus": false,
             "is-hidden": false, "is-floating": true, "is-sticky": false,
             "level": level, "subrole": subrole]
        }
        try response("--windows", [window(1, 7, 0, ""), window(2, 8, 3, "AXFloatingWindow")])
        let spaces = YabaiSpacesProvider().getSpacesWithWindows()!
        precondition(spaces.map(\.id) == [1, 7, 8], "Empty spaces must survive")
        precondition(spaces.map(\.displayID) == [900, 42, 42], "Map indexes to CG display IDs")
        precondition(spaces[1].windows.map(\.id) == [1], "Floating app windows must survive")
        precondition(spaces[2].windows.isEmpty, "Utility panels must be excluded")
        precondition(spaces[1].isFocused, "Highlight the visible space on an inactive display")
        try response("--displays", [["index": 1, "id": 42], ["index": 2, "id": 900]])
        precondition(YabaiSpacesProvider().getSpacesWithWindows()![1].displayID == 900,
                     "Display reordering must refresh the mapping")
        // Laptop -> external primary -> laptop alone, retaining the laptop ID.
        let laptop = BarDisplayLayout(id: 1, frame: CGRect(x: 0, y: 0, width: 2056, height: 1329))
        let external = BarDisplayLayout(id: 42, frame: CGRect(x: 0, y: 0, width: 3840, height: 1600))
        let movedLaptop = BarDisplayLayout(id: 1, frame: CGRect(x: -2056, y: 0, width: 2056, height: 1329))
        precondition([laptop] != [external, movedLaptop])
        precondition([external, movedLaptop] != [laptop])
        precondition([laptop] == [laptop])
        precondition([external, movedLaptop] != [movedLaptop, external], "Primary screen changes matter")
        try response("--displays", [["index": 1, "id": 1]])
        try response("--spaces", [
            ["index": 1, "display": 1, "has-focus": true, "is-visible": true],
            ["index": 8, "display": 1, "has-focus": false, "is-visible": false]
        ])
        let disconnected = YabaiSpacesProvider().getSpacesWithWindows()!
        precondition(disconnected.map(\.id) == [1, 8])
        precondition(disconnected.allSatisfy { $0.displayID == 1 }, "No disconnected display spaces remain")
        let above = DisplayGeometry.accessibilityFrame(
            CGRect(x: 0, y: 900, width: 1200, height: 800), primaryTop: 900)
        precondition(above == CGRect(x: 0, y: -800, width: 1200, height: 800))
        let left = DisplayGeometry.accessibilityFrame(
            CGRect(x: -1400, y: 0, width: 1400, height: 900), primaryTop: 900)
        precondition(left.minX == -1400 && left.minY == 0)
        let displays = [CGRect(x: 0, y: 0, width: 1200, height: 900), above, left]
        precondition(DisplayGeometry.containingDisplay(
            for: CGRect(x: 100, y: -700, width: 800, height: 600), displays: displays) == 1)
        precondition(DisplayGeometry.containingDisplay(
            for: CGRect(x: -1200, y: 50, width: 800, height: 600), displays: displays) == 2)
        print("Display checks passed: empty/floating spaces, display mapping/reordering, visible spaces, above/left geometry.")
    }
}
