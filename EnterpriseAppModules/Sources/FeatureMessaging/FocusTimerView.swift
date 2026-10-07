import SwiftUI
import DesignSystem
import SharedModels
import AppData

public struct FocusTimerView: View {
    @State private var sessionTitle: String = "Deep Work Session"
    @State private var targetMinutes: Int = 25
    @State private var remainingSeconds: Int = 25 * 60
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var mode: String = "Focus"
    @State private var timer: Timer? = nil

    private struct PresetItem: Identifiable {
        let id: String
        let label: String
        let minutes: Int
        let mode: String
    }

    private let presets: [PresetItem] = [
        PresetItem(id: "focus_25", label: "Focus 25m", minutes: 25, mode: "Focus"),
        PresetItem(id: "deep_45", label: "Deep Work 45m", minutes: 45, mode: "Focus"),
        PresetItem(id: "short_5", label: "Short Break 5m", minutes: 5, mode: "Break"),
        PresetItem(id: "long_15", label: "Long Break 15m", minutes: 15, mode: "Break")
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                presetSelectorView
                titleInputField
                timerDialView
                controlsView
                statusFooterView
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Subviews

    private var presetSelectorView: some View {
        HStack(spacing: 8) {
            ForEach(presets) { item in
                let isSelected = targetMinutes == item.minutes && mode == item.mode
                Button {
                    selectPreset(item)
                } label: {
                    Text(item.label)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(isSelected ? AppColors.brandPrimary : AppColors.surfaceElevated)
                        .foregroundStyle(isSelected ? Color.white : AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isRunning)
            }
        }
        .padding(.top, AppSpacing.md)
    }

    private var titleInputField: some View {
        TextField("Session Goal (e.g., Code Review)", text: $sessionTitle)
            .textFieldStyle(.plain)
            .padding()
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .disabled(isRunning)
    }

    private var timerDialView: some View {
        ZStack {
            Circle()
                .stroke(AppColors.borderDefault.opacity(0.3), lineWidth: 16)
                .frame(width: 240, height: 240)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    mode == "Focus" ? Color.orange : Color.green,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 6) {
                Image(systemName: mode == "Focus" ? "headphones" : "cup.and.saucer.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(mode == "Focus" ? Color.orange : Color.green)

                Text(timeString)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary)

                dialStatusLabel
            }
        }
        .padding(.vertical, AppSpacing.lg)
    }

    @ViewBuilder
    private var dialStatusLabel: some View {
        if !isRunning {
            Text("READY")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.textSecondary)
        } else if isPaused {
            Text("PAUSED")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.yellow)
        } else {
            Text("\(mode.uppercased()) ACTIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(mode == "Focus" ? Color.orange : Color.green)
        }
    }

    private var controlsView: some View {
        HStack(spacing: AppSpacing.xl) {
            if !isRunning {
                Button {
                    startTimer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start Session")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }
            } else {
                Button {
                    togglePause()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        Text(isPaused ? "Resume" : "Pause")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isPaused ? Color.green : Color.yellow)
                    .clipShape(Capsule())
                }

                Button {
                    stopTimer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private var statusFooterView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(LiveActivityManager.shared.areActivitiesSupported ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(LiveActivityManager.shared.areActivitiesSupported ? "Dynamic Island & Lock Screen Live Activity Active" : "Live Activities Not Supported on this OS")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Logic

    private var progress: Double {
        let total = Double(targetMinutes * 60)
        guard total > 0 else { return 0 }
        return Double(max(0, total - Double(remainingSeconds))) / total
    }

    private var timeString: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func selectPreset(_ item: PresetItem) {
        targetMinutes = item.minutes
        remainingSeconds = item.minutes * 60
        mode = item.mode
        if sessionTitle.isEmpty || sessionTitle == "Deep Work Session" {
            sessionTitle = item.label
        }
    }

    private func startTimer() {
        isRunning = true
        isPaused = false
        remainingSeconds = targetMinutes * 60

        LiveActivityManager.shared.startFocusTimerActivity(
            sessionTitle: sessionTitle,
            targetMinutes: targetMinutes,
            mode: mode
        )

        scheduleTimerTick()
    }

    private func togglePause() {
        if isPaused {
            isPaused = false
            let target = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            LiveActivityManager.shared.updateFocusTimerActivity(
                remainingSeconds: remainingSeconds,
                totalSeconds: targetMinutes * 60,
                isPaused: false,
                targetDate: target,
                mode: mode
            )
            scheduleTimerTick()
        } else {
            isPaused = true
            timer?.invalidate()
            timer = nil
            LiveActivityManager.shared.updateFocusTimerActivity(
                remainingSeconds: remainingSeconds,
                totalSeconds: targetMinutes * 60,
                isPaused: true,
                targetDate: Date(),
                mode: mode
            )
        }
    }

    private func stopTimer() {
        isRunning = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        remainingSeconds = targetMinutes * 60
        LiveActivityManager.shared.endFocusTimerActivity()
    }

    private func scheduleTimerTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                    let target = Date().addingTimeInterval(TimeInterval(self.remainingSeconds))
                    LiveActivityManager.shared.updateFocusTimerActivity(
                        remainingSeconds: self.remainingSeconds,
                        totalSeconds: self.targetMinutes * 60,
                        isPaused: false,
                        targetDate: target,
                        mode: self.mode
                    )
                } else {
                    self.stopTimer()
                }
            }
        }
    }
}
