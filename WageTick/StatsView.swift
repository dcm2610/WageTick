//
//  StatsView.swift
//  WageTick
//

import SwiftUI
import SwiftData
import StoreKit
import Charts

struct StatsView: View {
    @Query private var shifts: [Shift]
    @Query(sort: \Department.name) private var departments: [Department]
    @Environment(StoreManager.self) private var store
    @AppStorage("weekStartDay") private var weekStartDay: Int = 2 // 1=Sun, 2=Mon

    private var completedShifts: [Shift] {
        shifts.filter { $0.isCompleted }
    }

    private var totalEarned: Decimal {
        completedShifts.reduce(0) { $0 + $1.totalShiftPay() }
    }

    private var totalSeconds: Double {
        completedShifts.reduce(0.0) { $0 + $1.totalShiftDuration() }
    }

    private var totalHoursWorked: Double { totalSeconds / 3600 }

    private var totalBreakDeducted: Decimal {
        completedShifts.reduce(0) { $0 + $1.breakDeduction() }
    }

    private var averageShiftLength: Double {
        guard !completedShifts.isEmpty else { return 0 }
        return totalHoursWorked / Double(completedShifts.count)
    }

    private var averageEarningsPerShift: Decimal {
        guard !completedShifts.isEmpty else { return 0 }
        return totalEarned / Decimal(completedShifts.count)
    }

    private var bestShift: Shift? {
        completedShifts.max { $0.totalShiftPay() < $1.totalShiftPay() }
    }

    private var earningsThisWeek: Decimal {
        let start = Calendar.current.startOfWeek(firstWeekday: weekStartDay)
        return completedShifts
            .filter { $0.startTime >= start }
            .reduce(0) { $0 + $1.totalShiftPay() }
    }

    private var earningsThisMonth: Decimal {
        let start = Calendar.current.startOfMonth()
        return completedShifts
            .filter { $0.startTime >= start }
            .reduce(0) { $0 + $1.totalShiftPay() }
    }

    struct DayEarning: Identifiable {
        let id: Date
        let label: String
        let earnings: Double
        let isToday: Bool
    }

