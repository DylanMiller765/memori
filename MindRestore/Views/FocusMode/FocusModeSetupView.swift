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

    /// Optional completion handler — used when embedded in onboarding.
    /// When nil, the view dismisses itself via `dismiss()`.
    var onComplete: (() -> Void)?

    // MARK: Environment

    @Environment(FocusModeService.self) private var focusModeService
    @Environment(StoreService.self) private var storeService
    @Environment(\.dismiss) private var dismiss

    // MARK: State

    /// Start at "pick apps" — the intro step is skipped when used inline in onboarding.
    @State private var currentStep = 1
    @State private var scheduleEnabled = false
    // Default to evening/bedtime block (22:00 → 08:00) — matches FocusModeService's default and
    // the feature's primary intent (block distractions when winding down / sleeping).
    @State private var scheduleStart = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    @State private var scheduleEnd   = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
    @State private var scheduleDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7] // 1=Sun, 7=Sat
    @State private var unlockDuration = 15
    @State private var showingProPaywall = false
    @State private var showingAppPicker = false

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayIndices = [1, 2, 3, 4, 5, 6, 7] // Sunday=1 through Saturday=7

    private let durationOptions = [5, 15, 30, 60]

    /// True when this view is being shown as part of OnboardingView — hides the inner page dots
    /// because the outer onboarding flow renders its own progress indicator.
    private var isEmbeddedInOnboarding: Bool { onComplete != nil }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentStep) {
                    pickAppsStep.tag(1)
                    scheduleStep.tag(2)
                    durationStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(true)
                .animation(.easeInOut, value: currentStep)

                // Inner page indicator — only shown when used as a standalone sheet (not in onboarding).
                if !isEmbeddedInOnboarding {
                    HStack(spacing: 8) {
                        ForEach(1..<4, id: \.self) { index in
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

            // Free-user limit note — tappable to open paywall
            if !storeService.isProUser {
                Button {
                    showingProPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.amber)
                        Text("Free plan: 1 app. Get Pro for unlimited.")
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
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }

            // Selected apps summary
            let appCount = focusModeService.activitySelection.applicationTokens.count
            let catCount = focusModeService.activitySelection.categoryTokens.count
            let totalSelected = appCount + catCount

            Button {
                showingAppPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: totalSelected > 0 ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(totalSelected > 0 ? AppColors.mint : AppColors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(totalSelected > 0 ? "\(totalSelected) selected" : "Tap to choose apps")
                            .font(.system(size: 16, weight: .semibold))
                        Text(totalSelected > 0 ? "Tap to change" : "Pick apps & categories to block")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(totalSelected > 0 ? AppColors.mint.opacity(0.3) : AppColors.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()

            continueButton(disabled: totalSelected == 0) {
                let exceedsLimit = appCount > 1 || catCount > 0
                if !storeService.isProUser && exceedsLimit {
                    showingProPaywall = true
                } else {
                    currentStep = 2
                }
            }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .familyActivityPicker(isPresented: $showingAppPicker, selection: Binding(
            get: { focusModeService.activitySelection },
            set: { focusModeService.updateActivitySelection($0) }
        ))
        .sheet(isPresented: $showingProPaywall) {
            PaywallView(triggerSource: "focus_mode_limit")
        }
    }

    // MARK: - Step 2: Schedule

    private var scheduleStep: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            Text("When should\napps be blocked?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            Text("You can change this anytime in settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            // Schedule option cards
            VStack(spacing: 10) {
                scheduleCard(
                    mascot: "mascot-streak-fire",
                    title: "All day",
                    subtitle: "Maximum commitment. No breaks.",
                    isSelected: !scheduleEnabled
                ) { scheduleEnabled = false }

                scheduleCard(
                    mascot: "mascot-thinking",
                    title: "Set hours",
                    subtitle: "Active only when you need it.",
                    isSelected: scheduleEnabled
                ) { scheduleEnabled = true }
            }
            .padding(.horizontal, 20)

            // Time + day pickers when schedule is selected
            if scheduleEnabled {
                VStack(spacing: 10) {
                    // Time pickers
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $scheduleStart, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text("End")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $scheduleEnd, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    .padding(16)
                    .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )

                    // Day picker
                    HStack(spacing: 6) {
                        ForEach(Array(zip(dayIndices, dayLabels)), id: \.0) { index, label in
                            let isActive = scheduleDays.contains(index)
                            Text(label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isActive ? .white : .secondary)
                                .frame(width: 38, height: 38)
                                .background(
                                    isActive ? AppColors.accent : Color.white.opacity(0.05),
                                    in: Circle()
                                )
                                .onTapGesture {
                                    if scheduleDays.contains(index) {
                                        if scheduleDays.count > 1 {
                                            scheduleDays.remove(index)
                                        }
                                    } else {
                                        scheduleDays.insert(index)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            Spacer()

            continueButton { currentStep = 3 }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private func scheduleCard(mascot: String, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(mascot)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? AppColors.violet : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    // MARK: - Step 3: Duration + Enable

    private var durationStep: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            Text("Pick your pace")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .padding(.bottom, 6)

            Text("Every brain game earns you unlock time.\nYou can change this later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            // Preset cards
            VStack(spacing: 10) {
                paceCard(
                    mascot: "mascot-streak-fire",
                    name: "Laser",
                    description: "Max focus. Apps snap shut fast.",
                    minutes: 5,
                    isRecommended: false
                )

                paceCard(
                    mascot: "mascot-cool",
                    name: "Balanced",
                    description: "The one most people stick with.",
                    minutes: 15,
                    isRecommended: true
                )

                paceCard(
                    mascot: "mascot-welcome",
                    name: "Breathing",
                    description: "Room to reply without earning it twice.",
                    minutes: 30,
                    isRecommended: false
                )

                paceCard(
                    mascot: "mascot-bored",
                    name: "Easing in",
                    description: "Light touch while you're still adjusting.",
                    minutes: 60,
                    isRecommended: false
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            // Enable Focus Mode CTA
            Button {
                Task {
                    await focusModeService.requestAuthorization()
                    focusModeService.setUnlockDuration(unlockDuration)
                    focusModeService.updateScheduleDays(scheduleDays)
                    focusModeService.updateSchedule(
                        enabled: scheduleEnabled,
                        start: scheduleStart,
                        end: scheduleEnd
                    )
                    focusModeService.enable()
                    Analytics.focusSetupCompleted()
                    if let onComplete {
                        onComplete()
                    } else {
                        dismiss()
                    }
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

    private func paceCard(mascot: String, name: String, description: String, minutes: Int, isRecommended: Bool) -> some View {
        let isSelected = unlockDuration == minutes

        return HStack(spacing: 14) {
            Image(mascot)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    if isRecommended {
                        Text("RECOMMENDED")
                            .font(.system(size: 8, weight: .heavy))
                            .tracking(0.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.violet, in: Capsule())
                    }
                }

                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 1) {
                Text("\(minutes)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? AppColors.violet : .primary)
                Text("MIN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? AppColors.violet : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                unlockDuration = minutes
            }
        }
    }

    // MARK: - Helpers

    private func continueButton(disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .gradientButton()
                .opacity(disabled ? 0.45 : 1.0)
        }
        .disabled(disabled)
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
        // Recursively strip backgrounds after layout pass
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Self.clearBackgrounds(in: host.view)
        }
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let host = uiViewController as? UIHostingController<FamilyActivityPicker> {
            host.rootView = FamilyActivityPicker(selection: $selection)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Self.clearBackgrounds(in: host.view)
            }
        }
    }

    /// Recursively walks the view hierarchy to clear rounded-rect backgrounds
    /// that the system applies to FamilyActivityPicker.
    private static func clearBackgrounds(in view: UIView) {
        view.backgroundColor = .clear
        view.layer.cornerRadius = 0
        view.layer.borderWidth = 0
        view.layer.shadowOpacity = 0

        // Clear any visual effect views or grouped-style table backgrounds
        if let effectView = view as? UIVisualEffectView {
            effectView.effect = nil
            effectView.backgroundColor = .clear
        }

        for subview in view.subviews {
            clearBackgrounds(in: subview)
        }
    }
}
