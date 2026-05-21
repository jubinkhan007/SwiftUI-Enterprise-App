import SwiftUI
import DesignSystem
import SharedModels

/// Tabbed productivity hub: Reminders / Scheduled / Templates.
/// Drafts are accessed inside chats, so they're not a tab here.
public struct ProductivityHubView: View {
    public enum Tab: String, CaseIterable, Identifiable, Hashable {
        case reminders, scheduled, templates
        public var id: String { rawValue }
        var label: String {
            switch self {
            case .reminders: return "Reminders"
            case .scheduled: return "Scheduled"
            case .templates: return "Templates"
            }
        }
        var icon: String {
            switch self {
            case .reminders: return "bell.fill"
            case .scheduled: return "clock.arrow.circlepath"
            case .templates: return "text.badge.star"
            }
        }
    }

    @State private var tab: Tab = .reminders

    public let canManageOrgTemplates: Bool

    public init(canManageOrgTemplates: Bool) {
        self.canManageOrgTemplates = canManageOrgTemplates
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Label(t.label, systemImage: t.icon).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.backgroundPrimary)

            content
        }
        .background(AppColors.backgroundPrimary)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .reminders: RemindersView()
        case .scheduled: ScheduledMessagesView()
        case .templates: TemplatesSettingsView(canManageOrgTemplates: canManageOrgTemplates)
        }
    }
}
