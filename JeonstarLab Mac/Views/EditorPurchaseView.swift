import SwiftUI
import StoreKit

struct EditorPurchaseView: View {
    @State private var store = EditorPurchaseStore.shared
    @Environment(\.dismiss) private var dismiss
    private let coral = Color(red: 1, green: 0.32, blue: 0.34)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    RadialGradient(colors: [coral.opacity(0.36), .clear], center: .center, startRadius: 5, endRadius: 180)
                    Canvas { context, size in
                        for row in 0..<6 {
                            var path = Path()
                            for step in 0...180 {
                                let x = size.width * Double(step) / 180
                                let y = size.height / 2 + sin(Double(step) / 13 + Double(row) * 0.24) * 22
                                    + cos(Double(step) / 7) * 8
                                if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            context.stroke(path, with: .color(coral.opacity(0.14 + Double(row) * 0.035)), lineWidth: 1)
                        }
                    }
                    HStack(spacing: 7) {
                        Text("[").foregroundStyle(coral)
                        Image(systemName: "waveform.path").foregroundStyle(.white)
                        Text("]").foregroundStyle(coral)
                    }
                    .font(.system(size: 45, weight: .medium))
                    .frame(width: 112, height: 104)
                    .background(.black.gradient, in: RoundedRectangle(cornerRadius: 25))
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(coral.opacity(0.55)))
                    .shadow(color: coral.opacity(0.3), radius: 20)
                    .accessibilityHidden(true)
                }
                .frame(height: 136)
                Text("FULL ACCESS").font(.caption.weight(.bold)).tracking(2)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(coral.gradient, in: Capsule())
                VStack(spacing: 9) {
                    Text(store.isUnlocked ? String(localized: "You're all set") : String(localized: "Unlock WatchMotion Editor"))
                        .font(.system(size: 27, weight: .bold)).multilineTextAlignment(.center)
                    Text(store.isUnlocked ? String(localized: "Full access is active on this Mac.") : store.reason)
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if !store.isUnlocked {
                        Text("Turn every recording into a finished dataset.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                VStack(spacing: 8) {
                    benefit("Unlimited projects and recordings", symbol: "square.3.layers.3d")
                    benefit("Auto Segments and custom labels", symbol: "waveform.path")
                    benefit("CSV and Create ML exports", symbol: "doc.text")
                }
                VStack(spacing: 12) {
                    if !store.isUnlocked {
                        Text("One-time purchase · No subscription").font(.callout).foregroundStyle(.secondary)
                        if let product = store.product {
                            Text(product.displayPrice).font(.system(size: 38, weight: .bold, design: .rounded))
                        } else {
                            Text("Price unavailable").font(.title3).foregroundStyle(.secondary)
                            Button("Reload Price") { Task { await store.loadProduct() } }
                        }
                        Button { Task { await store.purchase() } } label: {
                            HStack {
                                if store.isBusy { ProgressView().controlSize(.small) }
                                Text("Unlock Forever").font(.headline)
                            }.frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .background(LinearGradient(colors: [Color(red: 1, green: 0.49, blue: 0.40), coral], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
                        .opacity(store.product == nil || store.isBusy ? 0.5 : 1)
                        .disabled(store.product == nil || store.isBusy)
                    }
                    Button(store.isUnlocked ? String(localized: "Continue Editing") : String(localized: "Not Now")) { dismiss() }
                        .buttonStyle(.bordered).controlSize(.large).keyboardShortcut(.cancelAction)
                    if let message = store.message {
                        Text(message).font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).accessibilityLabel(message)
                    }
                    if !store.isUnlocked {
                        Button("Restore Purchases") { Task { await store.restore() } }
                            .buttonStyle(.plain).foregroundStyle(coral).disabled(store.isBusy)
                    }
                }
                .padding(18).frame(maxWidth: .infinity)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            }.padding(26)
        }
        .frame(width: 520, height: min(760, (NSScreen.main?.visibleFrame.height ?? 830) - 70))
        .background(Color(red: 0.095, green: 0.105, blue: 0.12))
        .preferredColorScheme(.dark)
    }

    private func benefit(_ title: LocalizedStringKey, symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(coral).frame(width: 30)
            Text(title).font(.callout)
            Spacer(minLength: 0)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.09)))
    }
}
