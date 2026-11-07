import SwiftUI

/// Shared, semantic colors for the selected Leonardo anatomy-notebook UI.
/// The camera image and Metal anatomy colors are deliberately independent.
enum LeonardoPalette {
    static let parchment = Color(red: 0.953, green: 0.922, blue: 0.867)
    static let agedPaper = Color(red: 0.875, green: 0.820, blue: 0.725)
    static let ink = Color(red: 0.200, green: 0.176, blue: 0.153)
    static let mutedInk = Color(red: 0.455, green: 0.408, blue: 0.353)
    static let copper = Color(red: 0.651, green: 0.475, blue: 0.322)
    static let verdigris = Color(red: 0.220, green: 0.404, blue: 0.365)
    static let ivory = Color(red: 0.985, green: 0.968, blue: 0.920)
    static let cameraScrim = Color(red: 0.083, green: 0.095, blue: 0.086)
}

/// Decorative manuscript rule; not a tappable or announced element.
struct ManuscriptRule: View {
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(LeonardoPalette.copper.opacity(0.52))
                .frame(height: 1)
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(LeonardoPalette.copper.opacity(0.8))
            Rectangle()
                .fill(LeonardoPalette.copper.opacity(0.52))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}
