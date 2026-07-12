import SwiftUI

struct CalibrationView: View {
    @ObservedObject var viewModel: CalibrationViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: viewModel.progress)
                    .tint(.blue)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Step content
                Group {
                    switch viewModel.currentStep {
                    case .intro:
                        introStep
                    case .leftHand, .rightHand:
                        handRecordingStep
                    case .result:
                        resultStep
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("音量校准")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Intro Step
    @ViewBuilder
    private var introStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            VStack(spacing: 12) {
                Text("为什么要校准？")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("由于手机麦克风距离左右手的位置不同，即使你用相同的力度敲击，录音中两只手的音量也会有差异。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("校准可以帮助你获得更准确的左右手力度分析结果。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                // Show existing calibration if present
                if let existing = viewModel.existingProfile {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("已有校准数据（\(existing.calibratedAt.formatted(date: .abbreviated, time: .shortened))）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)
                }
                
                Button {
                    viewModel.currentStep = .leftHand
                } label: {
                    Text("开始校准")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                if viewModel.existingProfile != nil {
                    Button {
                        isPresented = false
                    } label: {
                        Text("使用已有校准")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                
                Button {
                    viewModel.skipCalibration()
                    isPresented = false
                } label: {
                    Text("跳过校准")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Hand Recording Step
    @ViewBuilder
    private var handRecordingStep: some View {
        VStack(spacing: 20) {
            // Hand indicator
            VStack(spacing: 12) {
                Text(viewModel.currentStep == .leftHand ? "👈" : "👉")
                    .font(.system(size: 56))
                
                Text("\(viewModel.handName)校准")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("请用\(viewModel.handName)以自然力度敲击哑鼓垫")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Text("建议敲击 \(viewModel.targetTaps) 次以上")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Live level meter
            AudioLevelMeter(level: viewModel.currentLevel, isActive: viewModel.isRecording)
                .frame(height: 32)
                .padding(.horizontal)
            
            // Live waveform
            if viewModel.isRecording && !viewModel.liveSamples.isEmpty {
                LiveWaveformView(samples: viewModel.liveSamples)
                    .frame(height: 60)
                    .padding(.horizontal)
            }
            
            // Tap count
            if viewModel.isRecording {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(.blue)
                    Text("检测到 \(viewModel.detectedTapCount) 次敲击")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Control button
            if !viewModel.isRecording {
                Button {
                    viewModel.startHandRecording()
                } label: {
                    HStack {
                        Image(systemName: "record.circle.fill")
                        Text("开始录音")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                }
            } else {
                Button {
                    viewModel.stopHandRecording()
                } label: {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                        Text("停止（已录 \(viewModel.detectedTapCount) 次）")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .disabled(viewModel.detectedTapCount < 3)
                
                if viewModel.detectedTapCount < 3 {
                    Text("至少需要检测到 3 次敲击")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            // Retry hint
            if !viewModel.isRecording && viewModel.detectedTapCount > 0 && viewModel.detectedTapCount < 3 {
                Text("检测到 \(viewModel.detectedTapCount) 次，不足 3 次。请重试")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    // MARK: - Result Step
    @ViewBuilder
    private var resultStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            
            Text("校准完成！")
                .font(.title2)
                .fontWeight(.bold)
            
            if let profile = viewModel.calibrationProfile {
                VStack(spacing: 16) {
                    // Left hand stats
                    CalibrationStatRow(
                        hand: "左手",
                        icon: "👈",
                        avgVolume: profile.leftHandAvgVolume,
                        stdDev: profile.leftHandStdDev,
                        count: viewModel.leftHandProfile?.count ?? 0
                    )
                    
                    // Right hand stats
                    CalibrationStatRow(
                        hand: "右手",
                        icon: "👉",
                        avgVolume: profile.rightHandAvgVolume,
                        stdDev: profile.rightHandStdDev,
                        count: viewModel.rightHandProfile?.count ?? 0
                    )
                    
                    Divider()
                    
                    // Volume ratio
                    HStack {
                        Text("音量比率")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f", profile.volumeRatio))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("校正系数")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("左手 ×\(String(format: "%.2f", profile.leftHandNormFactor))  右手 ×\(String(format: "%.2f", profile.rightHandNormFactor))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if abs(profile.volumeRatio - 1.0) > 0.2 {
                        Text("检测到左右手录音音量存在明显差异，分析时会自动校正")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    viewModel.reset()
                } label: {
                    Text("重新校准")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Text("完成")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
}

/// Displays calibration stats for one hand
struct CalibrationStatRow: View {
    let hand: String
    let icon: String
    let avgVolume: Float
    let stdDev: Float
    let count: Int
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hand)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(count) 次敲击")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("均值: \(String(format: "%.3f", avgVolume))")
                    .font(.caption)
                Text("标准差: \(String(format: "%.3f", stdDev))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
