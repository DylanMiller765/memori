import SwiftUI
import RiveRuntime

struct RiveMascotView: View {
    let brainScore: Int
    let brainAge: Int
    let size: CGFloat

    @State private var riveFailed = false
    @State private var debugText = "loading..."

    @StateObject private var viewModel: RiveViewModel = {
        let vm = RiveViewModel(fileName: "memori_mascot", stateMachineName: "BrainHealth")
        return vm
    }()

    private var healthValue: Double {
        Double(max(0, min(1000, brainScore))) / 10.0
    }

    var body: some View {
        Group {
            if riveFailed {
                MascotStateView(brainScore: brainScore, brainAge: brainAge, size: size)
            } else {
                VStack(spacing: 2) {
                    viewModel.view()
                        .frame(width: size, height: size)
                        .background(Color.red.opacity(0.1)) // debug: see the actual frame
                        .onAppear {
                            debugText = "appeared, health=\(healthValue)"
                            do {
                                try viewModel.setInput("health", value: healthValue)
                                debugText = "health set OK"
                            } catch {
                                debugText = "ERR: \(error.localizedDescription)"
                                riveFailed = true
                            }
                        }
                        .onChange(of: brainScore) { _, newScore in
                            try? viewModel.setInput("health", value: Double(max(0, min(1000, newScore))) / 10.0)
                        }

                    // Debug overlay — remove after fixing
                    Text(debugText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RiveMascotView(brainScore: 900, brainAge: 20, size: 200)
    }
}
