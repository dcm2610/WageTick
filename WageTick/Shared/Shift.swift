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

    /// Department segments. Empty = single-rate shift using hourlyWage.
    @Relationship(deleteRule: .cascade, inverse: \ShiftSegment.shift)
    var segments: [ShiftSegment] = []

    /// Which segment index (0-based, matching sortOrder) absorbs the unpaid break deduction.
    /// nil if no segments, or not yet assigned.
    var breakSegmentIndex: Int?

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

    /// Segments sorted by their sortOrder, ascending.
    var sortedSegments: [ShiftSegment] {
        segments.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Total pay for the entire shift (accounting for unpaid breaks).
    func totalShiftPay() -> Decimal {
        let sorted = sortedSegments
        guard !sorted.isEmpty else {
            // No segments: single-rate calculation
            let shiftHours = Decimal(totalShiftDuration()) / Decimal(3600)
            let unpaidBreakHours = Decimal(unpaidBreakDuration) / Decimal(3600)
            return (shiftHours - unpaidBreakHours) * hourlyWage
        }

        // Multi-segment: sum each segment's pay, deducting break from the chosen segment
        var total = Decimal(0)
        for (index, segment) in sorted.enumerated() {
            let rate = segment.effectiveRate(fallbackWage: hourlyWage)
            let hours = Decimal(segment.durationMinutes) / Decimal(60)
            var segmentPay = hours * rate

            // Deduct unpaid break from the designated segment
            if index == breakSegmentIndex, unpaidBreakDuration > 0 {
                let breakHours = Decimal(unpaidBreakDuration) / Decimal(3600)
                segmentPay -= breakHours * rate
            }

            total += segmentPay
        }
        return total
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
        let sorted = sortedSegments

        guard !sorted.isEmpty else {
            // No segments: single-rate with break-aware paidFraction
            let total = Decimal(totalShiftDuration())
            guard total > 0 else { return 0 }
            let elapsed = Decimal(elapsedTime(now: now))
            let unpaidBreakSeconds = Decimal(unpaidBreakDuration)
            let paidFraction = max(total - unpaidBreakSeconds, 0) / total
            return (elapsed / Decimal(3600)) * hourlyWage * paidFraction
        }

        // Multi-segment: walk through segments in timeline order
        let elapsed = elapsedTime(now: now)
        var remaining = elapsed
        var earned = Decimal(0)

        for (index, segment) in sorted.enumerated() {
            let segDuration = segment.durationSeconds
            let rate = segment.effectiveRate(fallbackWage: hourlyWage)

            if remaining <= 0 { break }

            let timeInSegment = min(remaining, segDuration)
            remaining -= timeInSegment

            // Fraction of this segment completed
            var segHours = Decimal(timeInSegment) / Decimal(3600)

            // Apply break deduction to the designated segment using paidFraction trick
            if index == breakSegmentIndex, unpaidBreakDuration > 0, segDuration > 0 {
                let breakSeconds = Decimal(unpaidBreakDuration)
                let segSeconds = Decimal(segDuration)
                let paidFraction = max(segSeconds - breakSeconds, 0) / segSeconds
                segHours = segHours * paidFraction
            }

            earned += segHours * rate
        }

        return earned
    }

    /// The break deduction amount.
    func breakDeduction() -> Decimal {
        let sorted = sortedSegments
        guard !sorted.isEmpty, let idx = breakSegmentIndex, idx < sorted.count else {
            // No segments or no break segment assigned: fall back to base rate
            let unpaidBreakHours = Decimal(unpaidBreakDuration) / Decimal(3600)
            return unpaidBreakHours * hourlyWage
        }
        let rate = sorted[idx].effectiveRate(fallbackWage: hourlyWage)
        let unpaidBreakHours = Decimal(unpaidBreakDuration) / Decimal(3600)
        return unpaidBreakHours * rate
    }

    var isCompleted: Bool { Date() >= endTime }
    var isScheduled: Bool { Date() < startTime }
    var isOngoing: Bool { !isScheduled && !isCompleted }

    /// True when segments exist but no break segment has been assigned and there's an unpaid break.
    var needsBreakSegmentAssignment: Bool {
        !segments.isEmpty && unpaidBreakDuration > 0 && breakSegmentIndex == nil
    }

    /// True when the shift is part of a recurring series and has no segments set.
    var needsDepartmentSegments: Bool {
        recurringSeriesID != nil && segments.isEmpty
    }
}
