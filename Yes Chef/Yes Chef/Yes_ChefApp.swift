//
//  Yes_ChefApp.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
import SwiftData
import LiveKitWebRTC

@main
struct Yes_ChefApp: App {
    init() {
        LKRTCAudioSession.sharedInstance().useManualAudio = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
        .modelContainer(ModelContainer.shared)
    }
}
