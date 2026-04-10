import SwiftUI
import SwiftData

struct ScoreRevealView: View {
    let viewModel: BrainAssessmentViewModel
    let previousScore: BrainScoreResult?
    var userAge: Int = 0
    let onDone: () -> Void

    @Query private var users: [User]
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService

    @State private var showingPaywall = false
    @State private var displayedScore: Int = 0
    @State private var shareImage: UIImage?
    @State private var showScore = false
    @State private var showType = false
    @State private var showConfetti = false
    @State private var showActions = false
    @State private var showBreakdown = false
    @State private var showComparison = false
    @State private var scoreTimer: Timer?
    // @State private var showChallenge = false
    @AppStorage("celebratedBrainAgeBelow") private var celebratedBrainAgeBelow = false

    // Brain Age dramatic reveal states
    @State private var showBrainAgeOverlay = false
    @State private var displayedBrainAge: Int = 18
    @State private var showBrainAgeLabel = false
    @State private var isCountingUp = false
    @State private var countUpFinished = false
    @State private var showBrainAgeSubtitle = false
    @State private var showBrainAgePercentile = false
    @State private var showBrainAgeShare = false
    @State private var pulseGlow = false
    @State private var brainAgeOverlayDismissed = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    private var ageComparisonText: String? {
        guard userAge > 0 else { return nil }
        let diff = userAge - viewModel.brainAge
        if diff > 0 { return "\(diff) years younger than you!" }
        if diff < 0 { return "\(abs(diff)) years older than your real age" }
        return "Same as your real age!"
    }

    private var ageComparisonColor: Color {
        guard userAge > 0 else { return .secondary }
        let diff = userAge - viewModel.brainAge
        if diff > 0 { return AppColors.teal }
        if diff < 0 { return AppColors.coral }
        return .secondary
    }

    var body: some View {
        // If brain age overlay is showing, it takes over the ENTIRE screen
        if showBrainAgeOverlay && !brainAgeOverlayDismissed {
            brainAgeOverlayView
                .toolbar(.hidden, for: .navigationBar)
        } else {
            mainResultsView
        }
    }

    private var mainResultsView: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    Spacer(minLength: 4)

