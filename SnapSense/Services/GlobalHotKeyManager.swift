import Carbon.HIToolbox
import Foundation

enum GlobalHotKeyError: LocalizedError {
    case installHandlerFailed(OSStatus)
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .installHandlerFailed(let status):
            return "Carbon: не удалось установить обработчик (код \(status))."
        case .registrationFailed(let status):
            return "Carbon: не удалось зарегистрировать комбинацию (код \(status))."
        }
    }
}

private let snapSenseHotKeySignature: OSType = 0x534E5345 // 'SNSE'
private let snapSenseHotKeyID: UInt32 = 1

private func snapSenseHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var eventHotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &eventHotKeyID
    )
    guard status == noErr else { return status }

    let manager = Unmanaged<GlobalHotKeyManager>
        .fromOpaque(userData)
        .takeUnretainedValue()

    Task { @MainActor in
        manager.handleHotKey(eventHotKeyID)
    }

    return noErr
}

/// A tiny Carbon wrapper for a system-wide hot key.
///
/// Carbon's `RegisterEventHotKey` works above full-screen applications and does
/// not require Accessibility permission, unlike `CGEvent` taps.
@MainActor
final class GlobalHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    func register(
        keyCode: UInt32,
        modifiers: UInt32,
        action: @escaping () -> Void
    ) throws {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            snapSenseHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            throw GlobalHotKeyError.installHandlerFailed(handlerStatus)
        }

        let identifier = EventHotKeyID(
            signature: snapSenseHotKeySignature,
            id: snapSenseHotKeyID
        )

        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }
            throw GlobalHotKeyError.registrationFailed(registrationStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        action = nil
    }

    fileprivate func handleHotKey(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == snapSenseHotKeySignature,
              hotKeyID.id == snapSenseHotKeyID else {
            return
        }
        action?()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
