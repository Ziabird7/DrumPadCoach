import SwiftUI
import SwiftData

@main
struct DrumPadCoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: PracticeHistoryRecord.self)
    }
}
