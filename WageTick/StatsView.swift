//
//  StatsView.swift
//  WageTick
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var shifts: [Shift]
    @Query(sort: \Department.name) private var departments: [Department]

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

    private var totalBreakHours: Double {
        completedShifts.reduce(0.0) { $0 + $1.unpaidBreakDuration } / 3600
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
        let start = Calendar.current.startOfWeek()
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

                            // Hero — total earned
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

                            // This week / this month
                            HStack(spacing: 16) {
                                PeriodCard(title: "This Week", value: "£\(format(earningsThisWeek))", icon: "calendar")
                                PeriodCard(title: "This Month", value: "£\(format(earningsThisMonth))", icon: "calendar.badge.clock")
                            }

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

                            // Time worked
                            HStack(spacing: 16) {
                                StatCard(
                                    icon: "timer",
                                    label: "Hours Worked",
                                    value: formatHours(totalHoursWorked),
                                    color: .purple
                                )
                                StatCard(
                                    icon: "minus.circle.fill",
                                    label: "Break Deductions",
                                    value: "-£\(format(totalBreakDeducted))",
                                    color: .orange
                                )
                            }

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
                        .padding()
                    }
                }
                .navigationTitle("Stats")
            }
        }
    }

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

// MARK: - Calendar helpers

private extension Calendar {
    func startOfWeek() -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return date(from: components) ?? Date()
    }

    func startOfMonth() -> Date {
        let components = dateComponents([.year, .month], from: Date())
        return date(from: components) ?? Date()
    }
}
