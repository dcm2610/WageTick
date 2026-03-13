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
            return try ModelContainer(for: Shift.self, Department.self, ShiftSegment.self, configurations: config)
        } catch {
            // Schema changed — delete the old store and start fresh.
            print("⚠️ [SharedModelContainer] Schema mismatch, resetting store: \(error)")
            let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            for url in [storeURL, shmURL, walURL] {
                try? FileManager.default.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: Shift.self, Department.self, ShiftSegment.self, configurations: config)
            } catch {
                fatalError("Could not create shared ModelContainer after reset: \(error)")
            }
        }
    }()
}
