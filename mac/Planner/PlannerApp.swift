import SwiftUI

@main
struct PlannerApp: App {
    @StateObject private var viewModel = PlannerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
