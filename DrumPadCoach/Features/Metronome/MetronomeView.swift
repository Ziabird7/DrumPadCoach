import SwiftUI

struct MetronomeView: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @State private var showAccentDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                bpmDisplay
                bpmControls
                bpmSlider
                beatIndicators
                    .padding(.vertical, 8)
                settingsSection
                accentModeSection
                playStopButton
                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    // MARK: - BPM Display

    private var bpmDisplay: some View {
        VStack(spacing: 8) {
            Text("\(viewModel.bpm)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(viewModel.isPlaying ? .orange : .primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: viewModel.bpm)

            Text("BPM")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - BPM Controls

    private var bpmControls: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.decreaseBPM(by: 10)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }

            Button {
                viewModel.decreaseBPM()
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }

            Button {
                viewModel.increaseBPM()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }

            Button {
                viewModel.increaseBPM(by: 10)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }
        }
    }

    private var bpmSlider: some View {
        Slider(
            value: Binding(
                get: { Double(viewModel.bpm) },
                set: { viewModel.bpm = Int($0) }
            ),
            in: 40...240,
            step: 1
        ) {
            Text("BPM")
        }
        .tint(.orange)
        .padding(.horizontal)
    }

    // MARK: - Beat Indicators

    private var beatIndicators: some View {
        let beatsPerMeasure = viewModel.timeSignature.beatsPerMeasure
        return HStack(spacing: 12) {
            ForEach(0..<beatsPerMeasure, id: \.self) { beat in
                let volume = viewModel.accentMode.volumeLevel(for: beat, beatsPerMeasure: beatsPerMeasure)
                let isActive = beat == viewModel.currentBeat && viewModel.isPlaying
                beatIndicator(for: beat, volume: volume, isActive: isActive)
            }
        }
    }

    private func beatIndicator(for beat: Int, volume: BeatVolumeLevel, isActive: Bool) -> some View {
        let size: CGFloat
        let fillColor: Color
        let label: String

        switch volume {
        case .accent:
            size = 36
            fillColor = isActive ? .orange : .orange.opacity(0.3)
            label = "\(beat + 1)"
        case .normal:
            size = 28
            fillColor = isActive ? .blue : .gray.opacity(0.3)
            label = "\(beat + 1)"
        case .soft:
            size = 22
            fillColor = isActive ? .gray : .gray.opacity(0.2)
            label = "\(beat + 1)"
        }

        return Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
            .animation(.spring(response: 0.2), value: viewModel.currentBeat)
            .overlay(
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isActive ? .white : .secondary)
            )
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 12) {
            Picker("Time Signature", selection: $viewModel.timeSignature) {
                ForEach(TimeSignature.allCases, id: \.self) { ts in
                    Text(ts.rawValue).tag(ts)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            Picker("Subdivisions", selection: $viewModel.subdivisions) {
                Text("1/4").tag(1)
                Text("1/8").tag(2)
                Text("1/16").tag(4)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
    }

    // MARK: - Accent Mode Section

    private var accentModeSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Accent Mode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showAccentDetail.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AccentMode.allCases, id: \.self) { mode in
                        accentModeChip(mode: mode)
                    }
                }
                .padding(.horizontal, 2)
            }

            Text(viewModel.accentMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.accentMode)
        }
        .padding(.horizontal, 4)
        .popover(isPresented: $showAccentDetail) {
            accentModeDetailPopover
        }
    }

    private func accentModeChip(mode: AccentMode) -> some View {
        let isSelected = viewModel.accentMode == mode

        return Button {
            viewModel.accentMode = mode
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.iconName)
                    .font(.caption)

                Text(mode.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var accentModeDetailPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accent Modes")
                .font(.headline)

            ForEach(AccentMode.allCases, id: \.self) { mode in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: mode.iconName)
                            .foregroundStyle(.accentColor)
                            .frame(width: 20)

                        Text(mode.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Play/Stop

    private var playStopButton: some View {
        Button {
            viewModel.togglePlay()
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isPlaying ? Color.red : Color.green)
                    .frame(width: 80, height: 80)
                    .shadow(color: (viewModel.isPlaying ? .red : .green).opacity(0.4), radius: 8, y: 4)

                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MetronomeView(viewModel: MetronomeViewModel())
}
