import Foundation

public enum DJConnectThirdPartyNotices {
    public static var joseSwiftLicense: String {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for:DJConnectThirdPartyBundleToken.self)
        #endif
        guard let url = bundle.url(forResource:"JOSESwift-LICENSE",withExtension:"txt"),
              let license = try? String(contentsOf:url,encoding:.utf8) else {
            return "JOSESwift 3.0.0 — Apache License 2.0: https://www.apache.org/licenses/LICENSE-2.0"
        }
        return "JOSESwift 3.0.0 — Copyright 2024 Airside Mobile Inc.\n\n" + license
    }
}

private final class DJConnectThirdPartyBundleToken {}
