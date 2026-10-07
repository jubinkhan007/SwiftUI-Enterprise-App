import SwiftUI
import Domain
import DesignSystem
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif
#if canImport(WidgetKit) && os(iOS)
import WidgetKit
#endif

#if canImport(ActivityKit) && canImport(WidgetKit) && os(iOS)

// MARK: - Meeting Live Activity Widget

public struct MeetingLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeetingActivityAttributes.self) { context in
            // Lock Screen / Notification Banner
            MeetingActivityLockScreenBanner(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color(red: 0.08, green: 0.10, blue: 0.16))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.meetingTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(context.state.participantCount) participants")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.leading, 4)
                }

                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timerInterval: context.state.startDate...Date.distantFuture)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.green)
                        Text(context.state.status)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 4)
                }

                // Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        HStack(spacing: 6) {
                            Label(
                                context.state.isAudioMuted ? "Muted" : "Unmuted",
                                systemImage: context.state.isAudioMuted ? "mic.slash.fill" : "mic.fill"
                            )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(context.state.isAudioMuted ? Color.orange : Color.green)

                            if context.state.isScreenSharing {
                                Label("Sharing", systemImage: "rectangle.inset.filled.and.cursorarrow")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.blue)
                            }
                        }

                        Spacer()

                        Link(destination: URL(string: "taskflow://meetings/\(context.attributes.meetingId)")!) {
                            HStack(spacing: 4) {
                                Text("Open")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.indigo)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.indigo)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...Date.distantFuture)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "video.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.indigo)
            }
        }
    }
}

// MARK: - Meeting Lock Screen Banner

private struct MeetingActivityLockScreenBanner: View {
    let attributes: MeetingActivityAttributes
    let state: MeetingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.2))
                    .frame(width: 42, height: 42)
                Image(systemName: "video.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(attributes.meetingTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(state.status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.green)
                }

                HStack(spacing: 8) {
                    Label("\(state.participantCount) in room", systemImage: "person.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))

                    Label(
                        state.isAudioMuted ? "Muted" : "Active",
                        systemImage: state.isAudioMuted ? "mic.slash.fill" : "mic.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(state.isAudioMuted ? Color.orange : Color.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(timerInterval: state.startDate...Date.distantFuture)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)

                Link(destination: URL(string: "taskflow://meetings/\(attributes.meetingId)")!) {
                    Text("Join")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Call Live Activity Widget

public struct CallLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: CallActivityAttributes.self) { context in
            CallActivityLockScreenBanner(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color(red: 0.08, green: 0.12, blue: 0.18))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.channelOrContactName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(context.state.remoteParticipantCount + 1) connected")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timerInterval: context.state.startDate...Date.distantFuture)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.green)
                        Text(context.state.status)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: context.state.isAudioMuted ? "mic.slash.fill" : "mic.fill")
                                .foregroundStyle(context.state.isAudioMuted ? Color.orange : Color.green)
                            Image(systemName: context.state.isVideoMuted ? "video.slash.fill" : "video.fill")
                                .foregroundStyle(context.state.isVideoMuted ? Color.gray : Color.blue)
                        }
                        .font(.system(size: 12))

                        Spacer()

                        Link(destination: URL(string: "taskflow://calls/\(context.attributes.callId)")!) {
                            HStack(spacing: 4) {
                                Text("Return")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.green)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...Date.distantFuture)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.green)
            }
        }
    }
}

// MARK: - Call Lock Screen Banner

private struct CallActivityLockScreenBanner: View {
    let attributes: CallActivityAttributes
    let state: CallActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 42, height: 42)
                Image(systemName: "phone.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.channelOrContactName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(state.status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.green)
                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(state.isAudioMuted ? "Mic Muted" : "Mic Live")
                        .font(.system(size: 11))
                        .foregroundStyle(state.isAudioMuted ? Color.orange : Color.white.opacity(0.7))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(timerInterval: state.startDate...Date.distantFuture)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Link(destination: URL(string: "taskflow://calls/\(attributes.callId)")!) {
                    Text("Return")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Focus Timer Live Activity Widget

public struct FocusTimerLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerActivityAttributes.self) { context in
            FocusTimerLockScreenBanner(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color(red: 0.16, green: 0.10, blue: 0.05))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "headphones")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.sessionTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.mode)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.orange.opacity(0.9))
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.isPaused {
                            Text("PAUSED")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.yellow)
                        } else {
                            Text(timerInterval: Date()...context.state.targetDate, countsDown: true)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
                        }
                        Text("\(context.attributes.targetMinutes) min goal")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ProgressView(
                            value: Double(max(0, context.state.totalSeconds - context.state.remainingSeconds)),
                            total: Double(max(1, context.state.totalSeconds))
                        )
                        .tint(Color.orange)

                        Spacer(minLength: 16)

                        Link(destination: URL(string: "taskflow://productivity")!) {
                            HStack(spacing: 4) {
                                Text("Focus")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "headphones")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.orange)
            } compactTrailing: {
                if context.state.isPaused {
                    Text("PAUSE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.yellow)
                        .frame(width: 44)
                } else {
                    Text(timerInterval: Date()...context.state.targetDate, countsDown: true)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.orange)
                        .frame(width: 44)
                }
            } minimal: {
                Image(systemName: "headphones")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.orange)
            }
        }
    }
}

// MARK: - Focus Timer Lock Screen Banner

private struct FocusTimerLockScreenBanner: View {
    let attributes: FocusTimerActivityAttributes
    let state: FocusTimerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 42, height: 42)
                Image(systemName: "headphones")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(attributes.sessionTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(state.mode)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.orange)
                }

                ProgressView(
                    value: Double(max(0, state.totalSeconds - state.remainingSeconds)),
                    total: Double(max(1, state.totalSeconds))
                )
                .tint(Color.orange)
                .frame(width: 140)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if state.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.yellow)
                } else {
                    Text(timerInterval: Date()...state.targetDate, countsDown: true)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.orange)
                }

                Link(destination: URL(string: "taskflow://productivity")!) {
                    Text("Open")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Live Activity Widget Bundle

public struct TaskFlowLiveActivityBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        MeetingLiveActivityWidget()
        CallLiveActivityWidget()
        FocusTimerLiveActivityWidget()
    }
}

#endif
