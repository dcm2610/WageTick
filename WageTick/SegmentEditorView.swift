//
//  SegmentEditorView.swift
//  WageTick
//

import SwiftUI
import SwiftData

/// A transient model used while editing segments before committing to SwiftData.
struct DraftSegment: Identifiable {
    let id: UUID = UUID()
    var departmentID: PersistentIdentifier?
    var durationMinutes: Int
}

/// A sheet presenting a countdown-style DatePicker for picking a duration.
private struct DurationPickerSheet: View {
    @Binding var durationMinutes: Int
    @Environment(\.dismiss) private var dismiss

    // DatePicker works with TimeInterval (seconds)
    @State private var interval: TimeInterval

    init(durationMinutes: Binding<Int>) {
        _durationMinutes = durationMinutes
        _interval = State(initialValue: TimeInterval(durationMinutes.wrappedValue * 60))
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                "Duration",
                selection: Binding(
                    get: { Date(timeIntervalSinceReferenceDate: interval) },
                    set: { interval = $0.timeIntervalSinceReferenceDate }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .navigationTitle("Set Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Convert back to minutes, minimum 15
                        let minutes = max(15, Int(interval / 60))
                        durationMinutes = minutes
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

/// Embeddable view for adding/editing department segments within a shift form.
/// Manages its own draft state; caller provides binding to segments + breakSegmentIndex.
struct SegmentEditorView: View {
    @Query(sort: \Department.name) private var allDepartments: [Department]

    /// Whether department splitting is enabled.
    @Binding var isEnabled: Bool
    /// Draft segments being edited (caller owns and commits these).
    @Binding var drafts: [DraftSegment]
    /// Index into drafts for which segment absorbs the break.
    @Binding var breakSegmentIndex: Int?
    /// Total shift duration in minutes (used to show allocation warning).
    let totalShiftMinutes: Int
    /// Whether the shift has an unpaid break (to show the break-segment picker).
    let hasBreak: Bool

    @State private var durationPickerIndex: Int? = nil

    private var activeDepartments: [Department] {
        allDepartments.filter { $0.isActive }
    }

    private var allocatedMinutes: Int {
        drafts.reduce(0) { $0 + $1.durationMinutes }
    }

    private var isFullyAllocated: Bool {
        allocatedMinutes == totalShiftMinutes
    }

    var body: some View {
        Section {
            Toggle("Split by department", isOn: $isEnabled.animation(.easeInOut(duration: 0.25)))
        } header: {
            Text("Department Split")
        } footer: {
            if isEnabled {
                allocationFooter
            }
        }

        if isEnabled {
            if activeDepartments.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("No departments set up. Add one in Settings → Departments.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                segmentRows

                if hasBreak && drafts.count > 1 {
                    breakSegmentPicker
                }
            }
        }
    }

    @ViewBuilder
    private var segmentRows: some View {
        Section {
            ForEach(drafts.indices, id: \.self) { idx in
                segmentRow(index: idx)
            }
            .onDelete { indexSet in
                drafts.remove(atOffsets: indexSet)
                // Adjust breakSegmentIndex if necessary
                if let bsi = breakSegmentIndex {
                    if indexSet.contains(bsi) {
                        breakSegmentIndex = nil
                    } else {
                        let deletedBelow = indexSet.filter { $0 < bsi }.count
                        breakSegmentIndex = bsi - deletedBelow
                    }
                }
            }

            Button {
                drafts.append(DraftSegment(departmentID: nil, durationMinutes: 60))
            } label: {
                Label("Add Segment", systemImage: "plus.circle.fill")
            }
        } header: {
            if !drafts.isEmpty {
                Text("Segments")
            }
        }
    }

    @ViewBuilder
    private func segmentRow(index: Int) -> some View {
        // Department picker row
        Picker("Department", selection: Binding(
            get: { drafts[index].departmentID },
            set: { drafts[index].departmentID = $0 }
        )) {
            Text("Base rate").tag(Optional<PersistentIdentifier>.none)
            ForEach(activeDepartments) { dept in
                Text("\(dept.name) (£\(String(format: "%.2f", NSDecimalNumber(decimal: dept.hourlyRate).doubleValue))/hr)")
                    .tag(Optional(dept.persistentModelID))
            }
        }

        // Duration row — tap to open picker sheet
        Button {
            durationPickerIndex = index
        } label: {
            HStack {
                Text("Duration")
                    .foregroundStyle(.primary)
                Spacer()
                Text(formatMinutes(drafts[index].durationMinutes))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: Binding(
            get: { durationPickerIndex == index },
            set: { if !$0 { durationPickerIndex = nil } }
        )) {
            DurationPickerSheet(durationMinutes: $drafts[index].durationMinutes)
        }
    }

    @ViewBuilder
    private var breakSegmentPicker: some View {
        Section {
            Picker("Deduct break from", selection: Binding(
                get: { breakSegmentIndex ?? 0 },
                set: { breakSegmentIndex = $0 }
            )) {
                ForEach(drafts.indices, id: \.self) { idx in
                    let label = departmentName(for: drafts[idx].departmentID) ?? "Base rate"
                    Text("Segment \(idx + 1): \(label)").tag(idx)
                }
            }
        } header: {
            Text("Break Deduction")
        } footer: {
            Text("Choose which department's pay rate is used to calculate the unpaid break deduction.")
        }
    }

    @ViewBuilder
    private var allocationFooter: some View {
        let diff = allocatedMinutes - totalShiftMinutes
        if diff == 0 {
            Text("✓ All \(formatMinutes(totalShiftMinutes)) allocated.")
                .foregroundStyle(.green)
        } else if diff > 0 {
            Text("Over by \(formatMinutes(diff)). Total shift is \(formatMinutes(totalShiftMinutes)).")
                .foregroundStyle(.orange)
        } else {
            Text("\(formatMinutes(-diff)) unallocated of \(formatMinutes(totalShiftMinutes)) total.")
                .foregroundStyle(.orange)
        }
    }

    private func departmentName(for id: PersistentIdentifier?) -> String? {
        guard let id else { return nil }
        return allDepartments.first { $0.persistentModelID == id }?.name
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
