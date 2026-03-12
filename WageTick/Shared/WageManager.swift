//
//  WageManager.swift
//  WageTick
//
//  Created by Dan Morgan on 11/03/2026.
//

import Foundation
import Observation

@Observable
final class WageManager {
    var shift: Shift
    var earnedSoFar: Decimal = 0
    
    private var displayLink: Timer?
    
    init(shift: Shift) {
        self.shift = shift
        self.earnedSoFar = shift.earnedSoFar()
        startUpdating()
    }
    
    /// Starts the real-time update loop for the wage ticker
    func startUpdating() {
        // Use a Timer to update the earned amount frequently (60 times per second for smooth animation)
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    /// Stops the real-time update loop
    func stopUpdating() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// Updates the earned amount based on the current time
    private func update() {
        let now = Date()
        self.earnedSoFar = shift.earnedSoFar(now: now)
        
        // Stop updating if the shift has ended
        if now >= shift.endTime {
            stopUpdating()
        }
    }
    
    deinit {
        stopUpdating()
    }
}
