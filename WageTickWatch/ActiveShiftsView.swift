//
//  ActiveShiftsView.swift
//  WageTickWatch

import SwiftUI
import SwiftData
import Combine

struct ActiveShiftsView: View {
    @Query(
        filter: #Predicate<Shift> { $0.endTime == nil },
        sort: \Shift.startTime,
        order: .reverse
    ) private var activeShifts: [Shift]

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
    @State private var earnings: Decimal = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("£\(shift.hourlyWage, format: .number)/hr")
                .font(.headline)
            Text("£\(NSDecimalNumber(decimal: earnings).doubleValue, format: .number.precision(.fractionLength(2)))")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .onAppear { earnings = shift.earnedSoFar() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            earnings = shift.earnedSoFar()
        }
    }
}
