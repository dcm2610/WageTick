//
//  NotificationManager.swift
//  WageTick
//

import UserNotifications
import Foundation
import SwiftData

enum NotificationManager {

    static let enabledKey = "notificationsEnabled"

    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    // MARK: - Permission

    /// Requests permission and, if granted, marks notifications as enabled.
    static func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: enabledKey)
                completion?(granted)
            }
        }
    }

    // MARK: - Shift start

    /// Schedules a "good luck" notification at the shift's start time.
    /// Only scheduled when the start time is in the future and notifications are enabled.
    static func scheduleShiftStart(shiftID: PersistentIdentifier, startTime: Date, hourlyWage: Decimal) {
        guard isEnabled else { return }
        guard startTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Shift starting now"
        content.body = goodLuckMessage(hourlyWage: hourlyWage)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startTime),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: startNotificationID(for: shiftID),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels any pending shift-start notification for the given shift.
    static func cancelShiftStart(shiftID: PersistentIdentifier) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [startNotificationID(for: shiftID)]
        )
    }

    // MARK: - Shift end

    /// Schedules an end notification at the shift's end time so it fires even if the app is closed.
    /// Only scheduled when endTime is in the future and notifications are enabled.
    static func scheduleShiftEnd(shiftID: PersistentIdentifier, shift: Shift) {
        guard isEnabled else { return }
        guard shift.endTime > Date() else { return }
        let endTime = shift.endTime

        let earnings = shift.totalShiftPay()
        let deduction = shift.breakDeduction()

        let content = UNMutableNotificationContent()
        content.title = "Shift complete"
        content.body = endMessage(earnings: earnings, breakDeduction: deduction)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: endTime),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: endNotificationID(for: shiftID),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels any pending shift-end notification for the given shift.
    static func cancelShiftEnd(shiftID: PersistentIdentifier) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [endNotificationID(for: shiftID)]
        )
    }

    // MARK: - Department reminder

    /// Schedules a reminder 2 hours before a recurring shift's start to prompt the user
    /// to set their department split for that shift.
    static func scheduleDepartmentReminder(shiftID: PersistentIdentifier, shiftStart: Date) {
        guard isEnabled else { return }
        let reminderTime = shiftStart.addingTimeInterval(-2 * 3600)
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming shift"
        content.body = "Don't forget to set your department split for today's shift."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: departmentReminderID(for: shiftID),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels any pending department reminder for the given shift.
    static func cancelDepartmentReminder(shiftID: PersistentIdentifier) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [departmentReminderID(for: shiftID)]
        )
    }

    /// Fires an immediate notification summarising a manually-ended shift's earnings.
    /// Also cancels any scheduled end notification to avoid a duplicate later.
    /// No-ops if notifications are disabled.
    static func sendShiftEnd(shiftID: PersistentIdentifier? = nil, earnings: Decimal, breakDeduction: Decimal) {
        guard isEnabled else { return }

        // Cancel the scheduled end notification if this shift had one
        if let shiftID { cancelShiftEnd(shiftID: shiftID) }

        let content = UNMutableNotificationContent()
        content.title = "Shift complete"
        content.body = endMessage(earnings: earnings, breakDeduction: breakDeduction)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "shift-end-\(UUID().uuidString)",
            content: content,
            trigger: nil  // nil = deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private helpers

    private static func startNotificationID(for shiftID: PersistentIdentifier) -> String {
        "shift-start-\(shiftID)"
    }

    private static func endNotificationID(for shiftID: PersistentIdentifier) -> String {
        "shift-end-\(shiftID)"
    }

    private static func departmentReminderID(for shiftID: PersistentIdentifier) -> String {
        "shift-dept-reminder-\(shiftID)"
    }

    private static let goodLuckMessages: [String] = [
        "Your shift has started.",
        "Clocked in.",
        "Shift started. Good luck.",
        "You're on the clock.",
        "Shift underway.",
        "Time to get to work.",
        "Your shift is now live.",
        "Clocked in and counting.",
    ]

    private static func goodLuckMessage(hourlyWage: Decimal) -> String {
        let base = goodLuckMessages.randomElement() ?? "Your shift has started. Good luck!"
        return "\(base) (£\(hourlyWage)/hr)"
    }

    private static func endMessage(earnings: Decimal, breakDeduction: Decimal) -> String {
        let earnedStr = String(format: "£%.2f", NSDecimalNumber(decimal: earnings).doubleValue)
        if breakDeduction > 0 {
            let deductionStr = String(format: "£%.2f", NSDecimalNumber(decimal: breakDeduction).doubleValue)
            return "You earned \(earnedStr) — \(deductionStr) deducted for unpaid break."
        } else {
            return "You earned \(earnedStr). Nice work!"
        }
    }
}
