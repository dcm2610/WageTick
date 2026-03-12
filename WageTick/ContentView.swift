
//
//  ContentView.swift
//  WageTick
//

import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"

    var body: some View {
        TabView {
            Tab("Shifts", systemImage: "clock") {
                ShiftsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .preferredColorScheme(colorScheme(for: appTheme))
    }

    private func colorScheme(for theme: String) -> ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

struct ShiftsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shift.startTime, order: .reverse) private var shifts: [Shift]
    @State private var showNewShiftForm = false
    @State private var selectedShift: Shift?
    @State private var editMode: EditMode = .inactive
    @State private var showMoreScheduled = false
    @State private var showMoreCompleted = false

    private let pageSize = 3

    private var now: Date { Date() }

    private var scheduledShifts: [Shift] {
        let upcoming = shifts.filter { $0.isScheduled || $0.isOngoing }
            .sorted { $0.startTime < $1.startTime }

        // For recurring series, show only the next occurrence (soonest startTime).
        // Non-recurring shifts pass through as-is.
        var seenSeriesIDs = Set<UUID>()
        return upcoming.filter { shift in
            guard let seriesID = shift.recurringSeriesID else { return true }
            return seenSeriesIDs.insert(seriesID).inserted
        }
    }
    private var completedShifts: [Shift] {
        shifts.filter { $0.isCompleted }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedShift) {
                if shifts.isEmpty {
                    Text("No shifts").foregroundColor(.secondary)
                } else {
                    shiftSection(title: "Upcoming & Ongoing", shifts: scheduledShifts, showMore: $showMoreScheduled)
                    shiftSection(title: "Completed", shifts: completedShifts, showMore: $showMoreCompleted)
                }
            }
            .navigationTitle("Shifts")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewShiftForm = true }) { Image(systemName: "plus") }
                }
            }
            #endif
            .environment(\.editMode, $editMode)
            .onChange(of: shifts.isEmpty) { _, isEmpty in
                if isEmpty { editMode = .inactive }
            }
            .sheet(isPresented: $showNewShiftForm) {
                NewShiftFormView(isPresented: $showNewShiftForm)
            }

        } detail: {
            if let shift = selectedShift {
                ShiftTickerView(shift: shift).navigationTitle("Active Shift")
            } else {
                Text("Select a shift").foregroundColor(.secondary)
            }
        }
    }

    private func deleteShift(_ shift: Shift) {
        NotificationManager.cancelShiftStart(shiftID: shift.persistentModelID)
        NotificationManager.cancelShiftEnd(shiftID: shift.persistentModelID)
        modelContext.delete(shift)
    }

    private func deleteEntireSeries(seriesID: UUID?) {
        guard let seriesID else { return }
        let matching = shifts.filter { $0.recurringSeriesID == seriesID }
        for shift in matching {
            NotificationManager.cancelShiftStart(shiftID: shift.persistentModelID)
            NotificationManager.cancelShiftEnd(shiftID: shift.persistentModelID)
            modelContext.delete(shift)
        }
    }

    @ViewBuilder
    private func shiftSection(title: String, shifts: [Shift], showMore: Binding<Bool>) -> some View {
        if !shifts.isEmpty {
            Section(title) {
                let visible = showMore.wrappedValue ? shifts : Array(shifts.prefix(pageSize))
                ForEach(visible) { shift in
                    ShiftRowWithDelete(
                        shift: shift,
                        allShifts: self.shifts,
                        onDelete: deleteShift,
                        onDeleteSeries: deleteEntireSeries
                    )
                }
                if shifts.count > pageSize {
                    Button(showMore.wrappedValue ? "Show Less" : "Show More (\(shifts.count - pageSize) more)") {
                        withAnimation { showMore.wrappedValue.toggle() }
                    }
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shifts: [Shift]
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage(NotificationManager.enabledKey) private var notificationsEnabled: Bool = false
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Text("System Default").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                NotificationManager.requestPermission { granted in
                                    if !granted {
                                        notificationsEnabled = false
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                            } else {
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Sends a notification when a scheduled shift starts and when a shift ends with your earnings summary.")
                }

                Section {
                    Button("Reset App", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .confirmationDialog("Reset App", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                        Button("Delete All Shifts", role: .destructive) {
                            for shift in shifts {
                                modelContext.delete(shift)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all your shifts. This cannot be undone.")
                    }
                } footer: {
                    Text("Deletes all shifts permanently.")
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: syncNotificationStatus)
        }
    }

    private func syncNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let systemGranted = settings.authorizationStatus == .authorized
                if notificationsEnabled && !systemGranted {
                    notificationsEnabled = false
                }
            }
        }
    }
}

struct NewShiftFormView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var hourlyWage = Decimal(15)
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(8 * 3600)
    @State private var unpaidBreakDuration = TimeInterval(0)
    @State private var isRecurring = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        Text("£").foregroundStyle(.secondary)
                        TextField("0.00", value: $hourlyWage, format: .number)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Hourly Rate")
                }

                Section("Times") {
                    DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Picker("Duration", selection: Binding(
                        get: { Int(unpaidBreakDuration / 60) },
                        set: { unpaidBreakDuration = TimeInterval($0 * 60) }
                    )) {
                        ForEach([0, 15, 30, 45, 60, 90, 120], id: \.self) {
                            Text($0 == 0 ? "None" : "\($0) min").tag($0)
                        }
                    }
                } header: {
                    Text("Unpaid Break")
                }

                Section {
                    Toggle("Repeat weekly", isOn: $isRecurring)
                } header: {
                    Text("Recurrence")
                } footer: {
                    if isRecurring {
                        Text("Schedules \(RecurringShiftGenerator.occurrenceCount) weekly occurrences. Each can be deleted individually.")
                    }
                }
            }
            .navigationTitle("New Shift")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add", action: createShift)
                        .fontWeight(.semibold)
                }
            }
            #endif
        }
    }

    private func createShift() {
        let template = Shift(hourlyWage: hourlyWage, startTime: startTime, endTime: endTime, unpaidBreakDuration: unpaidBreakDuration)
        if isRecurring {
            RecurringShiftGenerator.generate(from: template, into: modelContext)
        } else {
            modelContext.insert(template)
            let id = template.persistentModelID
            NotificationManager.scheduleShiftStart(shiftID: id, startTime: startTime, hourlyWage: hourlyWage)
            NotificationManager.scheduleShiftEnd(shiftID: id, shift: template)
        }
        isPresented = false
    }
}

