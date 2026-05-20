import Foundation
#if canImport(EventKit)
import EventKit
#endif
import SharedModels

/// Mirrors meetings the user has accepted into the system calendar via EventKit.
/// No-op on platforms without EventKit (e.g. some Mac contexts) — still safe to call.
@MainActor
public final class CalendarSyncStore: ObservableObject {
    public static let shared = CalendarSyncStore()

    @Published public private(set) var authorized: Bool = false
    @Published public var lastError: Error?

    #if canImport(EventKit)
    private let store = EKEventStore()
    #endif

    private init() {}

    public func requestAccessIfNeeded() async {
        #if canImport(EventKit)
        if #available(iOS 17.0, macOS 14.0, *) {
            do {
                let granted = try await store.requestWriteOnlyAccessToEvents()
                authorized = granted
            } catch {
                authorized = false
                lastError = error
            }
        } else {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.requestAccess(to: .event) { [weak self] granted, error in
                    Task { @MainActor in
                        self?.authorized = granted
                        if let error { self?.lastError = error }
                        continuation.resume()
                    }
                }
            }
        }
        #endif
    }

    /// Upsert a meeting into the user's default calendar. Idempotent via title+UID match.
    public func upsert(_ meeting: MeetingDTO) async {
        #if canImport(EventKit)
        guard authorized else { return }
        guard let calendar = store.defaultCalendarForNewEvents else { return }

        let identifierKey = "meeting-\(meeting.id.uuidString)"
        let event = findExistingEvent(matching: identifierKey, around: meeting.scheduledStartAt) ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = meeting.title
        event.startDate = meeting.scheduledStartAt
        event.endDate = meeting.scheduledEndAt
        event.notes = composeNotes(meeting: meeting, marker: identifierKey)
        if let urlString = meeting.shareUrl, let url = URL(string: urlString) {
            event.url = url
        }
        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            lastError = error
        }
        #endif
    }

    public func remove(_ meeting: MeetingDTO) async {
        #if canImport(EventKit)
        guard authorized else { return }
        let identifierKey = "meeting-\(meeting.id.uuidString)"
        guard let event = findExistingEvent(matching: identifierKey, around: meeting.scheduledStartAt) else { return }
        do { try store.remove(event, span: .thisEvent, commit: true) }
        catch { lastError = error }
        #endif
    }

    #if canImport(EventKit)
    private func composeNotes(meeting: MeetingDTO, marker: String) -> String {
        var lines: [String] = []
        if let agenda = meeting.agenda, !agenda.isEmpty { lines.append(agenda) }
        if let desc = meeting.description, !desc.isEmpty { lines.append(desc) }
        if let share = meeting.shareUrl { lines.append("Join: \(share)") }
        lines.append("")
        lines.append("[\(marker)]")  // sentinel for idempotent match
        return lines.joined(separator: "\n")
    }

    private func findExistingEvent(matching marker: String, around date: Date) -> EKEvent? {
        let start = date.addingTimeInterval(-30 * 86_400)
        let end = date.addingTimeInterval(30 * 86_400)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        return events.first(where: { ($0.notes ?? "").contains(marker) })
    }
    #endif
}
