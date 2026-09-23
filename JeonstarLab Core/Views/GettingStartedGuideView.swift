#if os(iOS) || os(macOS)
  import SwiftUI

  enum GuideAudience { case phone, mac }

  /// Informational only: the guide does not start recording, discover peers, or request permissions.
  struct GettingStartedGuideView: View {
    let audience: GuideAudience
    var onFinish: () -> Void
    @State private var page = 0

    var body: some View {
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              Text("Getting Started")
              Spacer()
              Text("\(page + 1) of 3").monospacedDigit()
            }
            .font(.caption).foregroundStyle(.secondary)
            Image(systemName: symbol)
              .font(.system(size: 44, weight: .medium))
              .foregroundStyle(.tint)
              .accessibilityHidden(true)
            Text(title).font(.largeTitle.weight(.bold))
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityAddTraits(.isHeader)
            Text(subtitle).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 18) {
              ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                HStack(alignment: .top, spacing: 12) {
                  Text("\(index + 1)")
                    .font(.callout.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: Circle())
                  Text(instruction).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
            }
          }
          .padding(24)
        }
        Divider()
        HStack(spacing: 14) {
          Button("Skip", action: onFinish).foregroundStyle(.secondary)
          Spacer()
          if page > 0 { Button("Back") { page -= 1 } }
          Button(page == 2 ? "Get Started" : "Next") {
            if page == 2 { onFinish() } else { page += 1 }
          }
          .buttonStyle(.borderedProminent)
        }
        .padding(20)
      }
      .onAppear { page = 0 }
    }

    private var symbol: String {
      if page == 0 { return "applewatch" }
      if page == 1 { return audience == .phone ? "waveform.path" : "arrow.down.circle" }
      return audience == .phone ? "laptopcomputer" : "tag"
    }
    private var title: String {
      switch (audience, page) {
      case (_, 0): "One workflow. Three devices."
      case (.phone, 1): "Record, then take a look."
      case (.phone, _): "Continue on your Mac."
      case (.mac, 1): "Receive your first recording."
      case (.mac, _): "Turn motion into a dataset."
      }
    }
    private var subtitle: String {
      switch (audience, page) {
      case (_, 0):
        "Use WatchMotion Editor on your Apple Watch, its paired iPhone, and your Mac for the complete workflow."
      case (.phone, 1): "Your iPhone is the place to review recordings and pass them on."
      case (.phone, _): "Start receiving on the Mac before searching from your iPhone."
      case (.mac, 1): "Keep the devices nearby with Wi-Fi and Bluetooth enabled."
      case (.mac, _): "Keep your original recordings and build labeled motion segments."
      }
    }
    private var instructions: [String] {
      switch (audience, page) {
      case (_, 0):
        [
          "Apple Watch captures your wrist's motion. Install the Watch app on the Watch paired with your iPhone.",
          "iPhone receives the recording, shows a motion preview, and sends files to your Mac.",
          "Mac lets you select segments, assign labels, organize folders, and export datasets.",
        ]
      case (.phone, 1):
        [
        "Open the Watch app and tap Record. Keep it open while recording. Tap Stop to save and queue delivery to iPhone; moving the app to the background also saves and stops.",
          "Open a recording on your iPhone to check its duration and acceleration, gyroscope, or attitude graphs.",
          "Add context in the Notes section. Saved files on the Watch remain until your iPhone confirms import.",
        ]
      case (.phone, _):
        [
          "In the Mac app, choose Start Receiving. On iPhone, open a recording and tap Find Mac, then Connect.",
          "Allow local network access when prompted. Once connected, tap Send to Mac. You can also share the original files.",
          "Connection Settings contains automatic transfer and this tutorial. Labeling and dataset editing happen on Mac.",
        ]
      case (.mac, 1):
        [
          "Choose Start Receiving in this app.",
          "On iPhone, open a recording, choose Find Mac, and connect to this Mac. Allow local network access when prompted.",
          "Tap Send to Mac on iPhone. When the recording appears here, select it to open the motion charts.",
        ]
      case (.mac, _):
        [
          "Select a time range in a chart, then save it as a snap. Assign a label and add notes in the inspector.",
          "Use the workspace Settings menu → Project Labels to create your own labels and colors. Add labeled snaps to folders.",
          "Export a folder as a dataset, or export a .watchmotion project to keep recordings and label settings together. Reopen this guide from Settings.",
        ]
      }
    }
  }
#endif
