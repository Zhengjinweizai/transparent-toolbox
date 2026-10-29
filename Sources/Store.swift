import Foundation

struct ClipItem: Codable {
    var text: String
    var time: Date = Date()
    var pinned: Bool = false
}

struct TodoItem: Codable {
    var id: UUID = UUID()
    var text: String
    var done: Bool = false
}

struct AppState: Codable {
    var todos: [TodoItem] = []
    var clips: [String] = []          // v1 遗留（迁移源）
    var clips2: [ClipItem] = []       // v2：带时间戳与置顶
    var opacity: Double = 0.78
    var material: String = "hud"   // hud | dark | light
    var collapsed: Bool = false
    var pomodoroWork: Int = 25
    var pomodoroBreak: Int = 5
    var hiddenWidgets: [String] = []
    var pinned: Bool = true
    var widgetOrder: [String] = []
    var notesList: [String] = [""] // 多便签；旧版单便签自动迁移
    var collapsedCards: [String] = [] // 每卡片独立折叠状态
    var pomodoroDay: String = ""      // "yyyy-MM-dd"，跨天自动清零
    var pomodoroDone: Int = 0         // 今日完成的专注轮数

    private enum CodingKeys: String, CodingKey {
        case notesList, notes, todos, clips, clips2, opacity, material, collapsed
        case pomodoroWork, pomodoroBreak, hiddenWidgets, pinned, widgetOrder, collapsedCards, pomodoroDay, pomodoroDone
    }

    // 兼容旧版本 state.json：缺字段时用默认值而不是解码失败
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        todos          = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        clips          = try c.decodeIfPresent([String].self, forKey: .clips) ?? []
        if let c2 = try c.decodeIfPresent([ClipItem].self, forKey: .clips2) {
            clips2 = c2
        } else {
            clips2 = clips.map { ClipItem(text: $0) }   // v1 迁移
        }
        opacity        = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.78
        material       = try c.decodeIfPresent(String.self, forKey: .material) ?? "hud"
        collapsed      = try c.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
        pomodoroWork   = try c.decodeIfPresent(Int.self, forKey: .pomodoroWork) ?? 25
        pomodoroBreak  = try c.decodeIfPresent(Int.self, forKey: .pomodoroBreak) ?? 5
        hiddenWidgets  = try c.decodeIfPresent([String].self, forKey: .hiddenWidgets) ?? []
        pinned         = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? true
        widgetOrder    = try c.decodeIfPresent([String].self, forKey: .widgetOrder) ?? []
        collapsedCards = try c.decodeIfPresent([String].self, forKey: .collapsedCards) ?? []
        pomodoroDay    = try c.decodeIfPresent(String.self, forKey: .pomodoroDay) ?? ""
        pomodoroDone   = try c.decodeIfPresent(Int.self, forKey: .pomodoroDone) ?? 0
        if let list = try c.decodeIfPresent([String].self, forKey: .notesList), !list.isEmpty {
            notesList = list
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .notes) {
            notesList = [legacy]
        }
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(notesList, forKey: .notesList)
        try c.encode(todos, forKey: .todos)
        try c.encode(clips2, forKey: .clips2)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(material, forKey: .material)
        try c.encode(collapsed, forKey: .collapsed)
        try c.encode(pomodoroWork, forKey: .pomodoroWork)
        try c.encode(pomodoroBreak, forKey: .pomodoroBreak)
        try c.encode(hiddenWidgets, forKey: .hiddenWidgets)
        try c.encode(pinned, forKey: .pinned)
        try c.encode(widgetOrder, forKey: .widgetOrder)
        try c.encode(collapsedCards, forKey: .collapsedCards)
        try c.encode(pomodoroDay, forKey: .pomodoroDay)
        try c.encode(pomodoroDone, forKey: .pomodoroDone)
    }
}

extension Store {
    func isWidgetVisible(_ id: String) -> Bool { !state.hiddenWidgets.contains(id) }
    func setWidgetVisible(_ id: String, visible: Bool) {
        if visible { state.hiddenWidgets.removeAll { $0 == id } }
        else if !state.hiddenWidgets.contains(id) { state.hiddenWidgets.append(id) }
        save()
    }

    /// 返回按用户顺序排列的 id（未知 id 排最后，保持默认相对顺序）
    func orderedWidgetIDs(_ defaults: [String]) -> [String] {
        let order = state.widgetOrder.filter { defaults.contains($0) }
        let unseen = defaults.filter { !order.contains($0) }
        return order + unseen
    }
}

final class Store {
    static let shared = Store()
    var state = AppState()

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TransparentToolbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(AppState.self, from: data) else { return }
        state = s
    }

    func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
        NotificationCenter.default.post(name: .storeSaved, object: nil)
    }
}

extension Notification.Name {
    static let storeSaved = Notification.Name("storeSaved")
    static let panelRefit = Notification.Name("panelRefit")
}
