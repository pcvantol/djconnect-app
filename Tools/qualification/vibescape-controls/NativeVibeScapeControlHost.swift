import SwiftUI
import Foundation
import AVFoundation
import Speech
import DJConnectCore
@testable import DJConnectUI

final class VisualButtonWire: URLProtocol, @unchecked Sendable {
 static let lock=NSLock()
 nonisolated(unsafe) static var calls:[String]=[]
 nonisolated(unsafe) static var capabilityReads=0
 nonisolated(unsafe) static var phases:[String]=[]
 static func phase(_ text:String){lock.withLock{phases.append(text)}}
 static var trace:String {lock.withLock{phases.joined(separator:">")}}
 static var status:String { lock.withLock { "caps:\(capabilityReads) post:\(calls.filter{$0.hasPrefix("POST ")}.count) context:\(calls.filter{$0.contains("/vibescape/context")}.count) ask:\(calls.filter{$0.contains("/ask_dj/message")}.count)" } }
 override class func canInit(with request:URLRequest)->Bool {true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
 override func startLoading() {
  do {
   let path=request.url!.path
   let number=Self.lock.withLock { Self.calls.append((request.httpMethod ?? "GET")+" "+path); if path.hasSuffix("/capabilities") {Self.capabilityReads += 1};return Self.capabilityReads }
   let root=Bundle.main.resourceURL!
   let receipt=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("session-history-producer-receipt.json"))) as! [String:Any]
   let moment=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("moment-contract-receipt.json"))) as! [String:Any]
   var runtime=moment["runtime"] as! [String:Any];runtime["mood_revision"]=0
   var broadcast=runtime["broadcast"] as! [String:Any];var session=broadcast["session"] as! [String:Any];session["mood_revision"]=0;broadcast["session"]=session;runtime["broadcast"]=broadcast
   var value:Any;var status=200
   if path.hasSuffix("/capabilities") {
    var caps=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("vibescape-visual-catalogue-v1.json"))) as! [String:Any]
    var flags=caps["capabilities"] as! [String:Bool];flags["session_conversation_history"]=true;caps["capabilities"]=flags;caps["contract_versions"]=["session_conversation_history":1]
    var catalogue=caps["vibescape_visual_director"] as! [String:Any];var help=catalogue["help"] as! [String:Any];var english=help["en"] as! [String:Any];var examples=english["examples"] as! [[String:Any]];examples[0]["text"]="Probe visual read \(number)";english["examples"]=examples;help["en"]=english;catalogue["help"]=help;caps["vibescape_visual_director"]=catalogue;value=caps
   } else if path.hasSuffix("/session/active") {value=["success":true,"session":runtime]}
   else if path.hasSuffix("/ask_dj/history") {value=receipt["later_historical_answer"]!}
   else if path.contains("/session/history/") {
    var page=receipt["archived_timeline"] as! [String:Any];var header=page["session"] as! [String:Any];header["session_id"]=runtime["session_id"];header["lifecycle_status"]="ACTIVE";header["read_only"]=false;header["ended_at"]="";header["interrupted_at"]="";page["session"]=header;page["entries"]=[] as [[String:Any]]
    let query=URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems ?? []
    if let window=query.first(where:{$0.name=="window"})?.value {page["window"]=window;page["window_limit"]=20;page["scan_complete"]=true};value=page
   } else {value=["success":false,"error":"no_synthetic_route"];status=404}
   let data=try JSONSerialization.data(withJSONObject:value)
   let response=HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json","Cache-Control":"no-store"])!
   client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
  } catch {client?.urlProtocol(self,didFailWithError:error)}
 }
 override func stopLoading() {}
}

@MainActor final class ProbeState:ObservableObject {
 let model:DJConnectAppModel
 @Published var ready=false
 let defaults:UserDefaults
 let suite:String
 init() {
  suite="visual-button-probe-"+UUID().uuidString;defaults=UserDefaults(suiteName:suite)!
  defaults.set("http://visual-button-synthetic.test:8123",forKey:"DJConnectHomeAssistantURL");defaults.set("http://visual-button-synthetic.test:8123",forKey:"DJConnectHALocalURL");defaults.set("local",forKey:"DJConnectHAConnectionMode")
  let configuration=URLSessionConfiguration.ephemeral;configuration.protocolClasses=[VisualButtonWire.self]
  model=DJConnectAppModel(defaults:defaults,tokenStore:DJConnectInMemoryTokenStore(token:"synthetic-fixture-token"),urlSession:URLSession(configuration:configuration),startBackgroundTasks:false)
  model.language="en"
  Task { await model.sessionHistory.prepare();await model.refreshActiveDJSession();model.isShowingVibeScape=true;ready=true }
 }
 func stop() {model.markInactiveSession();defaults.removePersistentDomain(forName:suite)}
}
@main struct VisualButtonProbeApp:App {var body:some Scene {WindowGroup {VisualButtonProbe()}}}
struct VisualButtonProbe:View {
 @StateObject private var state=ProbeState()
 @Environment(\.scenePhase) private var phase
 var body:some View {
  ZStack(alignment:.topLeading) {
   if state.ready {ActiveVisualProbe(model:state.model)}else{ProgressView()}
   TimelineView(.periodic(from:.now,by:0.25)) {_ in
    Text("mic:\(AVCaptureDevice.authorizationStatus(for:.audio).rawValue) speech:\(SFSpeechRecognizer.authorizationStatus().rawValue) "+VisualButtonWire.status+" ready:\(state.ready ? 1:0) mode:\(state.model.isShowingVibeScape ? 1:0) phases:"+VisualButtonWire.trace)
     .font(.caption2).padding(4).foregroundStyle(.white).background(.black.opacity(0.8)).accessibilityIdentifier("probe-status")
   }
  }.overlay(alignment:.topTrailing) {
   Button("Withdraw fixture owner") {state.model.sessionHistory.suspend()}
    .buttonStyle(.bordered).accessibilityIdentifier("probe-withdraw-owner").padding(.top,230)
  }.preferredColorScheme(.dark).onChange(of:phase){_,value in VisualButtonWire.phase("\(value):mic\(AVCaptureDevice.authorizationStatus(for:.audio).rawValue):mode\(state.model.isShowingVibeScape ? 1:0)")}.onDisappear{state.stop()}
 }
}

struct ActiveVisualProbe:View {
 @ObservedObject var model:DJConnectAppModel
 var body:some View {
  if model.isShowingVibeScape {VibeScapeScreen(model:model)}
  else {Text("VibeScape closed").accessibilityIdentifier("probe-closed")}
 }
}
