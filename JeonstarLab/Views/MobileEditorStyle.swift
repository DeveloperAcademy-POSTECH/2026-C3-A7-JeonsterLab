import SwiftUI

/// Shared appearance for the iPhone list, detail, connection settings, and sheets.
struct MobileEditorStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.tint(colorScheme == .dark
                     ? Color(red: 0.22, green: 0.53, blue: 0.96)
                     : Color(red: 0.92, green: 0.25, blue: 0.27))
    }
}

extension View {
    func mobileEditorStyle() -> some View { modifier(MobileEditorStyle()) }
}
