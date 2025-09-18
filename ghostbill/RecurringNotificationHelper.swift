//
//  RecurringNotificationsHelper.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import Foundation
import UserNotifications

/// Handles notification permission AND scheduling for recurring payments.
final class RecurringNotificationsHelper {
    static let shared = RecurringNotificationsHelper()
    private init() {}

    // MARK: - Public API

    /// Requests notification authorization **only if needed**.
    ///
    /// - Behavior:
    ///   - If status is `.notDetermined`, presents the iOS system prompt and returns the result.
    ///   - If status is `.authorized` / `.provisional` / `.ephemeral`, returns `true` (no prompt shown).
    ///   - If status is `.denied`, returns `false` (no prompt shown). Your UI should offer "Open Settings".
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await currentSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return await requestAuthorization()
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: Scheduling (Create the next notification)

    enum NotificationError: Error {
        case notAuthorized
        case notificationsDisabledOnItem
        case missingLeadOrTime
        case invalidNextDate
        case fireDateInPast
    }

    /// Schedules a single local notification for the item's next payment occurrence.
    /// If a pending request already exists with the same identifier, the system replaces it.
    func scheduleNext(for item: RecurringTransactionsService.DBRecurringTransaction) async throws {
        guard item.notifications_enabled else {
            throw NotificationError.notificationsDisabledOnItem
        }
        guard let leadDays = item.notify_lead_days, let timeStr = item.notify_time else {
            throw NotificationError.missingLeadOrTime
        }
        guard await requestAuthorizationIfNeeded() else {
            throw NotificationError.notAuthorized
        }
        guard let nextDate = parseYYYYMMDD(item.next_date) else {
            throw NotificationError.invalidNextDate
        }
        guard let fireDate = computeFireDate(nextDate: nextDate, leadDays: leadDays, timeString: timeStr) else {
            throw NotificationError.invalidNextDate
        }
        guard fireDate > Date() else {
            throw NotificationError.fireDateInPast
        }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming \(item.merchant_name) payment"
        let amountStr = formatAmount(item.amount)
        content.body = "You have a \(item.merchant_name) payment of \(amountStr) in \(leadDays) day\(leadDays == 1 ? "" : "s")."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let identifier = makeIdentifier(for: item)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await add(request: request)
    }

    /// Cancels any pending/delivered notifications for this recurring item.
    /// - Returns: `true` if a pending request existed before removal (best-effort).
    @discardableResult
    func cancel(for item: RecurringTransactionsService.DBRecurringTransaction) async -> Bool {
        let id = makeIdentifier(for: item)
        let center = UNUserNotificationCenter.current()

        let hadPending = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            center.getPendingNotificationRequests { reqs in
                let exists = reqs.contains { $0.identifier == id }
                cont.resume(returning: exists)
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
        return hadPending
    }

    /// Idempotent convenience that cancels then (optionally) schedules.
    /// - If the item has `notifications_enabled == false`, this only cancels and returns `false`.
    /// - Otherwise it cancels and re-schedules, returning `true` on success.
    @discardableResult
    func rescheduleNext(for item: RecurringTransactionsService.DBRecurringTransaction) async throws -> Bool {
        _ = await cancel(for: item)
        guard item.notifications_enabled else { return false }
        try await scheduleNext(for: item)
        return true
    }

    // MARK: - Helpers

    /// Stable identifier per recurring item (one-at-a-time scheduling model).
    func makeIdentifier(for item: RecurringTransactionsService.DBRecurringTransaction) -> String {
        "recurring:\(item.id.uuidString)"
    }

    private func computeFireDate(nextDate: Date, leadDays: Int, timeString: String) -> Date? {
        guard let notifyDay = Calendar.current.date(byAdding: .day, value: -leadDays, to: nextDate) else {
            return nil
        }
        let (h, m) = parseHHmm(timeString)
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: notifyDay)
        comps.hour = h
        comps.minute = m
        return Calendar.current.date(from: comps)
    }

    private func parseYYYYMMDD(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    private func parseHHmm(_ s: String) -> (hour: Int, minute: Int) {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        let hour = parts.indices.contains(0) ? parts[0] : 9
        let minute = parts.indices.contains(1) ? parts[1] : 0
        return (hour, minute)
    }

    private func formatAmount(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        return nf.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }

    // MARK: - UNUserNotificationCenter bridges (explicit continuation types)

    private func currentSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { (continuation: CheckedContinuation<UNNotificationSettings, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func add(request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

