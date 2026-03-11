//
//  ShiftTickerView.swift
//  WageTick
//

import SwiftUI
import SwiftData

@Observable
final class ShiftTickerViewModel {
    var currentEarnings: Decimal = 0
    var isCompleted = false
    private var timer: Timer?
    private let shift: Shift

    init(shift: Shift) {
        self.shift = shift
        self.currentEarnings = shift.earnedSoFar()
        self.isCompleted = shift.endTime.map { Date() >= $0 } ?? false
        startTimer()
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = Date()
            self.currentEarnings = self.shift.earnedSoFar(now: now)
            self.isCompleted = self.shift.endTime.map { now >= $0 } ?? false
            if self.isCompleted { self.stopTimer() }
        }
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
    @State private var showEditForm = false
    @State private var viewModel: ShiftTickerViewModel?

    // End shift flow
    @State private var showEndShiftOptions = false   // step 1 (only for shifts with planned end time)
    @State private var showBreakOptions = false      // step 2
    @State private var pendingEndTime: Date? = nil   // captured at the moment user taps End Shift
    @State private var editingBreakMinutes: Int = 0  // used in "Edit break time" option

    // Break deduction animation
    @State private var breakDeductionAmount: Decimal = 0
    @State private var showBreakDeduction = false

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
        VStack(spacing: 20) {
            // Rate info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hourly Rate").font(.caption).foregroundColor(.secondary)
                        Text("£\(String(describing: shift.hourlyWage))").font(.title2).fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Per Second").font(.caption).foregroundColor(.secondary)
                        let ps = shift.hourlyWage / Decimal(3600)
                        Text("£\(String(format: "%.6f", NSDecimalNumber(decimal: ps).doubleValue))").font(.caption)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            // Earnings ticker with break deduction overlay
            ZStack(alignment: .bottom) {
                VStack(spacing: 12) {
                    Text("Earned So Far").font(.headline).foregroundColor(.secondary)
                    Text("£\(String(format: "%.4f", NSDecimalNumber(decimal: viewModel.currentEarnings).doubleValue))")
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    if !viewModel.isCompleted {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding()

                if showBreakDeduction {
                    Text("-£\(String(format: "%.2f", NSDecimalNumber(decimal: breakDeductionAmount).doubleValue)) unpaid break")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(8)
                        .padding(.bottom, 24)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }

            // Shift details
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Start").foregroundColor(.secondary)
                    Spacer()
                    Text(shift.startTime.formatted(date: .abbreviated, time: .standard))
                        .font(.system(.body, design: .monospaced))
                }
                HStack {
                    Text("End").foregroundColor(.secondary)
                    Spacer()
                    Text(shift.endTime?.formatted(date: .abbreviated, time: .standard) ?? "Ongoing")
                        .font(.system(.body, design: .monospaced))
                }
                if shift.unpaidBreakDuration > 0 {
                    HStack {
                        Text("Unpaid Break").foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(shift.unpaidBreakDuration / 60))m")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)

            // End Shift button (ongoing only)
            if !viewModel.isCompleted {
                Button(action: onEndShiftTapped) {
                    HStack { Image(systemName: "stop.circle"); Text("End Shift") }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }

            Button(action: { showEditForm = true }) {
                HStack { Image(systemName: "pencil"); Text("Edit") }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .sheet(isPresented: $showEditForm) {
            ShiftFormView(shift: shift)
        }
        // Step 1: only shown when shift has a future planned end time
        .sheet(isPresented: $showEndShiftOptions) {
            EndShiftOptionsView(
                onFullPlannedPay: {
                    showEndShiftOptions = false
                    // Leave endTime as-is; the ticker will stop naturally when time is reached.
                    // To stop it immediately, set endTime to its existing value to trigger isCompleted.
                    // We mark as complete by leaving endTime unchanged — the ticker already handles it.
                    // Animate deduction since the planned pay includes the break deduction.
                    animateBreakDeduction()
                },
                onPayForTimeWorked: {
                    showEndShiftOptions = false
                    editingBreakMinutes = Int(shift.unpaidBreakDuration / 60)
                    showBreakOptions = true
                }
            )
        }
        // Step 2: break options
        .sheet(isPresented: $showBreakOptions) {
            BreakOptionsView(
                hoursWorked: hoursWorkedDescription(),
                breakMinutes: $editingBreakMinutes,
                onIncludeBreak: {
                    showBreakOptions = false
                    shift.unpaidBreakDuration = TimeInterval(editingBreakMinutes * 60)
                    commitEnd(animateDeduction: shift.unpaidBreakDuration > 0)
                },
                onNoBreak: {
                    showBreakOptions = false
                    shift.unpaidBreakDuration = 0
                    commitEnd(animateDeduction: false)
                }
            )
        }
    }

    // MARK: - Actions

    private func onEndShiftTapped() {
        pendingEndTime = Date()
        editingBreakMinutes = Int(shift.unpaidBreakDuration / 60)

        // If the shift has a future planned end time, show step 1
        if let end = shift.endTime, end > Date() {
            showEndShiftOptions = true
        } else {
            // No planned end time — go straight to step 2
            showBreakOptions = true
        }
    }

    /// Commits the shift end using the captured pendingEndTime
    private func commitEnd(animateDeduction: Bool) {
        shift.endTime = pendingEndTime ?? Date()
        if animateDeduction {
            animateBreakDeduction()
        }
    }

    private func animateBreakDeduction() {
        let deduction = shift.breakDeduction()
        guard deduction > 0 else { return }
        breakDeductionAmount = deduction
        withAnimation(.spring()) {
            showBreakDeduction = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showBreakDeduction = false
            }
        }
    }

    private func hoursWorkedDescription() -> String {
        let elapsed = pendingEndTime.map { $0.timeIntervalSince(shift.startTime) } ?? shift.elapsedTime()
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Step 1: End shift options (only shown when a planned end time exists)

struct EndShiftOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    let onFullPlannedPay: () -> Void
    let onPayForTimeWorked: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("You're ending this shift before its planned end time. How should we calculate your pay?")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                Section {
                    Button(action: onFullPlannedPay) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Full planned pay").fontWeight(.semibold)
                            Text("Calculate pay for the full shift as planned, with break deducted.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    Button(action: onPayForTimeWorked) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pay for time worked").fontWeight(.semibold)
                            Text("Calculate pay based on actual time worked up to now.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("End Shift Early")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Step 2: Break options

struct BreakOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    let hoursWorked: String
    @Binding var breakMinutes: Int
    let onIncludeBreak: () -> Void
    let onNoBreak: () -> Void

    @State private var showBreakPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("You worked \(hoursWorked). How should we handle the unpaid break?")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                Section {
                    Button(action: onIncludeBreak) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include break deduction").fontWeight(.semibold)
                            Text("Deduct \(breakMinutes)m unpaid break from your pay.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if showBreakPicker {
                        Picker("Break duration", selection: $breakMinutes) {
                            ForEach([0, 5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { min in
                                Text(min == 0 ? "None" : "\(min)m").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        Button(action: onIncludeBreak) {
                            Text("Confirm")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Button(action: { showBreakPicker = true }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Edit break time").fontWeight(.semibold)
                                Text("Adjust the break duration before deducting.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button(action: onNoBreak) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No break deduction").fontWeight(.semibold)
                            Text("Pay for all time worked with no break deducted.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Unpaid Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ShiftTickerView(shift: Shift(hourlyWage: 15, startTime: Date().addingTimeInterval(-3600), unpaidBreakDuration: 30 * 60))
        .modelContainer(for: Shift.self, inMemory: true)
}
