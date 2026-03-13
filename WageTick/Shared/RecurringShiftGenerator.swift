//
//  RecurringShiftGenerator.swift
//  WageTick
//

import Foundation
import SwiftData

enum RecurringShiftGenerator {

    /// Number of weekly occurrences to keep ahead of today at all times.
    static let occurrenceCount = 8

    /// How far ahead the last future occurrence must be before we top up.
    /// 2 weeks = extend when fewer than 2 future occurrences remain.
    private static let extensionThreshold: TimeInterval = 14 * 24 * 3600

    // MARK: - Initial generation

    /// Creates `occurrenceCount` Shift records spaced 7 days apart, all sharing
    /// the same `recurringSeriesID`. Inserts them into `context` and schedules
    /// notifications for any future occurrences.
    static func generate(from template: Shift, into context: ModelContext) {
        let seriesID = UUID()
        // Start occurrences from 1 week after the template so the template itself
        // isn't duplicated — the caller inserts the template as occurrence 0.
        guard let firstStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: template.startTime),
              let firstEnd   = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: template.endTime)
        else { return }

        // Tag the template as part of the series too
        template.recurringSeriesID = seriesID
        template.recurringSeriesIndex = 0

        insert(
            seriesID: seriesID,
            from: firstStart,
            endTime: firstEnd,
            wage: template.hourlyWage,
            breakDuration: template.unpaidBreakDuration,
            startingAtIndex: 1,
            count: occurrenceCount,
            into: context
        )
    }

    // MARK: - Auto-extend on launch

    /// Checks all recurring series and extends any that are running low on future occurrences.
    /// Call this once on app launch.
    static func extendIfNeeded(context: ModelContext) {
        let allRecurring = (try? context.fetch(
            FetchDescriptor<Shift>(predicate: #Predicate { $0.recurringSeriesID != nil })
        )) ?? []

        guard !allRecurring.isEmpty else { return }

        let now = Date()
        let threshold = now.addingTimeInterval(extensionThreshold)

        // Group by series ID
        var seriesMap: [UUID: [Shift]] = [:]
        for shift in allRecurring {
            guard let id = shift.recurringSeriesID else { continue }
            seriesMap[id, default: []].append(shift)
        }

        for (_, occurrences) in seriesMap {
            let futureOccurrences = occurrences.filter { $0.startTime > now }

            // Extend if the furthest future shift is within the threshold window
            guard let furthest = futureOccurrences.max(by: { $0.startTime < $1.startTime }),
                  furthest.startTime < threshold else { continue }

            // Use the last shift overall (highest index) as the anchor for extension
            guard let lastShift = occurrences.max(by: {
                ($0.recurringSeriesIndex ?? 0) < ($1.recurringSeriesIndex ?? 0)
            }) else { continue }

            let nextIndex = (lastShift.recurringSeriesIndex ?? 0) + 1
            // Start one week after the last known occurrence
            guard let nextStart = Calendar.current.date(
                byAdding: .weekOfYear, value: 1, to: lastShift.startTime
            ),
            let nextEnd = Calendar.current.date(
                byAdding: .weekOfYear, value: 1, to: lastShift.endTime
            ) else { continue }

            insert(
                seriesID: lastShift.recurringSeriesID!,
                from: nextStart,
                endTime: nextEnd,
                wage: lastShift.hourlyWage,
                breakDuration: lastShift.unpaidBreakDuration,
                startingAtIndex: nextIndex,
                count: occurrenceCount,
                into: context
            )
        }
    }

    // MARK: - Shared insertion helper

    private static func insert(
        seriesID: UUID,
        from firstStart: Date,
        endTime firstEnd: Date,
        wage: Decimal,
        breakDuration: TimeInterval,
        startingAtIndex startIndex: Int,
        count: Int,
        into context: ModelContext
    ) {
        var created: [Shift] = []

        for offset in 0..<count {
            guard let shiftStart = Calendar.current.date(
                byAdding: .weekOfYear, value: offset, to: firstStart
            ),
            let shiftEnd = Calendar.current.date(
                byAdding: .weekOfYear, value: offset, to: firstEnd
            ) else { continue }

            let shift = Shift(
                hourlyWage: wage,
                startTime: shiftStart,
                endTime: shiftEnd,
                unpaidBreakDuration: breakDuration,
                recurringSeriesID: seriesID,
                recurringSeriesIndex: startIndex + offset
            )

            context.insert(shift)
            created.append(shift)
        }

        // Schedule notifications after insertion so persistentModelID is stable
        #if os(iOS)
        for shift in created {
            let id = shift.persistentModelID
            NotificationManager.scheduleShiftStart(
                shiftID: id,
                startTime: shift.startTime,
                hourlyWage: shift.hourlyWage
            )
            NotificationManager.scheduleShiftEnd(shiftID: id, shift: shift)
            // Remind the user to set their department split 2 hours before each recurring shift
            NotificationManager.scheduleDepartmentReminder(shiftID: id, shiftStart: shift.startTime)
        }
        #endif
    }
}
