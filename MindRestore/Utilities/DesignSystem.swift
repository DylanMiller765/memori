import SwiftUI

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case light, dark, system

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - App Colors
// Premium Game Board — warm light bg, clean cards, muted game colors
// Inspired by: NYT Games cleanliness + Apple friendliness + competitive energy

enum AppColors {
    // Adaptive base — cream in light, dark in dark mode
    static let pageBg = Color("PageBg", bundle: nil)
    static let cardSurface = Color("CardSurface", bundle: nil)
    static let cardElevated = Color("CardElevated", bundle: nil)
    static let cardBorder = Color("CardBorder", bundle: nil)
    static let cardBorderDark = Color("CardBorderDark", bundle: nil)

    // Fallbacks for when asset catalog colors aren't found
    static let pageBgLight = Color(red: 0.969, green: 0.961, blue: 0.941)   // #F7F5F0
    static let pageBgDark = Color(red: 0.039, green: 0.039, blue: 0.059)    // #0A0A0F

    // Text — use system .primary/.secondary where possible, these for explicit use
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(red: 0.62, green: 0.60, blue: 0.58)

    // Accent — rich blue (energetic, trustworthy, competitive)
    static let accent = Color(red: 0.29, green: 0.50, blue: 0.90)           // #4A7FE5

    // Functional
    static let error = Color(red: 0.85, green: 0.28, blue: 0.25)
    static let warning = Color(red: 0.90, green: 0.62, blue: 0.15)
    static let chartBlue = Color(red: 0.35, green: 0.55, blue: 0.85)

    // Per-game colors — muted, earthy, sophisticated
    static let teal = Color(red: 0.20, green: 0.60, blue: 0.56)             // sage teal
    static let indigo = Color(red: 0.38, green: 0.36, blue: 0.70)           // muted indigo
    static let coral = Color(red: 0.85, green: 0.40, blue: 0.35)            // dusty coral
    static let violet = Color(red: 0.55, green: 0.38, blue: 0.75)           // dusty violet
    static let sky = Color(red: 0.35, green: 0.58, blue: 0.82)              // slate blue
    static let mint = Color(red: 0.25, green: 0.68, blue: 0.55)             // sage green
    static let rose = Color(red: 0.78, green: 0.35, blue: 0.48)             // dusty rose
    static let amber = Color(red: 0.85, green: 0.65, blue: 0.25)            // warm amber

    // Gradients — subtle warm gradient for premium feel
    static let accentGradient = LinearGradient(
        colors: [accent, Color(red: 0.35, green: 0.55, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let premiumGradient = LinearGradient(
        colors: [accent, Color(red: 0.22, green: 0.42, blue: 0.82)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = accentGradient
    static let coolGradient = accentGradient

    static let neuralGradient = LinearGradient(
        colors: [accent, accent.opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - App Card Modifier (white card, subtle shadow, 14pt radius)

struct AppCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: colorScheme == .dark ? 4 : 8, y: 2)
            }
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardModifier(padding: padding))
    }

    func pageBackground() -> some View {
        self.background(AppColors.pageBg.ignoresSafeArea())
    }

    func glowingCard(color: Color, intensity: Double = 0.15) -> some View {
        modifier(GlowingCardModifier(color: color, intensity: intensity))
    }

    func heroCard(color: Color) -> some View {
        modifier(HeroCardModifier(color: color))
    }

    /// Constrains content to a readable max width on iPad while staying full-width on iPhone.
    func responsiveContent(maxWidth: CGFloat = 680) -> some View {
        self.frame(maxWidth: maxWidth)
    }
}

struct GlowingCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let color: Color
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: colorScheme == .dark ? 4 : 8, y: 2)
            }
    }
}

struct HeroCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: colorScheme == .dark ? 4 : 12, y: 4)
            }
    }
}

// MARK: - Accent Button Style (rounded, slight depth/press effect)

struct AccentButtonStyle: ViewModifier {
    var color: Color = AppColors.accent

    func body(content: Content) -> some View {
        content
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .foregroundStyle(.white)
    }
}

extension View {
    func accentButton(color: Color = AppColors.accent) -> some View {
        modifier(AccentButtonStyle(color: color))
    }
}

// MARK: - Gradient Accent Button

struct GradientButtonStyle: ViewModifier {
    var gradient: LinearGradient = AppColors.accentGradient

    func body(content: Content) -> some View {
        content
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .foregroundStyle(.white)
    }
}

extension View {
    func gradientButton(_ gradient: LinearGradient = AppColors.accentGradient) -> some View {
        modifier(GradientButtonStyle(gradient: gradient))
    }
}

// MARK: - Section Header (clean, subtle)

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.textSecondary)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Colored Icon Badge

struct ColoredIconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.22))
    }
}

// MARK: - Cognitive Domain

enum CognitiveDomain: String, CaseIterable, Identifiable {
    case memory, speed, attention, flexibility, problemSolving

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .memory: return "Memory"
        case .speed: return "Speed"
        case .attention: return "Attention"
        case .flexibility: return "Flexibility"
        case .problemSolving: return "Problem Solving"
        }
    }

    var color: Color {
        switch self {
        case .memory: return AppColors.violet
        case .speed: return AppColors.coral
        case .attention: return AppColors.sky
        case .flexibility: return AppColors.teal
        case .problemSolving: return AppColors.amber
        }
    }

    var icon: String {
        switch self {
        case .memory: return "brain.head.profile"
        case .speed: return "bolt.fill"
        case .attention: return "eye.fill"
        case .flexibility: return "arrow.triangle.branch"
        case .problemSolving: return "puzzlepiece.fill"
        }
    }
}

// MARK: - Streak Week Calendar

struct StreakWeekView: View {
    let sessions: [Date]
    let currentStreak: Int

    private var weekDays: [(String, Date, Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0) })

        return (-6...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let dayStr = date.formatted(.dateTime.weekday(.narrow))
            let completed = sessionDays.contains(date)
            return (dayStr, date, completed)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.1) { day, date, completed in
                VStack(spacing: 6) {
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    ZStack {
                        Circle()
                            .fill(completed ? AppColors.accent : AppColors.cardBorder.opacity(0.5))
                            .frame(width: 30, height: 30)

                        if completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        if Calendar.current.isDateInToday(date) && !completed {
                            Circle()
                                .stroke(AppColors.accent, lineWidth: 2)
                                .frame(width: 34, height: 34)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Staggered Animation Modifier

struct StaggeredEntrance: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredEntrance(index: Int) -> some View {
        modifier(StaggeredEntrance(index: index))
    }
}

// MARK: - Cognitive Domain Bar

struct CognitiveDomainBar: View {
    let label: String
    let value: Double // 0-100
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(color)

            ProgressView(value: value, total: 100)
                .tint(color)
                .scaleEffect(y: 0.8)

            Text("\(Int(value))%")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Streak Ring

struct StreakRingView: View {
    let current: Int
    let goal: Int
    var lineWidth: CGFloat = 12
    var size: CGFloat = 120

    private var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(CGFloat(current) / CGFloat(goal), 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.cardBorder, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AppColors.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                Text(current == 1 ? "day" : "days")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}
