// swift-tools-version: 6.0
import PackageDescription

// Isolated qualification only. The shipping app/package has no dependency on this target.
let package = Package(name: "VibeCastBindingQualification", platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "VibeCastBindingQualification", targets: ["VibeCastBindingQualification"])],
    targets: [.target(name: "VibeCastBindingQualification"),
              .testTarget(name: "VibeCastBindingQualificationTests", dependencies: ["VibeCastBindingQualification"])])
