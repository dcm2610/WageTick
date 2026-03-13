//
//  ShiftFormView.swift
//  WageTick
//

import SwiftUI
import SwiftData
import UserNotifications

struct ShiftFormView: View {
    @Bindable var shift: Shift
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var segmentsEnabled: Bool = false
    @State private var draftSegments: [DraftSegment] = []
    @State private var breakSegmentIndex: Int? = nil

    private var totalShiftMinutes: Int {
        max(0, Int(shift.endTime.timeIntervalSince(shift.startTime) / 60))
    }

    private var segmentsValid: Bool {
        guard segmentsEnabled && !draftSegments.isEmpty else { return true }
        let allocated = draftSegments.reduce(0) { $0 + $1.durationMinutes }
        return allocated == totalShiftMinutes
    }

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
                } footer: {
                    if segmentsEnabled {
                        Text("Used as the fallback rate for segments not assigned to a department.")
                    }
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

                SegmentEditorView(
                    isEnabled: $segmentsEnabled,
                    drafts: $draftSegments,
                    breakSegmentIndex: $breakSegmentIndex,
                    totalShiftMinutes: totalShiftMinutes,
                    hasBreak: shift.unpaidBreakDuration > 0
                )
            }
            .navigationTitle("Edit Shift")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applySegments()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!segmentsValid)
                }
            }
            #endif
            .onAppear(perform: loadExistingSegments)
        }
    }

    private func loadExistingSegments() {
        let sorted = shift.sortedSegments
        guard !sorted.isEmpty else { return }
        segmentsEnabled = true
        breakSegmentIndex = shift.breakSegmentIndex
        draftSegments = sorted.map { seg in
            DraftSegment(departmentID: seg.department?.persistentModelID, durationMinutes: seg.durationMinutes)
        }
    }

    private func applySegments() {
        // Remove all existing segments
        for seg in shift.segments {
            modelContext.delete(seg)
        }

        if segmentsEnabled && !draftSegments.isEmpty {
            shift.breakSegmentIndex = breakSegmentIndex
            for (idx, draft) in draftSegments.enumerated() {
                let segment = ShiftSegment(durationMinutes: draft.durationMinutes, sortOrder: idx)
                modelContext.insert(segment)
                segment.shift = shift
                if let deptID = draft.departmentID {
                    segment.department = resolveDepartment(id: deptID)
                }
            }
        } else {
            shift.breakSegmentIndex = nil
        }
    }

    private func resolveDepartment(id: PersistentIdentifier) -> Department? {
        modelContext.model(for: id) as? Department
    }

    private func rescheduleEndNotification() {
        let id = shift.persistentModelID
        NotificationManager.cancelShiftEnd(shiftID: id)
        NotificationManager.scheduleShiftEnd(shiftID: id, shift: shift)
    }
}
