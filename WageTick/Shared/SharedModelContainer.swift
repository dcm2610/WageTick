//
//  SharedModelContainer.swift
//  WageTick

import SwiftData
import Foundation

extension ModelContainer {
    static var shared: ModelContainer = {
        let groupID = "group.danielmorgan.WageTick"
        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            storeURL = groupURL.appending(path: "wagetick.sqlite")
            print("✅ [SharedModelContainer] Using App Group store: \(storeURL.path)")
        } else {
            storeURL = URL.applicationSupportDirectory.appending(path: "wagetick.sqlite")
            print("⚠️ [SharedModelContainer] App Group not found, using fallback: \(storeURL.path)")
        }
        let config = ModelConfiguration(url: storeURL)
        do {
            return try ModelContainer(for: Shift.self, configurations: config)
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }()
}
