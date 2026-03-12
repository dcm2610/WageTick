//
//  ShiftFormView.swift
//  WageTick
//

import SwiftUI
import SwiftData
import UserNotifications

struct ShiftFormView: View {
    @Bindable var shift: Shift
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        Text("£").foregroundStyle(.secondary)
                        TextField("0.00", value: $shift.hourlyWage, format: .number)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Hourly Rate")
                }

                Section("Times") {
                    DatePicker("Start", selection: $shift.startTime, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: shift.startTime) { _, newStart in
                            NotificationManager.cancelShiftStart(shiftID: shift.persistentModelID)
                            NotificationManager.scheduleShiftStart(
                                shiftID: shift.persistentModelID,
                                startTime: newStart,
                                hourlyWage: shift.hourlyWage
                            )
                        }
                    DatePicker("End", selection: $shift.endTime, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: shift.endTime) { _, _ in rescheduleEndNotification() }
                }

                Section {
                    Picker("Duration", selection: Binding(
                        get: { Int(shift.unpaidBreakDuration / 60) },
                        set: {
                            shift.unpaidBreakDuration = TimeInterval($0 * 60)
                            rescheduleEndNotification()
                        }
                    )) {
                        ForEach([0, 15, 30, 45, 60, 90, 120], id: \.self) {
                            Text($0 == 0 ? "None" : "\($0) min").tag($0)
                        }
                    }
                } header: {
                    Text("Unpaid Break")
                }
            }
            .navigationTitle("Edit Shift")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            #endif
        }
    }

    private func rescheduleEndNotification() {
        let id = shift.persistentModelID
        NotificationManager.cancelShiftEnd(shiftID: id)
        NotificationManager.scheduleShiftEnd(shiftID: id, shift: shift)
    }
}
