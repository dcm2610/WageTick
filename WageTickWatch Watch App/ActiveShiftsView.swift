//
//  ActiveShiftsView.swift
//  WageTickWatch

import SwiftUI
import SwiftData

struct ActiveShiftsView: View {
    @Query(sort: \Shift.startTime, order: .reverse) private var allShifts: [Shift]

    private var activeShifts: [Shift] {
        let now = Date()
        return allShifts.filter { $0.startTime <= now && now < $0.endTime }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeShifts.isEmpty {
                    ContentUnavailableView(
                        "No Active Shifts",
                        systemImage: "clock.badge.xmark",
                        description: Text("Start a shift on your iPhone.")
                    )
                } else {
                    List(activeShifts) { shift in
                        NavigationLink(value: shift) {
                            ShiftRowWatchView(shift: shift)
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("WageTick")
            .navigationDestination(for: Shift.self) { shift in
                ShiftRingView(shift: shift)
            }
        }
    }
}

private struct ShiftRowWatchView: View {
    let shift: Shift

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let earnings = shift.earnedSoFar(now: context.date)
            VStack(alignment: .leading, spacing: 2) {
                Text("£\(shift.hourlyWage, format: .number)/hr")
                    .font(.headline)
                Text("£\(NSDecimalNumber(decimal: earnings).doubleValue, format: .number.precision(.fractionLength(2)))")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}
