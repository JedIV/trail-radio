import SwiftUI

@main
struct TrailRadioApp: App {
    @StateObject private var audio = TrailAudio()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(audio).preferredColorScheme(.dark) }
    }
}