    private var weeklyDailyEarnings: [DayEarning] {
        var cal = Calendar.current
        cal.firstWeekday = weekStartDay
        let today = cal.startOfDay(for: Date())
        // Find start of current week
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let nextDay = cal.date(byAdding: .day, value: 1, to: day) ?? day
            let earned = completedShifts
                .filter { $0.startTime >= day && $0.startTime < nextDay }
                .reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.totalShiftPay()).doubleValue }
            return DayEarning(
                id: day,
                label: formatter.string(from: day),
                earnings: earned,
                isToday: cal.isDate(day, inSameDayAs: today)
            )
        }
    }

    var body: some View {
        NavigationStack {
            if completedShifts.isEmpty {
                ContentUnavailableView(
                    "No Stats Yet",
                    systemImage: "chart.bar.fill",
                    description: Text("Complete a shift to see your statistics.")
                )
                .navigationTitle("Stats")
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        VStack(spacing: 16) {

                            // Hero — total earned (always free)
                            VStack(spacing: 6) {
                                Text("Total Earned")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("£\(format(totalEarned))")
                                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("\(completedShifts.count) shifts completed")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .padding(.horizontal)
                            .glassEffect(.regular.tint(.green), in: .rect(cornerRadius: 20))

                            // This week / this month (always free)
                            HStack(spacing: 16) {
                                PeriodCard(title: "This Week", value: "£\(format(earningsThisWeek))", icon: "calendar")
                                PeriodCard(title: "This Month", value: "£\(format(earningsThisMonth))", icon: "calendar.badge.clock")
                            }

                            // Weekly earnings chart + hours worked (always free)
                            WeeklyEarningsCard(
                                dailyEarnings: weeklyDailyEarnings,
                                totalHours: totalHoursWorked
                            )

                            // Premium section
                            if store.isUnlocked {
                                premiumStats
                            } else {
                                PremiumUpsellCard()
                                #if DEBUG
                                Button("DEBUG: Force Unlock") {
                                    store.debugUnlock()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                #endif
                            }
                        }
                        .padding()
                    }
                }
                .navigationTitle("Stats")
            }
        }
    }

    // MARK: - Premium stats

    @ViewBuilder
    private var premiumStats: some View {
        // Averages row
        HStack(spacing: 16) {
            StatCard(
                icon: "clock.fill",
                label: "Avg Shift",
                value: formatHours(averageShiftLength),
                color: .blue
            )
            StatCard(
                icon: "banknote.fill",
                label: "Avg Earnings",
                value: "£\(format(averageEarningsPerShift))",
                color: .green
            )
        }

        // Break deductions
        BreakDeductionsCard(
            totalBreakDeducted: totalBreakDeducted,
            totalEarned: totalEarned
        )

        // Best shift
        if let best = bestShift {
            BestShiftCard(shift: best)
        }

        // Per-department breakdown
        let deptStats = departmentStats()
        if !deptStats.isEmpty {
            DepartmentBreakdownSection(stats: deptStats)
        }
    }

    // MARK: - Data helpers

    struct DeptStat {
        let department: Department
        var totalMinutes: Int
        var totalEarned: Decimal
    }

    private func departmentStats() -> [DeptStat] {
        var map: [PersistentIdentifier: DeptStat] = [:]
        for shift in completedShifts {
            for seg in shift.sortedSegments {
                guard let dept = seg.department else { continue }
                let rate = dept.hourlyRate
                let hours = Decimal(seg.durationMinutes) / Decimal(60)
                let earned = hours * rate
                let id = dept.persistentModelID
                if var stat = map[id] {
                    stat.totalMinutes += seg.durationMinutes
                    stat.totalEarned += earned
                    map[id] = stat
                } else {
                    map[id] = DeptStat(department: dept, totalMinutes: seg.durationMinutes, totalEarned: earned)
                }
            }
        }
        return map.values.sorted { $0.totalEarned > $1.totalEarned }
    }

    private func format(_ value: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Premium upsell card

private struct PremiumUpsellCard: View {
    @Environment(StoreManager.self) private var store
    @State private var showError = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis.ascending.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Detailed Stats")
                    .font(.headline)
                Text("Unlock averages, best shift, break deductions, and per-department breakdowns.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await store.purchase() }
            } label: {
                HStack {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Support the Developer · £0.99")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isPurchasing)

            Button("Restore Purchase") {
                Task { await store.restore() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .disabled(store.isPurchasing)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.errorMessage) { _, msg in showError = msg != nil }
    }
}

// MARK: - Sub-views

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Spacer()
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

private struct PeriodCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

private struct BestShiftCard: View {
    let shift: Shift

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Best Shift")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("£\(String(format: "%.2f", NSDecimalNumber(decimal: shift.totalShiftPay()).doubleValue))")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow)
                Text(shift.startTime.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow.opacity(0.8))
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

private struct DepartmentBreakdownSection: View {
    let stats: [StatsView.DeptStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By Department")
                .font(.headline)
                .padding(.bottom, 2)

            ForEach(stats, id: \.department.persistentModelID) { stat in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.department.name)
                            .fontWeight(.medium)
                        Text(formatHours(stat.totalMinutes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("£\(String(format: "%.2f", NSDecimalNumber(decimal: stat.totalEarned).doubleValue))")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)

                if stat.department.persistentModelID != stats.last?.department.persistentModelID {
                    Divider()
                }
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func formatHours(_ totalMinutes: Int) -> String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Break deductions card

private struct BreakDeductionsCard: View {
    let totalBreakDeducted: Decimal
    let totalEarned: Decimal

    private var grossEarnings: Decimal { totalEarned + totalBreakDeducted }

    private var percentage: Double {
        guard grossEarnings > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalBreakDeducted / grossEarnings * 100).doubleValue
    }

    private func format(_ value: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "minus.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Spacer()
            Text("-£\(format(totalBreakDeducted))")
                .font(.title3)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("Unpaid Break Deductions")
                .font(.caption)
                .foregroundStyle(.secondary)
            if percentage > 0 {
                Text(String(format: "%.1f%% of gross earnings", percentage))
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Weekly earnings chart card

private struct WeeklyEarningsCard: View {
    let dailyEarnings: [StatsView.DayEarning]
    let totalHours: Double

    private var maxEarnings: Double {
        dailyEarnings.map(\.earnings).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                Text("This Week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatHours(totalHours))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(dailyEarnings) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Earnings", day.earnings)
                )
                .foregroundStyle(day.isToday ? Color.purple : Color.purple.opacity(0.4))
                .cornerRadius(4)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            let day = dailyEarnings.first { $0.label == label }
                            Text(label)
                                .font(.caption2)
                                .fontWeight(day?.isToday == true ? .bold : .regular)
                                .foregroundStyle(day?.isToday == true ? Color.purple : Color.secondary)
                        }
                    }
                }
            }
            .frame(height: 80)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Calendar helpers

private extension Calendar {
    func startOfWeek(firstWeekday: Int = 2) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = firstWeekday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: components) ?? Date()
    }

    func startOfMonth() -> Date {
        let components = dateComponents([.year, .month], from: Date())
        return date(from: components) ?? Date()
    }
}
