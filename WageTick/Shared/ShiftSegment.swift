//
//  ShiftSegment.swift
//  WageTick
//

import Foundation
import SwiftData

@Model
final class ShiftSegment {
    /// The department this segment belongs to. nil = uses the shift's base hourlyWage.
    var department: Department?
    /// Duration of this segment in minutes.
    var durationMinutes: Int
    /// The order of this segment within the shift (0-based).
    var sortOrder: Int
    /// Back-reference to the owning shift.
    var shift: Shift?

    init(department: Department? = nil, durationMinutes: Int, sortOrder: Int = 0) {
        self.department = department
        self.durationMinutes = durationMinutes
        self.sortOrder = sortOrder
    }

    /// Duration in seconds.
    var durationSeconds: TimeInterval {
        TimeInterval(durationMinutes) * 60
    }

    /// Effective hourly rate: department rate or falls back to the shift's base wage.
    func effectiveRate(fallbackWage: Decimal) -> Decimal {
        department?.hourlyRate ?? fallbackWage
    }
}
