//
//  WageTickApp.swift
//  WageTick
//
//  Created by Dan Morgan on 11/03/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct WageTickApp: App {

    var sharedModelContainer: ModelContainer = .shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    RecurringShiftGenerator.extendIfNeeded(
                        context: sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

