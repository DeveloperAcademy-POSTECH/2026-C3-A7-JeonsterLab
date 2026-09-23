import AppKit
import SwiftUI

enum EditorAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum EditorPalette {
    static let background = adaptive(light: 0xF4F5F7, dark: 0x15191F)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1D232B)
    static let border = adaptive(light: 0xE1E4E9, dark: 0x343C46)
    static let accent = adaptive(light: 0xEB4045, dark: 0x3987F5)
    static let sidebar = Color(red: 0.075, green: 0.085, blue: 0.10)
    static let coral = Color(red: 0.92, green: 0.25, blue: 0.27)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

private struct EditorAppearanceModifier: ViewModifier {
    @AppStorage("WatchMotionEditor.appearance") private var appearance = EditorAppearance.system
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearance.colorScheme)
            .tint((appearance.colorScheme ?? systemScheme) == .dark ? .blue : EditorPalette.coral)
    }
}

extension View {
    func editorAppearance() -> some View { modifier(EditorAppearanceModifier()) }

    func editorSurface() -> some View {
        background(EditorPalette.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(EditorPalette.border, lineWidth: 1))
    }
}

struct EditorAppearanceMenu: View {
    @AppStorage("WatchMotionEditor.appearance") private var appearance = EditorAppearance.system

    var body: some View {
        Menu {
            Picker("Appearance", selection: $appearance) {
                ForEach(EditorAppearance.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Label("Appearance", systemImage: "circle.lefthalf.filled")
        }
        .help("Appearance: System, Light, or Dark")
    }
}
