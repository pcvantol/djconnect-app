import SwiftUI
@testable import DJConnectUI
@main struct ContributionProbeApp: App { var body: some Scene { WindowGroup { ContributionProbe() } } }
struct ContributionProbe: View {
 @State var requests=0; @State var controls=0
 var body: some View { VStack {
 Text("requests:\(requests)").accessibilityIdentifier("requests")
 Text("controls:\(controls)").accessibilityIdentifier("controls")
 ScrollView {
 VStack(alignment:.leading,spacing:20) {
 if ProcessInfo.processInfo.arguments.contains("--grouped-text") {
  VStack(alignment:.leading) {
   Text("This original contribution stays selected when the current track changes. Select its words or tap once to ask for more.").accessibilityIdentifier("contribution-content")
   Text("Another paragraph in the same answer.")
  }.font(.title2).modifier(ContributionContentAction(question:"Tell me more",action:{requests += 1}))
 } else {
  Text("This original contribution stays selected when the current track changes. Select its words or tap once to ask for more.")
   .font(.title2).accessibilityIdentifier("contribution-content")
   .modifier(ContributionContentAction(question:"Tell me more",action:{requests += 1}))
 }
 HStack { ForEach(["Play", "TTS", "Artwork", "Source", "Avatar"],id:\.self) { name in Button(name) {controls += 1}.accessibilityIdentifier("sibling-"+name) } }
 Color.blue.frame(height:60).accessibilityElement().accessibilityLabel("Contribution menu").accessibilityIdentifier("menu-area").contextMenu {Button("Remove contribution") {controls += 1}}
 ForEach(0..<40) {Text("Scroll row \($0)").frame(height:50)}
 }.padding().frame(maxWidth:.infinity,alignment:.leading)
 }
 }.padding().preferredColorScheme(.dark) }
}
