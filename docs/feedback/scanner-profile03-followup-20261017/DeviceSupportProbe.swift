import XCTest
import DeviceCheck
import UIKit
@MainActor
final class PhysicalProbe: XCTestCase {
    func testReadDeviceAppAttestSupportOnly() throws {
        let supported = DCAppAttestService.shared.isSupported
        let data: [String: Any] = ["isSupported": supported, "os_version": UIDevice.current.systemVersion, "device_model": UIDevice.current.model, "runner_bundle_id": Bundle.main.bundleIdentifier ?? "unknown", "scope": "physical device service support from XCTest runner; not DJConnect app identity or enrollment", "keys_generated": false, "receipts_collected": false]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: data, options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "Read-only App Attest device support"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCUIApplication(bundleIdentifier: "dev.djconnect.ios").activate()
    }
}
