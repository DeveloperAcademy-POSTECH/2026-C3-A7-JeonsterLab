import SwiftUI

struct MacTutorialWindow: View {
  @Environment(\.dismissWindow) private var dismissWindow
  var body: some View {
    GettingStartedGuideView(audience: .mac) { dismissWindow(id: "getting-started") }
      .frame(width: 620, height: 540)
      .editorAppearance()
  }
}
