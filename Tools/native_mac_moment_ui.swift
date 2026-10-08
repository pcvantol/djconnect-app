import AppKit
import ApplicationServices
import CoreGraphics
let args=CommandLine.arguments
let pid=pid_t(args[1])!
guard let process=NSRunningApplication(processIdentifier:pid),process.bundleIdentifier=="dev.djconnect.mac.momentproof",["/private/tmp/djc-mac-momentproof.app","/private/tmp/djc-mac-momentproof-final.app"].contains(process.bundleURL?.path ?? "") else {fatalError("Only the isolated temporary test bundle is allowed")}
func get(_ e:AXUIElement,_ k:String)->CFTypeRef? {var v:CFTypeRef?;return AXUIElementCopyAttributeValue(e,k as CFString,&v) == .success ? v:nil}
let app=AXUIElementCreateApplication(pid)
func nodes(_ e:AXUIElement,_ depth:Int=0)->[AXUIElement] {guard depth<24 else{return []};return [e]+(get(e,kAXChildrenAttribute) as? [AXUIElement] ?? []).flatMap{nodes($0,depth+1)}}
let windows=get(app,kAXWindowsAttribute) as? [AXUIElement] ?? []
let elements=windows.flatMap{nodes($0)}
let mode=args[2]
if mode=="read" {
 for e in elements {
  let role=get(e,kAXRoleAttribute) as? String ?? ""
  let label=(get(e,kAXDescriptionAttribute) as? String).flatMap{$0.isEmpty ? nil:$0} ?? (get(e,kAXTitleAttribute) as? String ?? "")
  let value=get(e,kAXValueAttribute) as? String ?? ""
  if !label.isEmpty || (role=="AXStaticText" && !value.isEmpty) {print(role,label,value)}
 }
} else if mode=="press" {
 let needle=args[3]
 guard let e=elements.first(where:{(get($0,kAXRoleAttribute) as? String)=="AXButton" && ((get($0,kAXDescriptionAttribute) as? String)==needle || (get($0,kAXTitleAttribute) as? String)==needle)}) else{fatalError("Native button absent: "+needle)}
 let result=AXUIElementPerformAction(e,kAXPressAction as CFString)
 guard result == .success else{fatalError("Native press failed")};print("pressed",needle)
} else if mode=="windowid" {
 let records=CGWindowListCopyWindowInfo([.optionAll],kCGNullWindowID) as? [[String:Any]] ?? []
 for w in records where (w[kCGWindowOwnerPID as String] as? Int)==Int(pid) {
  if let b=w[kCGWindowBounds as String] as? [String:Double],b["Height",default:0]>300 {print(w[kCGWindowNumber as String] ?? "");break}
 }
}
