//
//  ShiftRingView.swift
//  WageTickWatch

import SwiftUI
import SwiftData

struct ShiftRingView: View {
    let shift: Shift

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            let earnings = shift.earnedSoFar(now: now)
            let elapsed = shift.elapsedTime(now: now)
            let total = shift.totalShiftDuration()
            let progress: Double = min(total > 0 ? elapsed / total : 0, 1.0)

            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 10)
                    .padding(8)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(8)
                    .animation(.linear(duration: 1), value: progress)

                // Centre content
                VStack(spacing: 4) {
                    Text("£\(NSDecimalNumber(decimal: earnings).doubleValue, format: .number.precision(.fractionLength(2)))")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text("£\(shift.hourlyWage, format: .number)/hr")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Earning")
        .navigationBarTitleDisplayMode(.inline)
    }
}
