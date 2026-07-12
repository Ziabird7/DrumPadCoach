import SwiftUI

struct RecorderView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @Binding var showAnalysis: Bool
    @Binding var analysisData: ([Float], Float, Int, TimeSignature, AccentMode)?
    @Binding var showCalibration: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Calibration Status Bar
            calibrationStatusBar
            
            // Metronome Controls
            MetronomeView(viewModel: viewModel.metronomeVM)
            
            Divider()
            
            // Recording Section
            VStack(spacing: 16) {
                // Recording Status
                HStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .opacity(viewModel.isRecording ? (sin(Date().timeIntervalSince1970 * 3) > 0 ? 1 : 0.3) : 1)
                    
                    Text(viewModel.isRecording ? "录音中" : "准备就绪")
                        .font(.headline)
                        .foregroundStyle(viewModel.isRecording ? .red : .secondary)
                    
                    Spacer()
                    
                    Text(viewModel.formatDuration(viewModel.recordingDuration))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(viewModel.isRecording ? .red : .primary)
                }
                .padding(.horizontal)
                
                // Audio Level Meter
                AudioLevelMeter(level: viewModel.currentLevels, isActive: viewModel.isRecording)
                    .frame(height: 40)
                    .padding(.horizontal)
                
                // Live Waveform Display during recording
                if viewModel.isRecording {
                    LiveWaveformView(samples: viewModel.liveSamples)
                        .frame(height: 80)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                // Practice Button
                HStack(spacing: 16) {
                    if !viewModel.isRecording {
                        Button {
                            viewModel.startPractice()
                        } label: {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("开始练习")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    } else {
                        Button {
                            viewModel.stopPractice()
                        } label: {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("停止并分析")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Analyze Button
                if viewModel.hasRecording && !viewModel.isRecording {
                    Button {
                        analysisData = (viewModel.recordedAudioData, viewModel.recordedSampleRate,
                                       viewModel.bpm, viewModel.timeSignature, viewModel.metronomeVM.accentMode)
                        showAnalysis = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.doc.fill")
                            Text("查看分析结果")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .alert("麦克风权限", isPresented: $viewModel.showingPermissionAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("请在设置中允许此应用使用麦克风以录制您的练习音频")
        }
        .onAppear {
            viewModel.requestMicPermission()
        }
    }
    
    // MARK: - Calibration Status Bar
    @ViewBuilder
    private var calibrationStatusBar: some View {
        let profile = CalibrationStore.shared.profile
        
        Button {
            showCalibration = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: profile?.isValid == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(profile?.isValid == true ? .green : .orange)
                    .font(.caption)
                
                if let profile = profile, profile.isValid {
                    Text("已校准 · 左右手比率 \(String(format: "%.2f", profile.volumeRatio))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("未校准 · 点击进行左右手音量校准")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .disabled(viewModel.isRecording)
    }
}

/// Live waveform display during recording
struct LiveWaveformView: View {
    let samples: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                
                if !samples.isEmpty {
                    WaveformShape(samples: samples, hitMarkers: [])
                        .fill(Color.green.opacity(0.7))
                }
                
                // Center line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
        }
    }
}

/// Audio level meter visualization
struct AudioLevelMeter: View {
    let level: Float
    let isActive: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                
                // Level bar
                RoundedRectangle(cornerRadius: 6)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(min(level * 10, 1.0)))
                    .animation(.easeOut(duration: 0.1), value: level)
                
                // Scale marks
                HStack {
                    ForEach(0..<10) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var levelColor: LinearGradient {
        LinearGradient(
            colors: [.green, .yellow, .orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
