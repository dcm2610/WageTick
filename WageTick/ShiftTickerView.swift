//
//  ShiftTickerView.swift
//  WageTick
//

import SwiftUI
import SwiftData
import UserNotifications

@Observable
final class ShiftTickerViewModel {
    var currentEarnings: Decimal = 0
    var elapsedSeconds: TimeInterval = 0
    var isCompleted = false
    var breakDeduction: Decimal = 0
    private var timer: Timer?
    private let shift: Shift
    let shiftID: PersistentIdentifier

    init(shift: Shift) {
        self.shift = shift
        self.shiftID = shift.persistentModelID
        self.currentEarnings = shift.earnedSoFar()
        self.elapsedSeconds = shift.elapsedTime()
        self.isCompleted = shift.isCompleted
        if isCompleted {
            self.breakDeduction = shift.breakDeduction()
        }
        startTimer()
    }

    func startTimer() {
        let t = Timer(timeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = Date()
            self.currentEarnings = self.shift.earnedSoFar(now: now)
            self.elapsedSeconds = self.shift.elapsedTime(now: now)
            let completed = self.shift.isCompleted
            if completed && !self.isCompleted {
                self.breakDeduction = self.shift.breakDeduction()
                NotificationManager.sendShiftEnd(
                    shiftID: self.shiftID,
                    earnings: self.currentEarnings,
                    breakDeduction: self.breakDeduction
                )
            }
            self.isCompleted = completed
            if self.isCompleted { self.stopTimer() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopTimer()
    }
}

struct ShiftTickerView: View {
    let shift: Shift
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEditForm = false
    @State private var viewModel: ShiftTickerViewModel?

    var body: some View {
        if let viewModel {
            buildContent(for: viewModel)
        } else {
            Text("Loading...").onAppear {
                viewModel = ShiftTickerViewModel(shift: shift)
            }
        }
    }

    @ViewBuilder
    func buildContent(for viewModel: ShiftTickerViewModel) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    // Rate info — single rate or per-segment breakdown
                    rateCard(for: viewModel)

                    // Earnings ticker
                    VStack(spacing: 12) {
                        Text("Earned So Far").font(.headline).foregroundStyle(.white.opacity(0.7))
                        Text("£\(String(format: "%.4f", NSDecimalNumber(decimal: viewModel.currentEarnings).doubleValue))")
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        // Elapsed time timer
                        Text(formatElapsed(viewModel.elapsedSeconds))
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))

                        if !viewModel.isCompleted {
                            Circle().fill(.white.opacity(0.7)).frame(width: 8, height: 8)
                        }

                        // Persistent break deduction — shown once shift ends with a break
                        if viewModel.breakDeduction > 0 {
                            Text("-£\(String(format: "%.2f", NSDecimalNumber(decimal: viewModel.breakDeduction).doubleValue)) unpaid break")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassEffect(.regular.tint(colorScheme == .dark ? .orange : .teal).interactive(), in: .capsule)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassEffect(.regular.tint(colorScheme == .dark ? .teal : .mint), in: .rect(cornerRadius: 20))

                    // Shift details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Start").foregroundStyle(.secondary)
                            Spacer()
                            Text(shift.startTime.formatted(date: .abbreviated, time: .standard))
                                .font(.system(.body, design: .monospaced))
                        }
                        HStack {
                            Text("End").foregroundStyle(.secondary)
                            Spacer()
                            Text(shift.endTime.formatted(date: .abbreviated, time: .standard))
                                .font(.system(.body, design: .monospaced))
                        }
                        if shift.unpaidBreakDuration > 0 {
                            HStack {
                                Text("Unpaid Break").foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(shift.unpaidBreakDuration / 60))m")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 16))

                    Button(action: { showEditForm = true }) {
                        HStack { Image(systemName: "pencil"); Text("Edit") }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showEditForm) {
            ShiftFormView(shift: shift)
        }
    }

    @ViewBuilder
    private func rateCard(for viewModel: ShiftTickerViewModel) -> some View {
        let sorted = shift.sortedSegments
        if sorted.isEmpty {
            // Single-rate card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hourly Rate").font(.caption).foregroundStyle(.secondary)
                    Text("£\(String(describing: shift.hourlyWage))").font(.title2).fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Per Second").font(.caption).foregroundStyle(.secondary)
                    let ps = shift.hourlyWage / Decimal(3600)
                    Text("£\(String(format: "%.6f", NSDecimalNumber(decimal: ps).doubleValue))").font(.caption)
                }
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
        } else {
            // Per-segment breakdown
            let activeIdx = activeSegmentIndex(elapsed: viewModel.elapsedSeconds, segments: sorted)
            VStack(alignment: .leading, spacing: 8) {
                Text("Department Split").font(.caption).foregroundStyle(.secondary)
                ForEach(Array(sorted.enumerated()), id: \.offset) { idx, seg in
                    let rate = seg.effectiveRate(fallbackWage: shift.hourlyWage)
                    let name = seg.department?.name ?? "Base rate"
                    let isActive = idx == activeIdx && !viewModel.isCompleted
                    let hrs = seg.durationMinutes / 60
                    let mins = seg.durationMinutes % 60
                    let timeStr = hrs > 0 ? (mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h") : "\(mins)m"
                    HStack {
                        if isActive {
                            Circle().fill(.green).frame(width: 7, height: 7)
                        }
                        Text(name).fontWeight(isActive ? .semibold : .regular)
                        Spacer()
                        Text(timeStr).font(.caption).foregroundStyle(.secondary)
                        Text("£\(String(format: "%.2f", NSDecimalNumber(decimal: rate).doubleValue))/hr")
                            .font(.caption)
                            .foregroundStyle(isActive ? .green : .secondary)
                    }
                }
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
        }
    }

    /// Returns the index of the segment currently being worked in based on elapsed time.
    private func activeSegmentIndex(elapsed: TimeInterval, segments: [ShiftSegment]) -> Int {
        var remaining = elapsed
        for (idx, seg) in segments.enumerated() {
            remaining -= seg.durationSeconds
            if remaining <= 0 { return idx }
        }
        return segments.count - 1
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

#Preview {
    ShiftTickerView(shift: Shift(hourlyWage: 15, startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(3600), unpaidBreakDuration: 30 * 60))
        .modelContainer(for: Shift.self, inMemory: true)
}
