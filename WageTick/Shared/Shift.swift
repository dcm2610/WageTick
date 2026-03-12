 //
//  Shift.swift
//  WageTick
//
//  Created by Dan Morgan on 11/03/2026.
//

import Foundation
import SwiftData

@Model
final class Shift {
    var hourlyWage: Decimal
    var startTime: Date
    var endTime: Date
    var unpaidBreakDuration: TimeInterval
    /// Non-nil when this shift is part of a weekly recurring series.
    var recurringSeriesID: UUID?
    /// 1-based index within the series (1 = first occurrence).
    var recurringSeriesIndex: Int?

    init(
        hourlyWage: Decimal,
        startTime: Date,
        endTime: Date,
        unpaidBreakDuration: TimeInterval = 0,
        recurringSeriesID: UUID? = nil,
        recurringSeriesIndex: Int? = nil
    ) {
        self.hourlyWage = hourlyWage
        self.startTime = startTime
        self.endTime = endTime
        self.unpaidBreakDuration = unpaidBreakDuration
        self.recurringSeriesID = recurringSeriesID
        self.recurringSeriesIndex = recurringSeriesIndex
    }

    /// Total duration from start to end.
    func totalShiftDuration() -> TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Total pay for the entire shift (accounting for unpaid breaks).
    func totalShiftPay() -> Decimal {
        let shiftHours = Decimal(totalShiftDuration()) / Decimal(3600)
        let unpaidBreakHours = Decimal(unpaidBreakDuration) / Decimal(3600)
        let paidHours = shiftHours - unpaidBreakHours
        return paidHours * hourlyWage
    }

    /// Elapsed time since start, clamped to [0, totalDuration].
    /// Returns 0 if the shift hasn't started yet.
    func elapsedTime(now: Date = Date()) -> TimeInterval {
        guard now >= startTime else { return 0 }
        let effectiveEnd = min(now, endTime)
        return effectiveEnd.timeIntervalSince(startTime)
    }

    /// Earnings accrued so far, ticking at a rate that accounts for the break
    /// so the final value is correct with no jump at end time.
    /// Returns 0 if the shift hasn't started yet.
    func earnedSoFar(now: Date = Date()) -> Decimal {
        guard now >= startTime else { return 0 }
        let total = Decimal(totalShiftDuration())
        guard total > 0 else { return 0 }
        let elapsed = Decimal(elapsedTime(now: now))
        let unpaidBreakSeconds = Decimal(unpaidBreakDuration)
        let paidFraction = max(total - unpaidBreakSeconds, 0) / total
        let elapsedHours = elapsed / Decimal(3600)
        return elapsedHours * hourlyWage * paidFraction
    }

    /// The break deduction amount.
    func breakDeduction() -> Decimal {
        let unpaidBreakHours = Decimal(unpaidBreakDuration) / Decimal(3600)
        return unpaidBreakHours * hourlyWage
    }

    var isCompleted: Bool { Date() >= endTime }
    var isScheduled: Bool { Date() < startTime }
    var isOngoing: Bool { !isScheduled && !isCompleted }
}
