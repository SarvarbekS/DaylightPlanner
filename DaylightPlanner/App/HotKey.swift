import Carbon.HIToolbox

final class HotKey {
    static let shared = HotKey()
    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register(keyCode: Int, modifiers: Int) {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }

        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                     eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { HotKey.shared.onPress?() }
                return noErr
            }, 1, &spec, nil, &handler)
        }

        let id = EventHotKeyID(signature: OSType(0x444C5048), id: 1)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                            GetApplicationEventTarget(), 0, &ref)
    }
}
