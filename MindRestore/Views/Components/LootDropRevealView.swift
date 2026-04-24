import SwiftUI

struct LootDropRevealView: View {
    let item: CosmeticItemDef
    let onDismiss: () -> Void

    @State private var phase: RevealPhase = .buildup
    @State private var shimmerOffset: CGFloat = -200

    enum RevealPhase {
        case buildup
        case reveal
        case details
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95).ignoresSafeArea()

            // Rarity glow
            RadialGradient(
                colors: [item.rarity.color.opacity(phase == .buildup ? 0 : 0.3), .clear],
                center: .center,
                startRadius: 10,
                endRadius: phase == .details ? 300 : 150
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.8), value: phase)

            VStack(spacing: 0) {
                Spacer()

                // Item icon
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(item.rarity.color.opacity(phase == .buildup ? 0 : 0.15))
                        .frame(width: 160, height: 160)
                        .scaleEffect(phase == .details ? 1.2 : 0.8)

                    Circle()
                        .fill(item.rarity.color.opacity(phase == .buildup ? 0 : 0.25))
                        .frame(width: 110, height: 110)

                    Image(systemName: item.type.icon)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(phase == .buildup ? 0.3 : phase == .reveal ? 1.3 : 1.0)
                        .opacity(phase == .buildup ? 0 : 1)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: phase)

                Spacer().frame(height: 32)

                // Rarity badge
                if phase != .buildup {
                    Text(item.rarity.displayName.uppercased())
                        .font(.system(size: 12, weight: .black))
                        .tracking(3)
                        .foregroundStyle(item.rarity.color)
                        .opacity(phase == .details ? 1 : 0)
                        .offset(y: phase == .details ? 0 : 10)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: phase)
                }

                Spacer().frame(height: 8)

                // Item name
                Text(item.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(phase == .details ? 1 : 0)
                    .offset(y: phase == .details ? 0 : 15)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: phase)

                Spacer().frame(height: 6)

                // Item type
                Text(item.type.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(phase == .details ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: phase)

                Spacer()

                // Dismiss
                if phase == .details {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Collect")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(item.rarity.color, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            // Buildup → reveal → details
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { phase = .reveal }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { phase = .details }
                HapticService.complete()
            }
        }
        .onTapGesture {
            if phase == .details {
                onDismiss()
            } else {
                // Skip to details on tap
                withAnimation { phase = .details }
            }
        }
    }
}
