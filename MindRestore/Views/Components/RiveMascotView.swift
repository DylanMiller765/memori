import SwiftUI
import RiveRuntime

enum MascotRiveMood: String {
    case sad = "sad"
    case happy = "happy"
    case neutral = "neutral"
}

enum MascotRivePlaybackPolicy {
    case brief
    case continuous
    case paused
}

private class MascotRiveVM: RiveViewModel {
    private(set) var dataBindingInstance: RiveDataBindingViewModel.Instance?

    var enumProperty: RiveDataBindingViewModel.Instance.EnumProperty? {
        dataBindingInstance?.enumProperty(fromPath: "posesEnum")
    }

    init() {
        super.init(fileName: "memori (1)", stateMachineName: "State Machine 1", artboardName: "Memori")
        riveModel?.enableAutoBind { [weak self] instance in
            self?.dataBindingInstance = instance
        }
    }

    func setPose(_ mood: MascotRiveMood) {
        enumProperty?.value = mood.rawValue
    }
}

struct RiveMascotView: View {
    let mood: MascotRiveMood
    let size: CGFloat
    let playbackPolicy: MascotRivePlaybackPolicy

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = MascotRiveVM()
    @State private var isVisible = false
    @State private var playbackTask: Task<Void, Never>?

    init(
        mood: MascotRiveMood,
        size: CGFloat,
        playbackPolicy: MascotRivePlaybackPolicy = .brief
    ) {
        self.mood = mood
        self.size = size
        self.playbackPolicy = playbackPolicy
    }

    var body: some View {
        viewModel.view()
            .frame(width: size, height: size)
            .onAppear {
                isVisible = true
                restartPlayback()
            }
            .onDisappear {
                isVisible = false
                stopPlayback()
            }
            .onChange(of: mood) {
                restartPlayback()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    restartPlayback()
                } else {
                    stopPlayback()
                }
            }
    }

    private func restartPlayback() {
        playbackTask?.cancel()
        guard isVisible, scenePhase == .active else {
            viewModel.pause()
            return
        }

        let requestedMood = mood
        let shouldAnimate = playbackPolicy != .paused && !reduceMotion
        if shouldAnimate {
            viewModel.play()
        } else {
            viewModel.pause()
        }

        playbackTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            viewModel.setPose(requestedMood)

            guard playbackPolicy == .brief, shouldAnimate else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, isVisible, scenePhase == .active else { return }
            viewModel.pause()
        }
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        viewModel.pause()
    }
}

#Preview("Happy") {
    RiveMascotView(mood: .happy, size: 200)
}

#Preview("Neutral") {
    RiveMascotView(mood: .neutral, size: 200)
}

#Preview("Sad") {
    RiveMascotView(mood: .sad, size: 200)
}
