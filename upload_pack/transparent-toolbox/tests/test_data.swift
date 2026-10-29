import Foundation

// 数据层测试：v1 → v2 兼容迁移、Sparkline 缓冲、相对时间
var failures = 0
func check(_ name: String, _ cond: Bool) {
    if cond { print("✔ \(name)") } else { print("✘ \(name)"); failures += 1 }
}

// 1) v1 state.json（clips 为 [String]）→ 应迁移为 clips2
struct Probe1: Decodable {
    var clips: [String]
    var clips2: [ClipItem]?
    enum Keys: String, CodingKey { case clips, clips2 }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: Keys.self)
        clips = try c.decodeIfPresent([String].self, forKey: .clips) ?? []
        if let c2 = try c.decodeIfPresent([ClipItem].self, forKey: .clips2) { clips2 = c2 }
        else { clips2 = clips.map { ClipItem(text: $0) } }
    }
}
let v1json = Data(#"{"clips":["hello","world"]}"#.utf8)
if let p = try? JSONDecoder().decode(Probe1.self, from: v1json) {
    check("v1 clips 迁移为 clips2（2 条）", p.clips2?.count == 2 && p.clips2?.first?.text == "hello")
    check("迁移后的时间戳为当前", abs(p.clips2?.first?.time.timeIntervalSinceNow ?? -99) < 5)
} else { check("v1 clips 迁移解码", false); failures += 1 }

// 2) Sparkline 缓冲：超过 capacity 时丢弃最旧
final class Buf {
    private(set) var values: [Double] = []
    var capacity = 5
    func push(_ v: Double) {
        values.append(v)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}
let b = Buf()
(1...8).forEach { b.push(Double($0)) }
check("Sparkline 缓冲保留最后 capacity 个", b.values == [4,5,6,7,8])

// 3) 相对时间边界
check("刚刚", Theme.relativeTime(from: Date().addingTimeInterval(-5)) == "刚刚")
check("3 分钟前", Theme.relativeTime(from: Date().addingTimeInterval(-180)) == "3 分钟前")

if failures == 0 { print("数据层测试全部通过 ✔") } else { print("失败 \(failures) 项"); exit(1) }
