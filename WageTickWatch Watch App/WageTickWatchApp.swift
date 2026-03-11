//
//  WageTickWatchApp.swift
//  WageTickWatch

import SwiftUI
import SwiftData

@main
struct WageTickWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ActiveShiftsView()
        }
        .modelContainer(.shared)
    }
}