struct ShiftRowView: View {
    let shift: Shift

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            let earnings = shift.earnedSoFar(now: now)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("£\(String(describing: shift.hourlyWage))/hr").font(.headline)
                    Spacer()
                    Text("£\(String(format: "%.2f", NSDecimalNumber(decimal: earnings).doubleValue))").foregroundColor(.green)
                }
                HStack {
                    Text(shift.startTime.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary)
                    if shift.recurringSeriesID != nil {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Repeats weekly")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    let statusLabel = shift.isScheduled ? "Scheduled" : shift.isCompleted ? "Completed" : "Ongoing"
                    Text(statusLabel).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct ShiftRowWithDelete: View {
    let shift: Shift
    let allShifts: [Shift]
    let onDelete: (Shift) -> Void
    let onDeleteSeries: (UUID?) -> Void
    @State private var showConfirmation = false
    @State private var slideOffset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        NavigationLink(value: shift) {
            ShiftRowView(shift: shift)
        }
        .offset(x: slideOffset)
        .opacity(opacity)
        .swipeActions {
            if shift.recurringSeriesID != nil {
                Button {
                    showConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            } else {
                Button(role: .destructive) {
                    animateThenDelete { onDelete(shift) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete Recurring Shift",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete This Shift Only", role: .destructive) {
                animateThenDelete { onDelete(shift) }
            }
            Button("Delete All Shifts in Series", role: .destructive) {
                animateThenDelete { onDeleteSeries(shift.recurringSeriesID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is part of a weekly recurring series. Do you want to delete just this shift, or remove the entire series?")
        }
    }

    private func animateThenDelete(action: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.25)) {
            slideOffset = -400
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            action()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Shift.self, configurations: config)
    return ShiftsView().modelContainer(container)
}
