import SwiftUI
import FamilyControls

// MARK: - FocusModeSetupView
//
// 4-step setup sheet for Focus Mode.
// Step 0: Intro
// Step 1: Pick apps (FamilyActivityPicker)
// Step 2: Schedule (always-on or timed window)
// Step 3: Duration + enable (requests authorization, applies shields, dismisses)

struct FocusModeSetupView: View {

    // MARK: Environment

    @Environment(FocusModeService.self) private var focusModeService
    @Environment(StoreService.self) private var storeService
    @Environment(\.dismiss) private var dismiss

    // MARK: State

    @State private var currentStep = 0
    @State private var scheduleEnabled = false
    @State private var scheduleStart = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
    @State private var scheduleEnd   = Calendar.current.date(from: DateComponents(hour: 17)) ?? Date()
    @State private var unlockDuration = 15

    private let totalSteps = 4
    private let durationOptions = [5, 15, 30, 60]

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentStep) {
                    introStep.tag(0)
                    pickAppsStep.tag(1)
                    scheduleStep.tag(2)
                    durationStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(true)
                .animation(.easeInOut, value: currentStep)

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == currentStep
                                    ? AnyShapeStyle(AppColors.accentGradient)
                                    : AnyShapeStyle(Color.gray.opacity(0.25))
                            )
                            .frame(width: index == currentStep ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Step 0: Intro

    private var introStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("mascot-goal")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 200)

            VStack(spacing: 10) {
                Text("Block distracting apps")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Train your brain instead of doomscrolling")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            continueButton { currentStep = 1 }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1: Pick Apps

    private var pickAppsStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 32)

            VStack(spacing: 8) {
                Text("Choose apps to block")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("These will be shielded while Focus Mode is on")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Free-user limit note
            if !storeService.isUltraUser {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.amber)
                    Text("Free plan: 1 app. Upgrade to Ultra for unlimited.")
                        .font(.caption)
                        .foregroundStyle(AppColors.amber)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.amber.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.amber.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
            }

            // FamilyActivityPicker — binds directly to focusModeService.activitySelection
            FamilyActivityPickerWrapper(selection: Binding(
                get: { focusModeService.activitySelection },
                set: { focusModeService.updateActivitySelection($0) }
            ))
            .frame(maxHeight: 340)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)

            Spacer()

            continueButton { currentStep = 2 }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 2: Schedule

    private var scheduleStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 32)

            VStack(spacing: 8) {
                Text("Set a schedule")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Automatically turn Focus Mode on at set times")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Always on / Scheduled toggle
            VStack(spacing: 0) {
                scheduleOptionRow(
                    title: "Always on",
                    subtitle: "Focus Mode stays active at all times",
                    icon: "infinity",
                    isSelected: !scheduleEnabled,
                    action: { withAnimation(.spring(response: 0.3)) { scheduleEnabled = false } }
                )

                Divider()
                    .padding(.horizontal, 16)

                scheduleOptionRow(
                    title: "Set a schedule",
                    subtitle: "Active only during specific hours",
                    icon: "clock.fill",
                    isSelected: scheduleEnabled,
                    action: { withAnimation(.spring(response: 0.3)) { scheduleEnabled = true } }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Time pickers — shown only when schedule is enabled
            if scheduleEnabled {
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("Start")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DatePicker("Start", selection: $scheduleStart, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    VStack(spacing: 6) {
                        Text("End")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DatePicker("End", selection: $scheduleEnd, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            continueButton { currentStep = 3 }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 3: Duration + Enable

    private var durationStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 32)

            VStack(spacing: 8) {
                Text("Unlock duration")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("How long can you unlock Focus Mode after a game?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Duration button row
            HStack(spacing: 10) {
                ForEach(durationOptions, id: \.self) { minutes in
                    let isSelected = unlockDuration == minutes
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            unlockDuration = minutes
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .primary)
                            Text("min")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? AnyShapeStyle(AppColors.accentGradient) : AnyShapeStyle(AppColors.cardSurface))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.clear : AppColors.cardBorder, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) minutes\(isSelected ? ", selected" : "")")
                }
            }
            .padding(.horizontal, 24)

            // Summary card
            VStack(alignment: .leading, spacing: 12) {
                summaryRow(icon: "app.badge.fill", label: "\(focusModeService.blockedAppCount) app\(focusModeService.blockedAppCount == 1 ? "" : "s") selected")
                summaryRow(icon: "clock.fill", label: scheduleEnabled ? "Scheduled (\(formattedTime(scheduleStart)) – \(formattedTime(scheduleEnd)))" : "Always on")
                summaryRow(icon: "bolt.fill", label: "Unlock: \(unlockDuration) min per game")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            // Enable Focus Mode CTA
            Button {
                Task {
                    await focusModeService.requestAuthorization()
                    focusModeService.unlockDuration = unlockDuration
                    focusModeService.updateSchedule(
                        enabled: scheduleEnabled,
                        start: scheduleStart,
                        end: scheduleEnd
                    )
                    focusModeService.enable()
                    dismiss()
                }
            } label: {
                Text("Enable Focus Mode")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .gradientButton()
        }
        .padding(.horizontal, 32)
    }

    private func scheduleOptionRow(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? AppColors.accent : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.accent)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func summaryRow(icon: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - FamilyActivityPickerWrapper

/// UIViewControllerRepresentable wrapper so FamilyActivityPicker can be embedded
/// inside a regular SwiftUI layout without needing to be a sheet itself.
private struct FamilyActivityPickerWrapper: UIViewControllerRepresentable {
    @Binding var selection: FamilyActivitySelection

    func makeUIViewController(context: Context) -> UIViewController {
        let picker = FamilyActivityPicker(selection: $selection)
        let host = UIHostingController(rootView: picker)
        host.view.backgroundColor = .clear
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let host = uiViewController as? UIHostingController<FamilyActivityPicker> {
            host.rootView = FamilyActivityPicker(selection: $selection)
        }
    }
}
