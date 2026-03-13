//
//  Department.swift
//  WageTick
//

import Foundation
import SwiftData

@Model
final class Department {
    var name: String
    var hourlyRate: Decimal
    var isActive: Bool
    /// When true, this department's rate is used as the shift's base hourly wage.
    var isBaseRate: Bool

    @Relationship(deleteRule: .nullify, inverse: \ShiftSegment.department)
    var segments: [ShiftSegment] = []

    init(name: String, hourlyRate: Decimal, isActive: Bool = true, isBaseRate: Bool = false) {
        self.name = name
        self.hourlyRate = hourlyRate
        self.isActive = isActive
        self.isBaseRate = isBaseRate
    }
}
