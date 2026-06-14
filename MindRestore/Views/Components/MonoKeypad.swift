import SwiftUI
import UIKit

// MARK: - Mono Keypad
//
// Custom 0–9 keypad styled to match the v2 onboarding system. Used by Number
// Memory in the brain age assessment, and reused by exercise games (Number
// Memory full game, Math Speed, Chunking) instead of the iOS system numberPad.
//
// Why custom over system numberPad:
// - No iOS keyboard slide-up animation (faster, cleaner UX in games)
// - Bigger tap targets sized for thumb use
// - Mono digits + dark surface tokens match the brand
// - Submit button is part of the keypad, not a separate floating CTA
// - Consistent across the assessment and the in-app games

struct MonoKeypad: View {
    @Binding var input: String

    /// Optional cap. When set, additional digits are blocked once `input.count`
    /// reaches `maxLength`, and the Submit button only enables when full.
    /// When nil, any length is allowed and Submit enables on first digit.
    var maxLength: Int?

    /// Tap handler for Submit (✓). When nil, the Submit slot renders as empty.
    var onSubmit: (() -> Void)?

    /// Override for Submit-enabled state. Defaults to maxLength match (or
    /// non-empty input if no maxLength). Useful for math games where the
    /// submit condition is "any input + user explicitly hits ✓".
    var submitEnabled: Bool?

    init(
        input: Binding<String>,
        maxLength: Int? = nil,
        submitEnabled: Bool? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self._input = input
        self.maxLength = maxLength
        self.submitEnabled = submitEnabled
        self.onSubmit = onSubmit
    }

    private var canSubmit: Bool {
        if let submitEnabled { return submitEnabled }
        if let maxLength { return input.count == maxLength }
        return !input.isEmpty
    }

    private var canAppend: Bool {
        if let maxLength { return input.count < maxLength }
        return true
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) { ForEach(1...3, id: \.self) { digitButton($0) } }
            HStack(spacing: 12) { ForEach(4...6, id: \.self) { digitButton($0) } }
            HStack(spacing: 12) { ForEach(7...9, id: \.self) { digitButton($0) } }
            HStack(spacing: 12) {
                deleteButton
                digitButton(0)
                if onSubmit != nil {
                    submitButton
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                }
            }
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            append(digit)
        } label: {
            Text("\(digit)")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!canAppend)
        .opacity(canAppend ? 1 : 0.5)
    }

    private var deleteButton: some View {
        Button {
            delete()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(input.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(input.isEmpty)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(canSubmit ? .white : AppColors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canSubmit ? AppColors.accent : AppColors.cardSurface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(canSubmit ? AppColors.accent : AppColors.cardBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    private func append(_ digit: Int) {
        guard canAppend else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        input.append(String(digit))
    }

    private func delete() {
        guard !input.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        input.removeLast()
    }

    private func submit() {
        guard canSubmit, let onSubmit else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSubmit()
    }
}

// MARK: - Display Slots
//
// Helper for fixed-length numeric inputs (e.g. digit span). Renders one slot
// per expected character: filled with the typed digit + accent fill, or empty
// with a faint border. Pair with MonoKeypad(maxLength:) above the keypad.

struct MonoKeypadSlots: View {
    let input: String
    let length: Int

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<length, id: \.self) { index in
                slot(at: index)
            }
        }
    }

    private func slot(at index: Int) -> some View {
        let typed = index < input.count
        let char: String
        if typed {
            let stringIndex = input.index(input.startIndex, offsetBy: index)
            char = String(input[stringIndex])
        } else {
            char = ""
        }
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(typed ? AppColors.accent.opacity(0.18) : Color.gray.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(typed ? AppColors.accent.opacity(0.6) : AppColors.cardBorder, lineWidth: 1.2)
                )
            Text(char)
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.accent)
        }
        .frame(width: 38, height: 50)
    }
}

#if DEBUG
#Preview("Fixed length (digit span)") {
    @Previewable @State var input = ""
    return VStack(spacing: 20) {
        MonoKeypadSlots(input: input, length: 6)
        MonoKeypad(input: $input, maxLength: 6, onSubmit: { print("submit \(input)") })
    }
    .padding()
    .background(AppColors.pageBg)
    .preferredColorScheme(.dark)
}

#Preview("Free length (math)") {
    @Previewable @State var input = ""
    return VStack(spacing: 20) {
        Text(input.isEmpty ? "—" : input)
            .font(.system(size: 60, weight: .heavy, design: .monospaced))
            .foregroundStyle(AppColors.accent)
        MonoKeypad(input: $input, onSubmit: { print("answer \(input)") })
    }
    .padding()
    .background(AppColors.pageBg)
    .preferredColorScheme(.dark)
}
#endif
