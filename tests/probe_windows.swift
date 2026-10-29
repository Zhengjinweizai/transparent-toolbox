import AppKit

// 探针：读取当前屏幕所有窗口（含其他 app）中属于 TransparentToolbox 的窗口
let opts: CGWindowListOption = [.optionAll, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
    print("无法读取窗口列表（需要屏幕录制权限）"); exit(1)
}
var found = 0
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    guard owner.contains("TransparentToolbox") else { continue }
    found += 1
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print("窗口 owner=\(owner) layer=\(w[kCGWindowLayer as String] ?? "?") alpha=\(w[kCGWindowAlpha as String] ?? "?") bounds=\(bounds)")
}
print("匹配窗口数: \(found)")

let screens = NSScreen.screens.map { "\($0.frame)" }
print("屏幕: \(screens)")
print("鼠标位置: \(NSEvent.mouseLocation)")
