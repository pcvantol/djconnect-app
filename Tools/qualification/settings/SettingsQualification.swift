import XCTest
import CryptoKit
import ImageIO
import DJConnectCore
#if os(iOS)
import ActivityKit
import WidgetKit
#endif
@testable import DJConnectUI

/// Uses the actual app's ordinary credential store in-process; never exports credentials.
@MainActor final class SettingsQualification: XCTestCase {
    func testReadCurrentSharedSettings() async throws {
        #if os(macOS)
        let bundleID = "dev.djconnect.mac"
        let key = "DJConnectMacDeviceToken"
        #else
        let bundleID = "dev.djconnect.ios"
        let key = "DJConnectIOSDeviceToken"
        #endif
        XCTAssertEqual(Bundle.main.bundleIdentifier, bundleID)
        let model = DJConnectAppModel(tokenStore: DJConnectUserDefaultsTokenStore(key: key), startBackgroundTasks: false)
        guard !model.isDemoMode, model.pairingStatus == .paired else { throw XCTSkip("Actual app is not in an ordinary paired owner context") }
        await model.refreshProfileDJSettings()
        if model.profileDJSettings.response == nil {
            var diagnostics: [String: Any] = ["phase": model.profileDJSettings.phase.rawValue,
                "model_active": model.profileDJSettings.active, "owner_authorized": model.sessionHistory.hasAuthorizedOwner,
                "error_code": model.profileDJSettings.errorCode ?? "none"]
            do {
                let caps = try await model.withHomeAssistantClient { try await $0.activeSessionMoodCapabilities() }
                diagnostics["settings3_capability"] = caps.sharedSettingsAvailable
                let report = try await model.withHomeAssistantClient { client -> [String: String] in
                    let payload = DJConnectStatusPayload(identity: model.identity, haPairingStatus: .paired,
                        language: model.language, logLevel: "info", appBuild: DJConnectApplicationVersion.buildVersion,
                        localAudioSupported: true, voiceSupported: true)
                    var request = try client.statusRequest(payload)
                    var parts = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                    parts.path = "/api/djconnect/v1/profile/settings"
                    parts.queryItems = [.init(name: "contract_version", value: "3"),
                        .init(name: "device_id", value: model.identity.deviceID),
                        .init(name: "client_type", value: model.identity.clientType.rawValue)]
                    request.url = parts.url; request.httpMethod = "GET"; request.httpBody = nil
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    let (bytes, status) = try await DJConnectHybridURLWire().http(request)
                    guard bytes.count <= 65_536 else { return ["http_status": String(status), "bounded": "false"] }
                    do {
                        let direct = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: bytes)
                        return ["http_status": String(status), "direct_valid": String(direct.isValid),
                            "snapshot_valid": String(direct.snapshot.isValid), "scope_valid": String(direct.scope == "profile_and_active_session"),
                            "binding_valid": String(direct.binding.count == 64), "fields_valid": String(Set(direct.writable_fields) == DJConnectProfileDJSettingsResponse.fields),
                            "date_valid": String(DJConnectHistoryEntry.date(direct.as_of) != nil),
                            "allowed_personas_valid": String(direct.allowed_values.persona.allSatisfy { DJConnectSessionPersonaValue(rawValue: $0) != nil })]
                    } catch let error as DecodingError {
                        let path: [any CodingKey]
                        switch error {
                        case .keyNotFound(let key, let context): path = context.codingPath + [key]
                        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context): path = context.codingPath
                        @unknown default: path = []
                        }
                        return ["http_status": String(status), "decode_failure_path": path.map(\.stringValue).joined(separator: ".")]
                    }
                }
                diagnostics["direct_probe"] = report
            } catch { diagnostics["probe_error_domain"] = (error as NSError).domain; diagnostics["probe_error_code"] = (error as NSError).code }
            print("SETTINGS_FAILURE_QUALIFICATION", String(decoding: try JSONSerialization.data(withJSONObject: diagnostics, options: [.sortedKeys]), as: UTF8.self))
        }
        let response = try XCTUnwrap(model.profileDJSettings.response)
        XCTAssertTrue(response.isValid)
        // Profile fingerprint is independent diagnostic history evidence, not
        // a prerequisite for the settings API or its UI.
        let context = try? await model.withHomeAssistantClient { try await $0.profileConversationHistory() }
        let profile = context?.ownerScope
        let hash: (String) -> String = { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() }
        var report: [String: Any] = ["bundle_id": bundleID,
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "profile_fingerprint": profile.map(hash) as Any? ?? NSNull(), "profile_scope_available": profile != nil, "phase": model.profileDJSettings.phase.rawValue,
            "defaults_revision": response.snapshot.defaults_revision,
            "effective": try JSONSerialization.jsonObject(with: JSONEncoder().encode(response.snapshot.effective)),
            "defaults": try JSONSerialization.jsonObject(with: JSONEncoder().encode(response.snapshot.defaults)),
            "requires_selection": response.requiresSelection, "read_only": true,
            "scope": "actual signed app read; no credentials or raw profile/session IDs exported"]
        if let session = response.snapshot.session {
            report["session_fingerprint"] = hash(session.session_id)
            report["session_revision"] = session.revision
        }
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent("DJConnect/SettingsQualification", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
            .write(to: root.appendingPathComponent("readback.json"), options: .atomic)
    }

    /// Reads inventory plus current playback; never sends set_output or changes audio.
    func testCurrentOutputUIFollowsActualPlayback() async throws {
        #if os(macOS)
        let tokenKey = "DJConnectMacDeviceToken"
        #else
        let tokenKey = "DJConnectIOSDeviceToken"
        #endif
        let model = DJConnectAppModel(tokenStore: DJConnectUserDefaultsTokenStore(key: tokenKey), startBackgroundTasks: false)
        guard !model.isDemoMode, model.pairingStatus == .paired else { throw XCTSkip("No paired app context") }
        let refreshed = await model.refreshOutputDevicesAndPlayback()
        XCTAssertTrue(refreshed)
        let device = try XCTUnwrap(model.playback?.device)
        let active = model.availableOutputs.filter { $0.active == true }
        let matching = model.availableOutputs.filter { $0.matchesPlaybackDevice(id: device.id, name: device.name) }
        let current = try XCTUnwrap(matching.count == 1 ? matching.first : nil, "Actual playback has no unambiguous inventory row")
        XCTAssertEqual(active.map(\.id), [current.id])
        XCTAssertEqual(model.selectedOutput, current.name)
        XCTAssertFalse(model.isLoadingOutputs)
        let report: [String: Any] = [
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "read_only": true, "inventory_count": model.availableOutputs.count,
            "active_count": active.count, "active_matches_playback": active.first?.id == current.id,
            "selected_label_matches_playback": model.selectedOutput == current.name,
            "paired": model.pairingStatus == .paired,
            "scope": "actual signed app, devices + status reads; no transfer or device identity exported"]
        print("OUTPUT_UI_QUALIFICATION", String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }

    /// Actual current iOS route + ordinary paired playback, with no audio activation.
    func testCurrentBluetoothOutputName() async throws {
        #if os(iOS)
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.djconnect.ios")
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil else { throw XCTSkip("Physical device required") }
        let model = DJConnectAppModel(tokenStore: DJConnectUserDefaultsTokenStore(key: "DJConnectIOSDeviceToken"), startBackgroundTasks: false)
        guard !model.isDemoMode, model.pairingStatus == .paired else { throw XCTSkip("No ordinary paired app context") }
        let refreshed = await model.refreshOutputDevicesAndPlayback()
        // A physical Spotify transfer can briefly return no playback device.
        // Allow a bounded convergence window using reads only; never transfer audio.
        var settleReads = 0
        for _ in 0..<4 {
            guard model.currentPlaybackBluetoothDeviceName == nil,
                  model.localAudioRoute.bluetoothName != nil else { break }
            try await Task.sleep(for: .seconds(2))
            _ = await model.refreshOutputDevicesAndPlayback()
            settleReads += 1
        }
        let route = model.localAudioRoute
        let device = model.playback?.device
        let matching = model.availableOutputs.filter { $0.active == true && $0.id == device?.id }
        let report: [String: Any] = [
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "read_only": true, "refreshed": refreshed, "settle_reads": settleReads,
            "bluetooth_port_count": route.bluetoothPortNames.count,
            "has_other_route_outputs": route.hasOtherOutputs,
            "route_name_available": route.bluetoothName != nil,
            "playback_type": device?.type ?? "unreported",
            "playback_cached": device?.cached == true,
            "playback_matches_local_name": device?.name?.localizedCaseInsensitiveCompare(route.localDeviceName) == .orderedSame,
            "active_inventory_matches": matching.count,
            "local_bluetooth_match": model.currentPlaybackUsesLocalBluetooth,
            "display_matches_route": model.currentPlaybackBluetoothDeviceName != nil && model.currentPlaybackOutputDisplayName == route.bluetoothName,
            "scope": "actual signed app route/status/inventory reads; no names, IDs or credentials exported; no route/volume/transfer command"]
        print("BLUETOOTH_NAME_QUALIFICATION", String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        XCTAssertTrue(refreshed)
        guard let name = model.currentPlaybackBluetoothDeviceName else { throw XCTSkip("No unambiguous active local Bluetooth playback route for a positive hardware proof") }
        let current = try XCTUnwrap(matching.count == 1 ? matching.first : nil)
        XCTAssertEqual(model.currentPlaybackOutputDisplayName, name)
        XCTAssertEqual(model.outputDisplayName(current), name)
        XCTAssertEqual(name, route.bluetoothName)
        XCTAssertTrue(model.playback?.device?.name?.localizedCaseInsensitiveCompare(route.localDeviceName) == .orderedSame)
        #else
        throw XCTSkip("iOS hardware route qualification")
        #endif
    }

    /// Compare the real paired internal/external status routes in-process.
    /// Status only: no transport reconfiguration, credential export or playback.
    func testQualifyActualPairedRoutes() async throws {
        #if os(macOS)
        let key = "DJConnectMacDeviceToken"
        #else
        let key = "DJConnectIOSDeviceToken"
        #endif
        let store = DJConnectUserDefaultsTokenStore(key: key)
        let model = DJConnectAppModel(tokenStore: store, startBackgroundTasks: false)
        guard !model.isDemoMode, model.pairingStatus == .paired else { throw XCTSkip("No paired owner context") }
        let payload = DJConnectStatusPayload(identity: model.identity, haPairingStatus: .paired,
            language: model.language, logLevel: "info", appBuild: DJConnectApplicationVersion.buildVersion,
            localAudioSupported: true, voiceSupported: true)
        var rows: [[String: Any]] = []
        for (route, raw) in [("internal", model.haLocalURL), ("external", model.haRemoteURL)] {
            guard let url = URL(string: raw), url.host != nil else { continue }
            let client = DJConnectClient(baseURL: url, identity: model.identity, tokenStore: store)
            let started = ContinuousClock.now
            var row: [String: Any] = ["route": route]
            do {
                let response = try await client.postStatus(payload)
                row["status_read"] = "accepted"
                row["playback_present"] = response.playback != nil || response.data != nil
            } catch {
                row["status_read"] = "failed"
                row["error_domain"] = (error as NSError).domain
                row["error_code"] = (error as NSError).code
                if case let DJConnectError.server(status, _) = error { row["http_status"] = status }
                if case DJConnectError.versionMismatch = error { row["version_mismatch"] = true }
                if let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
                    row["underlying_domain"] = underlying.domain; row["underlying_code"] = underlying.code
                }
            }
            row["elapsed_seconds"] = Double(started.duration(to: .now).components.seconds)
            rows.append(row)
        }
        XCTAssertFalse(rows.isEmpty)
        print("PAIRED_ROUTE_QUALIFICATION", String(decoding: try JSONSerialization.data(withJSONObject: [
            "build": DJConnectApplicationVersion.buildVersion, "read_only": true, "routes": rows,
            "scope": "actual signed paired status reads; no URL, bearer, profile or device identifiers exported"
        ], options: [.sortedKeys]), as: UTF8.self))
    }

    /// Read actual installed OS stores and authorization. No grant writes,
    /// widget reloads, Activity requests or private payload/name export.
    func testReadInstalledPassiveSurfaceState() async throws {
        #if os(iOS)
        let now = Date()
        let group = "group.dev.djconnect" // Deliberately read the real store, never write it.
        let shared = try XCTUnwrap(UserDefaults(suiteName: group))
        let snapshotData = shared.data(forKey: DJConnectSessionSurfaceSnapshot.storageKey)
        let snapshot = snapshotData.flatMap { try? JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: $0) }
        var surfaces: [[String: Any]] = []
        for surface in DJConnectPassiveSurface.allCases {
            let data = shared.data(forKey: DJConnectPassiveSurfaceCache.key(surface))
            let value = data.flatMap { try? JSONDecoder().decode(DJConnectPassiveSurfaceCache.self, from: $0) }
            var row: [String: Any] = ["surface": surface.rawValue, "present": data != nil,
                "decodable": value != nil, "current": value?.isCurrent(at: now) == true,
                "pixel_count": value?.pixels.count ?? 0]
            if let value {
                row["received_age_seconds"] = now.timeIntervalSince(value.receivedAt)
                row["projection_current"] = value.projection.isCurrent(at: now)
                row["has_current_music"] = value.projection.currentPlayback(at: now) != nil
                row["has_current_contribution"] = value.projection.currentContribution(at: now) != nil
            }
            surfaces.append(row)
        }
        let configurations = try await WidgetCenter.shared.currentConfigurations()
        let kinds = Set([DJConnectSessionSurfaceSnapshot.widgetKind] + DJConnectSessionSurfaceSnapshot.legacyKinds)
        let model = DJConnectAppModel(tokenStore: DJConnectUserDefaultsTokenStore(key: "DJConnectIOSDeviceToken"), startBackgroundTasks: false)
        await model.refreshProfileDJSettings()
        _ = await model.refreshActiveDJSession()
        let capability = try await model.withHomeAssistantClient { try await $0.passiveSurfaceAvailable() }
        let report: [String: Any] = [
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "read_only": true,
            "group_container_accessible": FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
            "neutral_cache_present": snapshotData != nil, "neutral_cache_decodable": snapshot != nil,
            "neutral_cache_current": snapshot?.isCurrent(at: now) == true,
            "configured_session_widgets": configurations.filter { kinds.contains($0.kind) }.count,
            "activities_enabled": ActivityAuthorizationInfo().areActivitiesEnabled,
            "activity_states": Activity<DJConnectSessionLiveActivityAttributes>.activities.map { String(describing: $0.activityState) },
            "has_previous_request_marker": UserDefaults.standard.string(forKey: "DJConnectSessionSurface.requested") != nil,
            "has_current_request_marker": UserDefaults.standard.string(forKey: DJConnectSessionSurfacePresentation.requestedKey) != nil,
            "server_active_session": model.activeDJSession?.runtimeState == "active",
            "settings_active": model.profileDJSettings.active, "passive_capability": capability,
            "surfaces": surfaces,
            "scope": "actual OS stores/configurations and paired pure reads; no content, IDs, credentials or authorization writes"]
        print("INSTALLED_PASSIVE_QUALIFICATION", String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        #else
        throw XCTSkip("Physical iOS OS-store qualification")
        #endif
    }

    /// Explicit diagnostic surface consent, bounded reads, then revoke. The
    /// test model never publishes to AppGroup/ActivityKit or starts a Session.
    func testQualifyCurrentPassiveSurfaceRead() async throws {
        #if os(macOS)
        let tokenKey = "DJConnectMacDeviceToken"
        #else
        let tokenKey = "DJConnectIOSDeviceToken"
        #endif
        let model = DJConnectAppModel(tokenStore: DJConnectUserDefaultsTokenStore(key: tokenKey), startBackgroundTasks: false)
        guard !model.isDemoMode, model.pairingStatus == .paired else { throw XCTSkip("No paired app context") }
        await model.refreshProfileDJSettings()
        _ = await model.refreshActiveDJSession()
        guard model.activeDJSession?.runtimeState == "active" else { throw XCTSkip("No current active owner Session") }
        await model.preparePassiveSurfaceControls()
        guard model.passiveSurfaces.available else { throw XCTSkip("Passive surface v1 is not available from the current producer") }
        var imageReport: [String: Any] = [:]
        var services = model.passiveSurfaceServices
        let ordinaryImage = services.image
        services.image = { art, response in
            do {
                let bytes = try await ordinaryImage(art, response)
                imageReport["ordinary_read_bytes"] = bytes.count
                return bytes
            } catch {
                let original = error
                imageReport["ordinary_error_domain"] = (error as NSError).domain
                imageReport["ordinary_error_code"] = (error as NSError).code
                if case let DJConnectError.server(status, _) = error { imageReport["ordinary_http_status"] = status }
                // A second pure read diagnoses optional-image failure only. No
                // bytes, URLs, grant or subject identifiers leave the process.
                do {
                    let image = try await model.withHomeAssistantClient { try await $0.passiveSurfaceImage(art, response: response) }
                    imageReport["second_read_width"] = image.image.width
                    imageReport["second_read_height"] = image.image.height
                    let bytes = NSMutableData()
                    if let destination = CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil) {
                        CGImageDestinationAddImage(destination, image.image, nil)
                        imageReport["png_encoded"] = CGImageDestinationFinalize(destination)
                        imageReport["png_bytes"] = bytes.length
                        imageReport["cache_image_byte_limit"] = DJConnectPassiveSurfaceCache.maximumImageBytes
                    }
                } catch {
                    imageReport["second_error_domain"] = (error as NSError).domain
                    imageReport["second_error_code"] = (error as NSError).code
                    if case let DJConnectError.server(status, _) = error { imageReport["second_http_status"] = status }
                }
                throw original
            }
        }
        await model.passiveSurfaces.setEnabled(true, surface: .widget, services: services)
        let cache = model.passiveSurfaces.caches[.widget]
        print("PASSIVE_IMAGE_DIAGNOSIS", String(decoding: try JSONSerialization.data(withJSONObject: [
            "cache_present": cache != nil, "phase_before_disable": model.passiveSurfaces.phases[.widget]?.rawValue ?? "none",
            "images": imageReport
        ], options: [.sortedKeys]), as: UTF8.self))
        // Revoke even when no eligible content was returned. Do not retain a
        // diagnostic grant or turn the ordinary app's surface choice on.
        await model.setPassiveSurface(.widget, enabled: false)
        XCTAssertFalse(model.passiveSurfaces.enabled(.widget))
        XCTAssertNil(model.passiveSurfaces.caches[.widget])
        XCTAssertEqual(model.passiveSurfaces.phases[.widget], .idle, "Server disable acknowledgement is required")
        let value = try XCTUnwrap(cache, "No current qualified passive projection")
        let now = Date()
        let contribution = value.projection.currentContribution(at: now) != nil
        let music = value.projection.currentPlayback(at: now) != nil
        let report: [String: Any] = ["build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "current": value.isCurrent(at: now), "has_contribution": contribution, "has_now_playing": music,
            "qualified_artwork_count": value.projection.artwork.count, "loaded_pixel_count": value.pixels.count, "image_diagnosis": imageReport,
            "local_withdrawal": !model.passiveSurfaces.enabled(.widget), "server_disable_confirmed": model.passiveSurfaces.phases[.widget] == .idle, "os_publication": false,
            "scope": "actual signed app + paired HA; temporary explicit diagnostic grant; no OS cache or media effects"]
        print("PASSIVE_SURFACE_QUALIFICATION", String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        XCTAssertTrue(value.isCurrent(at: now))
        XCTAssertTrue(contribution || music, "A neutral-only response is not positive rich-content acceptance")
    }

    func testQualifyCurrentArtworkDelivery() async throws {
        #if os(macOS)
        let tokenKey = "DJConnectMacDeviceToken"
        #else
        let tokenKey = "DJConnectIOSDeviceToken"
        #endif
        let model = DJConnectAppModel(tokenStore: DJConnectUserDefaultsTokenStore(key: tokenKey), startBackgroundTasks: false)
        guard !model.isDemoMode, model.pairingStatus == .paired else { throw XCTSkip("No paired app context") }
        await model.refreshProfileDJSettings()
        await model.sessionHistory.prepare()
        _ = await model.refreshActiveDJSession()
        _ = await model.sessionHistory.loadSessions()
        var report: [String: Any] = ["artwork_capability": model.sessionHistory.artworkAvailable,
            "history_capability": model.sessionHistory.available, "profile_authorized": model.sessionHistory.hasAuthorizedOwner,
            "active_media_count": model.activeDJSession?.broadcast.sessionMedia.count ?? 0]
        var outcomes: [[String: Any]] = []
        if let sessionID = model.activeDJSession?.id ?? model.sessionHistory.sessions.first?.id {
            await model.sessionHistory.loadTimeline(sessionID)
            let entries = model.sessionHistory.timelines[sessionID]?.entries ?? []
            report["loaded_entry_count"] = entries.count
            for entry in entries.filter({ [.playbackObserved, .djMoment].contains($0.kind) }).prefix(4) {
                await model.sessionHistory.refreshArtwork(for: entry)
                let media = model.sessionHistory.timelines[sessionID]?.entries.first(where: { $0.reference == entry.reference })?.sessionMedia
                var row: [String: Any] = ["kind": entry.kind.rawValue, "projection_present": media != nil,
                    "state": media?.artwork.state.rawValue ?? "absent", "reason": media?.artwork.reason ?? "none"]
                if let media {
                    let audience: DJConnectSessionMedia.Audience = media.artwork.historicalDisplayAllowed ? .history : .activeFlow
                    row["grant_admitted"] = media.admittedArtwork(session: sessionID, target: .entry(entry.id), audience: audience) != nil
                    if row["grant_admitted"] as? Bool == true {
                        do { let image = try await model.loadSessionArtwork(media, target: .entry(entry.id), audience: audience); row["pixels_loaded"] = image.image.width > 0 }
                        catch {
                            row["pixels_loaded"] = false
                            row["error_domain"] = (error as NSError).domain
                            row["error_code"] = (error as NSError).code
                            row["locally_current"] = model.sessionArtworkIsCurrent(media, target: .entry(entry.id), audience: audience)
                            if case let DJConnectError.server(statusCode, _) = error { row["http_status"] = statusCode }
                            if case DJConnectError.invalidResponse = error { row["invalid_response"] = true }
                        }
                    }
                }
                outcomes.append(row)
            }
        }
        report["outcomes"] = outcomes
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        print("ARTWORK_QUALIFICATION", String(decoding:data,as:UTF8.self))
    }
}
