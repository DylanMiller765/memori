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

enum AppColors {
    static let accent = Color(red: 0.18, green: 0.49, blue: 0.20)
    static let error = Color(red: 0.94, green: 0.33, blue: 0.31)
    static let warning = Color(red: 1.0, green: 0.65, blue: 0.15)
}

// MARK: - App Card Modifier

struct AppCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardModifier(padding: padding))
    }

    func pageBackground() -> some View {
        self.background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Accent Button Style

struct AccentButtonStyle: ViewModifier {
    var color: Color = AppColors.accent

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
    }
}

extension View {
    func accentButton(color: Color = AppColors.accent) -> some View {
        modifier(AccentButtonStyle(color: color))
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
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
                .stroke(AppColors.accent.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                Text(current == 1 ? "day" : "days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
