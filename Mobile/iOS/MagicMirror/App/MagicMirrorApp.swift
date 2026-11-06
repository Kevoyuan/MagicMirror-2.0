import SwiftUI

@main
struct MagicMirrorApp: App {
    var body: some Scene {
        WindowGroup {
            MirrorScreen()
                .preferredColorScheme(.dark)
        }
    }
}
