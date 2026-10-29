import AppKit
import Carbon.HIToolbox

/// 全局快捷键：⌥Space 显示/隐藏工具箱（Carbon RegisterEventHotKey）
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private weak var app: AppDelegate?

    func register(app: AppDelegate) {
        self.app = app
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.app?.togglePanel()
            return noErr
        }, 1, &eventType, userData, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x544F4F4C) /* 'TOOL' */, id: 1)
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey),
                            hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
