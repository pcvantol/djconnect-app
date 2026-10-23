# Offline ActivityKit wire probe

`ActivityStateWireProbe.swift` imports the real ActivityKit and DJConnectCore iOS framework. Compile it for an owned iOS simulator against a framework whose two relevant source blobs match the handoff, then run the executable with simctl spawn on that simulator. It calls no Activity SDK effects or network. No installed app or paired profile is used.

The original run used the iPhoneSimulator27.1 SDK/arm64 target and the owned iOS27.0 simulator. The framework was the already qualified Help host's Core framework, with its unchanged Attributes/ContentState source blobs independently checked against protected027354f. Source, framework and probe hashes are in the private source-binding receipt. The resulting JSON is imported unchanged under Tests/Fixtures; ordinary package tests assert source-model roundtrip and original dates.

This is codec evidence only. It grants no push purpose, external content right, native token, provider admission or production Activity profile. See docs/feedback/APPLE_ACTIVITY_PUSH_CODEC_20261023.md.
