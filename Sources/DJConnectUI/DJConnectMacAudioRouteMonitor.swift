#if os(macOS)
import Foundation
@preconcurrency import CoreAudio
import SystemConfiguration

/// Read-only hardware presentation. No audio session activation, device switching,
/// Bluetooth discovery, provider inventory mutation or durable state.
@MainActor final class DJConnectMacAudioRouteMonitor {
    private var systemObservation: MacAudioPropertyObservation?
    private var deviceObservations: [MacAudioPropertyObservation] = []
    private var observedDevice = AudioObjectID(kAudioObjectUnknown)
    private var changed: (@MainActor (DJConnectLocalAudioRoute) -> Void)?

    func start(_ changed: @escaping @MainActor (DJConnectLocalAudioRoute) -> Void) {
        stop()
        self.changed = changed
        systemObservation = observe(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
        refresh()
    }

    func stop() {
        systemObservation = nil; deviceObservations.removeAll()
        observedDevice = AudioObjectID(kAudioObjectUnknown); changed = nil
    }

    private func observe(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> MacAudioPropertyObservation? {
        MacAudioPropertyObservation(object: object, selector: selector) { [weak self] in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    private func refresh() {
        guard changed != nil else { return } // Retired queued callbacks cannot re-register listeners.
        // Always reread the current default. A queued callback from a retired
        // device must never restore that device's name during A→B→A switches.
        let device = Self.defaultOutputDevice()
        if device != observedDevice {
            deviceObservations.removeAll(); observedDevice = device
            if device != kAudioObjectUnknown {
                deviceObservations = [kAudioObjectPropertyName, kAudioDevicePropertyTransportType].compactMap { observe(device, $0) }
            }
        }
        changed?(Self.snapshot())
    }

    static func snapshot() -> DJConnectLocalAudioRoute {
        let computer = SCDynamicStoreCopyComputerName(nil, nil) as String? ?? ""
        let device = defaultOutputDevice()
        guard device != kAudioObjectUnknown else { return route(computer: computer, output: nil, transport: nil) }
        var transport: UInt32 = 0
        var address = property(kAudioDevicePropertyTransportType)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let transportStatus = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport)
        // Core Audio returns an owned CFString for this property (AudioHardwareBase.h).
        var name: Unmanaged<CFString>?
        address = property(kAudioObjectPropertyName)
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let nameStatus = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, $0)
        }
        let outputName = name?.takeRetainedValue() as String?
        // Do not combine properties from different defaults if it switched mid-read.
        guard device == defaultOutputDevice() else { return route(computer: computer, output: nil, transport: nil) }
        return route(computer: computer, output: nameStatus == noErr ? outputName : nil,
                     transport: transportStatus == noErr ? transport : nil)
    }

    static func route(computer: String, output: String?, transport: UInt32?) -> DJConnectLocalAudioRoute {
        let bluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        return .init(localDeviceName: computer, bluetoothPortNames: bluetooth ? [output ?? ""] : [],
                     hasOtherOutputs: !bluetooth, localDeviceTypes: ["computer"])
    }

    private static func defaultOutputDevice() -> AudioObjectID {
        var device = AudioObjectID(kAudioObjectUnknown)
        var address = property(kAudioHardwarePropertyDefaultOutputDevice)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else {
            return AudioObjectID(kAudioObjectUnknown)
        }
        return device
    }

    private static func property(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        .init(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
}

/// Each registration removes the exact block on release, including when its
/// owning model disappears. Core Audio removal is safe off the main actor too.
private final class MacAudioPropertyObservation {
    private let object: AudioObjectID
    private let selector: AudioObjectPropertySelector
    private let block: AudioObjectPropertyListenerBlock
    init?(object: AudioObjectID, selector: AudioObjectPropertySelector, changed: @escaping @Sendable () -> Void) {
        self.object = object; self.selector = selector
        block = { _, _ in changed() }
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectAddPropertyListenerBlock(object, &address, .main, block) == noErr else { return nil }
    }
    deinit {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
    }
}
#endif