                    // Brain Score
                    if showScore {
                        VStack(spacing: 4) {
                            Text("\(displayedScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                                .contentTransition(.numericText(value: Double(displayedScore)))

                            Text("Brain Score")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Brain Score \(viewModel.brainScore) out of 1000")
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Brain Age summary (shown after overlay dismissed)
                    if brainAgeOverlayDismissed {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile.fill")
                                .foregroundStyle(brainAgeColor(for: viewModel.brainAge))
                            Text("Brain Age:")
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.brainAge)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(brainAgeColor(for: viewModel.brainAge))
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Your brain age is \(viewModel.brainAge)")
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        if let comparison = ageComparisonText {
                            Text(comparison)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ageComparisonColor)
                        }

                        // First-time brain age below real age celebration
                        if userAge > 0 && viewModel.brainAge < userAge && !celebratedBrainAgeBelow {
                            ShareLink(
                                item: "My Brain Age is \(viewModel.brainAge) — that's \(userAge - viewModel.brainAge) years younger than my real age! \u{1F9E0}\u{1F525}\n\nTest yours with Memori"
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption2.weight(.semibold))
                                    Text("Brain younger than you! Share")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppColors.teal, in: Capsule())
                            }
                            .transition(.scale.combined(with: .opacity))
                            .onAppear {
                                celebratedBrainAgeBelow = true
                            }
                        }
                    }

                    // Brain Type
                    if showType {
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.brainType.icon)
                                    .font(.headline)
                                Text(viewModel.brainType.displayName)
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundStyle(brainTypeColor)

                            Text(viewModel.brainType.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    // Percentile (inline, after overlay)
                    if brainAgeOverlayDismissed {
                        Text("Better than \(viewModel.percentile)% of players")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.accent.opacity(0.18), in: Capsule())
                            .accessibilityLabel("Better than \(viewModel.percentile) percent of players")
                            .transition(.opacity)
                    }

                    // Score Comparison
                    if showComparison, let previous = previousScore {
                        let diff = viewModel.brainScore - previous.brainScore
                        let improved = diff > 0

                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Text("Previous: \(previous.brainScore)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)

                                Text("Current: \(viewModel.brainScore)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.accent)
                            }

                            if improved {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.green)
                                    Text("+\(diff) points!")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.green)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.green.opacity(0.1), in: Capsule())
                            } else {
                                Text("Keep training!")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.accent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppColors.accent.opacity(0.18), in: Capsule())
                            }
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    // Breakdown
                    if showBreakdown {
                        VStack(spacing: 8) {
                            Text("Performance Breakdown")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            breakdownRow(
                                icon: "number.circle.fill",
                                label: "Digit Span",
                                value: "\(viewModel.digitMaxCorrect) digits",
                                score: viewModel.digitScore,
                                color: .blue
                            )
                            breakdownRow(
                                icon: "bolt.fill",
                                label: "Reaction Time",
                                value: "\(viewModel.avgReactionMs)ms",
                                score: viewModel.reactionScore,
                                color: .yellow
                            )
                            breakdownRow(
                                icon: "square.grid.3x3.fill",
                                label: "Visual Memory",
                                value: "Level \(viewModel.visualMaxCorrect)",
                                score: viewModel.visualScore,
                                color: .purple
                            )
                        }
                        .appCard()
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Leaderboard rank
                    if showBreakdown {
                        LeaderboardRankCard(
                            exerciseType: nil,
                            userScore: viewModel.brainScore,
                        )
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Actions
                    if showActions {
                        VStack(spacing: 12) {
                            if let shareImage {
                                ShareLink(
                                    item: Image(uiImage: shareImage),
                                    preview: SharePreview("Brain Score: \(viewModel.brainScore)", image: Image(uiImage: shareImage))
                                ) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Your Score")
                                    }
                                    .accentButton()
                                }
                                .accessibilityHint("Share your brain score on social media")
                            } else {
                                ShareLink(item: shareText) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Your Score")
                                    }
                                    .accentButton()
                                }
                                .accessibilityHint("Share your brain score on social media")
                            }

                            if let previous = previousScore, viewModel.brainScore > previous.brainScore {
                                let diff = viewModel.brainScore - previous.brainScore
                                ShareLink(item: "I improved my Brain Score by +\(diff) points! (\(previous.brainScore) -> \(viewModel.brainScore)/1000)\n\nTest yours with Memori") {
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                        Text("Share Your Improvement")
                                    }
                                    .gradientButton()
                                }
                            }

                            HStack(spacing: 12) {
                                /*
                                Button {
                                    showChallenge = true
                                } label: {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                        Text("Challenge")
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                }
                                */

                                Button(action: onDone) {
                                    Text("Done")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                    }
                }
                .safeAreaPadding(.bottom, 24)
                .responsiveContent()
                .frame(maxWidth: .infinity)
            }

            if showConfetti {
                ConfettiView()
            }
        }
        .task { await fetchRealPercentile() }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isHighIntent: true)
        }
        .onAppear { startRevealSequence() }
    }

    // MARK: - Brain Age Overlay View

    @State private var showDomainBars = false

    private var mascotRevealMood: MascotRiveMood {
        if viewModel.brainAge <= 30 { return .happy }
        if viewModel.brainAge <= 50 { return .neutral }
        return .sad
    }

    // Background gradient based on brain age
    private func revealGradient(for age: Int) -> LinearGradient {
        if age <= 25 {
            return LinearGradient(colors: [
                Color(red: 0.0, green: 0.18, blue: 0.38),
                Color(red: 0.0, green: 0.28, blue: 0.48),
                Color(red: 0.0, green: 0.12, blue: 0.25),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if age <= 40 {
            return LinearGradient(colors: [
                Color(red: 0.15, green: 0.05, blue: 0.32),
                Color(red: 0.25, green: 0.10, blue: 0.45),
                Color(red: 0.10, green: 0.04, blue: 0.20),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [
                Color(red: 0.32, green: 0.06, blue: 0.06),
                Color(red: 0.45, green: 0.12, blue: 0.08),
                Color(red: 0.18, green: 0.04, blue: 0.04),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var brainAgeOverlayView: some View {
        let finalAge = viewModel.brainAge
        let ageColor = brainAgeColor(for: countUpFinished ? finalAge : displayedBrainAge)

        return ZStack {
            // Floating orbs
            if countUpFinished {
                Circle()
                    .fill(ageColor.opacity(0.18))
                    .blur(radius: 100)
                    .frame(width: 300, height: 300)
                    .offset(x: -80, y: -120)

                Circle()
                    .fill(ageColor.opacity(pulseGlow ? 0.12 : 0.06))
                    .blur(radius: 80)
                    .frame(width: 200, height: 200)
                    .offset(x: 100, y: 80)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: pulseGlow)
            }

            // STRIPPED DOWN: mascot → number → roast → share
            VStack(spacing: 0) {
                Spacer()

                // Rive mascot
                if countUpFinished {
                    RiveMascotView(mood: mascotRevealMood, size: 140)
                        .frame(height: 120)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .padding(.bottom, 8)
                }

                // Label
                if showBrainAgeLabel {
                    Text("YOUR BRAIN AGE")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(6)
                }

                // THE NUMBER — massive
                if isCountingUp || countUpFinished {
                    Text("\(displayedBrainAge)")
                        .font(.system(size: 140, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: ageColor.opacity(0.8), radius: 40, y: 0)
                        .shadow(color: ageColor.opacity(0.4), radius: 80, y: 0)
                        .contentTransition(.numericText(value: Double(displayedBrainAge)))
                        .scaleEffect(countUpFinished ? 1.0 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: countUpFinished)
                        .minimumScaleFactor(0.5)
                        .padding(.vertical, -16)
                }

                // THE ROAST
                if showBrainAgeSubtitle {
                    Text(brainAgeVerdict(viewModel.brainAge))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))

                    if let comparison = ageComparisonText {
                        Text(comparison)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(ageColor)
                            .padding(.top, 8)
                    }
                }

                Spacer()

                // Share + continue
                if showBrainAgeShare {
                    VStack(spacing: 12) {
                        if let shareImage {
                            ShareLink(
                                item: Image(uiImage: shareImage),
                                preview: SharePreview("Brain Age: \(finalAge)", image: Image(uiImage: shareImage))
                            ) { revealShareButton(color: ageColor) }
                        } else {
                            ShareLink(item: brainAgeShareText) { revealShareButton(color: ageColor) }
                        }

                        Button { dismissBrainAgeOverlay() } label: {
                            Text("See Full Results →")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(revealGradient(for: finalAge).ignoresSafeArea())
        .onAppear { if countUpFinished { pulseGlow = true } }
        .onChange(of: countUpFinished) { _, finished in if finished { pulseGlow = true } }
    }

    private var percentileRoast: String {
        let p = viewModel.percentile
        if p >= 90 { return "Top \(100 - p)% — you're built different" }
        if p >= 70 { return "Better than \(p)% of players" }
        if p >= 50 { return "Better than \(p)%... barely above average" }
        if p >= 30 { return "Only \(p)% scored worse than you" }
        return "Bottom \(100 - p)% — there's nowhere to go but up"
    }

    private func brainAgeEmoji(_ age: Int) -> String {
        switch age {
        case ...20: return "🤯"
        case 21...25: return "🔥"
        case 26...30: return "🧠"
        case 31...35: return "😐"
        case 36...45: return "😬"
        case 46...55: return "😭"
        default: return "💀"
        }
    }

    // Domain score pill for reveal screen
    private func domainPillReveal(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // Share button that matches result color
    private func revealShareButton(color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.headline)
            Text("Share Your Brain Age")
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: color.opacity(0.4), radius: 16, y: 6)
    }

    private var brainAgeShareButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.headline)
            Text("Share Your Brain Age")
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.accent)
        .clipShape(Capsule())
        .accessibilityHint("Share your brain age on social media")
    }

    private var brainAgeShareText: String {
        "My Brain Age is \(viewModel.brainAge)! Better than \(viewModel.percentile)% of players.\n\nTest yours with Memori"
    }

    private func brainAgeVerdict(_ age: Int) -> String {
        switch age {
        case ...20: return "Your brain is actually built different"
        case 21...25: return "OK you're sharp... for now"
        case 26...30: return "Average. TikTok hasn't fully won yet"
        case 31...35: return "Your attention span left the chat"
        case 36...45: return "More screen time than brain time"
        case 46...55: return "The doomscrolling is showing"
        default: return "Your brain is rotting. Not a joke."
        }
    }

    private func brainAgeColor(for age: Int) -> Color {
        switch age {
        case ...25: return Color(red: 0, green: 0.82, blue: 0.62)       // green
        case 26...40: return Color(red: 0.25, green: 0.61, blue: 0.98)  // sky
        case 41...55: return Color(red: 1.0, green: 0.76, blue: 0.28)   // amber
        default: return Color(red: 0.98, green: 0.42, blue: 0.35)       // coral
        }
    }

    private var shareText: String {
        "My Brain Score is \(viewModel.brainScore)/1000 (Brain Age: \(viewModel.brainAge)) \u{1F9E0}\n\nI'm a \(viewModel.brainType.displayName) \u{2014} better than \(viewModel.percentile)% of players!\n\nTest yours with Memori"
    }

    private var brainTypeColor: Color {
        switch viewModel.brainType {
        case .lightningReflex: return .orange
        case .numberCruncher: return .blue
        case .patternMaster: return AppColors.violet
        case .balancedBrain: return AppColors.accent
        }
    }

    private func breakdownRow(icon: String, label: String, value: String, score: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * score / 100)
                }
            }
            .frame(width: 80, height: 8)

            Text("\(Int(score))")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value), score \(Int(score))")
    }

    // MARK: - Dismiss Brain Age Overlay

    private func dismissBrainAgeOverlay() {
        withAnimation(.easeOut(duration: 0.4)) {
            brainAgeOverlayDismissed = true
        }
        // NOW show the score card (was previously shown first — now comes after the overlay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5)) { showScore = true }
            startScoreCounter()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showType = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showConfetti = true
            SoundService.shared.playComplete()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if previousScore != nil {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showComparison = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeIn(duration: 0.4)) { showBreakdown = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.easeIn(duration: 0.3)) { showActions = true }
        }
    }

    // MARK: - Real Percentile from Leaderboard

    private func fetchRealPercentile() async {
        guard gameCenterService.isAuthenticated else { return }
        let result = await gameCenterService.loadLeaderboardEntries(
            category: .brainScore,
            timeFilter: .allTime
        )
        guard result.totalPlayerCount >= 10 else { return }
        if let localEntry = result.localPlayerEntry {
            viewModel.updatePercentileFromLeaderboard(
                rank: localEntry.rank,
                totalPlayers: result.totalPlayerCount
            )
        }
    }

    // MARK: - Reveal Sequence

    private func startRevealSequence() {
        // Report brain score to GameCenter
        if gameCenterService.isAuthenticated {
            gameCenterService.reportScore(viewModel.brainScore, leaderboardID: GameCenterService.brainScoreLeaderboard)
        }

        // Brain Age overlay comes FIRST — this is the viral moment
        SoundService.shared.playTap()
        showBrainAgeOverlay = true

        // Generate TikTok-style share card image
        let card = TikTokBrainScoreCard(
            brainScore: viewModel.brainScore,
            brainAge: viewModel.brainAge,
            brainType: viewModel.brainType,
            percentile: viewModel.percentile,
            digitScore: viewModel.digitScore,
            reactionScore: viewModel.reactionScore,
            visualScore: viewModel.visualScore,
            userAge: userAge
        )
        shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)

        // Step 1: "Your Brain Age" label fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.4)) {
                showBrainAgeLabel = true
            }
        }

        // Step 2: Start count-up after label appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            startBrainAgeCountUp(target: viewModel.brainAge)
        }
    }

    private func startBrainAgeCountUp(target: Int) {
        displayedBrainAge = 18
        isCountingUp = true
        let totalSteps = max(target - 18, 1)
        let interval = 3.0 / Double(totalSteps)
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        lightImpact.prepare()
        heavyImpact.prepare()

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            Task { @MainActor in
                if displayedBrainAge >= target {
                    timer.invalidate()
                    displayedBrainAge = target
                    // Heavy slam haptic on landing
                    heavyImpact.impactOccurred(intensity: 1.0)
                    withAnimation(.easeOut(duration: 0.3)) {
                        countUpFinished = true
                    }
                    // Mascot + verdict
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4)) {
                        showBrainAgeSubtitle = true
                    }
                    // Domain stat bars
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.9)) {
                        showDomainBars = true
                    }
                    // Percentile
                    withAnimation(.easeOut(duration: 0.4).delay(1.4)) {
                        showBrainAgePercentile = true
                    }
                    // Share + continue
                    withAnimation(.easeOut(duration: 0.4).delay(1.8)) {
                        showBrainAgeShare = true
                    }
                } else {
                    displayedBrainAge += 1
                    // Tick haptic every 3rd number
                    if (displayedBrainAge - 18) % 3 == 0 {
                        lightImpact.impactOccurred(intensity: 0.3)
                    }
                }
            }
        }
    }

    private func startScoreCounter() {
        let target = viewModel.brainScore
        let duration: Double = 2.0
        let steps = 60
        let stepDuration = duration / Double(steps)
        var currentStep = 0

        scoreTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let eased = 1.0 - pow(1.0 - progress, 3) // ease-out cubic
            let value = Int(Double(target) * eased)

            Task { @MainActor in
                displayedScore = min(value, target)
                if currentStep >= steps {
                    timer.invalidate()
                    displayedScore = target
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Brain Age Reveal — Young") {
    let vm = BrainAssessmentViewModel()
    let _ = {
        vm.brainScore = 847
        vm.brainAge = 23
        vm.brainType = .balancedBrain
        vm.percentile = 88
        vm.digitScore = 85
        vm.reactionScore = 72
        vm.visualScore = 91
    }()
    ScoreRevealView(
        viewModel: vm,
        previousScore: nil,
        userAge: 25,
        onDone: {}
    )
    .environment(StoreService())
    .environment(GameCenterService())
    .modelContainer(for: User.self, inMemory: true)
}

#Preview("Brain Age Reveal — Old") {
    let vm = BrainAssessmentViewModel()
    let _ = {
        vm.brainScore = 210
        vm.brainAge = 58
        vm.brainType = .lightningReflex
        vm.percentile = 22
        vm.digitScore = 30
        vm.reactionScore = 45
        vm.visualScore = 25
    }()
    ScoreRevealView(
        viewModel: vm,
        previousScore: nil,
        userAge: 25,
        onDone: {}
    )
    .environment(StoreService())
    .environment(GameCenterService())
    .modelContainer(for: User.self, inMemory: true)
}
