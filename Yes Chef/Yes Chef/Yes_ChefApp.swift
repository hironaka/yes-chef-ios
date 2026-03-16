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
        requestNotificationPermissions()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
        .modelContainer(ModelContainer.shared)
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted!")
            } else if let error = error {
                print("Error requesting permissions: \(error.localizedDescription)")
            }
        }
    }
}
