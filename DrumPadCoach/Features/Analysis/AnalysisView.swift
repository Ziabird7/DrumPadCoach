import SwiftUI

struct AnalysisView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let result = viewModel.analysisResult {
                    VStack(spacing: 24) {
                        // Score Section
                        scoreSection(result)
                        
                        // Waveform Section
                        waveformSection
                        
                        // Timing Analysis
                        timingSection(result)
                        
                        // Volume Analysis
                        volumeSection(result)
                        
                        // Suggestions
                        suggestionsSection(result)
                    }
                    .padding()
                } else if viewModel.isAnalyzing {
                    ProgressView("分析中...")
                        .padding()
                } else {
                    ContentUnavailableView("无数据", systemImage: "chart.bar",
                                          description: Text("请先进行练习录音"))
                }
            }
            .navigationTitle("分析结果")
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
    
    // MARK: - Score Section
    @ViewBuilder
    private func scoreSection(_ result: AnalysisResult) -> some View {
        VStack(spacing: 16) {
            // Overall Score
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(result.overallScore) / 100.0)
                    .stroke(scoreColor(result.overallScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(result.overallScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("综合")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Sub scores
            HStack(spacing: 32) {
                ScoreBadge(title: "时值", score: result.timingScore, icon: "clock.fill")
                ScoreBadge(title: "音量", score: result.volumeScore, icon: "speaker.wave.2.fill")
            }
            
            Text("\(result.isCalibrated ? "✅ 已校准" : "⚠️ 未校准")")
                .font(.caption)
                .foregroundStyle(result.isCalibrated ? .green : .orange)
            
            // Accent mode badge
            HStack(spacing: 6) {
                Image(systemName: result.accentMode.iconName)
                    .font(.caption2)
                Text("重音模式: \(result.accentMode.displayName)")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            
            Text("检测到 \(result.hits.count) 次击打")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    // MARK: - Waveform Section
    @ViewBuilder
    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("波形图", systemImage: "waveform")
                .font(.headline)
            
            WaveformView(samples: viewModel.audioData, hits: viewModel.hits, sampleRate: viewModel.sampleRate)
            
            Text("红色标记为检测到的击打位置")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    // MARK: - Timing Section
    @ViewBuilder
    private func timingSection(_ result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("时值分析", systemImage: "clock.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("平均偏差: \(String(format: "%.1f", result.averageTimingDeviation * 1000))ms")
                Text("最大偏差: \(String(format: "%.1f", result.maxTimingDeviation * 1000))ms")
                Text("标准差: \(String(format: "%.1f", result.timingStdDev * 1000))ms")
                
                // Early/Late hit summary
                if !result.earlyHitIndices.isEmpty || !result.lateHitIndices.isEmpty {
                    HStack(spacing: 12) {
                        if !result.earlyHitIndices.isEmpty {
                            Label("\(result.earlyHitIndices.count)拍偏快", systemImage: "arrow.left")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        if !result.lateHitIndices.isEmpty {
                            Label("\(result.lateHitIndices.count)拍偏慢", systemImage: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .font(.subheadline)
            
            // Timing intervals bar chart
            if !result.timingIntervals.isEmpty {
                Text("击打间隔分布")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TimingBarChart(
                    intervals: result.timingIntervals.map { $0 * 1000 },
                    expectedInterval: result.expectedInterval * 1000
                )
                .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    // MARK: - Volume Section
    @ViewBuilder
    private func volumeSection(_ result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("音量分析", systemImage: "speaker.wave.2.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("平均音量: \(String(format: "%.3f", result.averageVolume))")
                
                if result.hasMixedAccentLevels {
                    Text("组内变异系数: \(String(format: "%.2f", result.accentAwareVolumeCV))")
                        .foregroundStyle(.secondary)
                    Text("原始变异系数: \(String(format: "%.2f", result.volumeCV))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("变异系数: \(String(format: "%.2f", result.volumeCV))")
                }
                
                // Volume outlier summary
                if !result.loudHitIndices.isEmpty || !result.quietHitIndices.isEmpty {
                    HStack(spacing: 12) {
                        if !result.loudHitIndices.isEmpty {
                            Label("\(result.loudHitIndices.count)拍偏高", systemImage: "arrow.up")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if !result.quietHitIndices.isEmpty {
                            Label("\(result.quietHitIndices.count)拍偏低", systemImage: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .font(.subheadline)
            
            // Volume bar chart
            if !result.volumes.isEmpty {
                Text("击打音量分布")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                VolumeBarChart(
                    volumes: result.volumes,
                    loudIndices: Set(result.loudHitIndices),
                    quietIndices: Set(result.quietHitIndices)
                )
                .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    // MARK: - Suggestions Section
    @ViewBuilder
    private func suggestionsSection(_ result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("练习建议", systemImage: "lightbulb.fill")
                .font(.headline)
            
            ForEach(Array(result.suggestions.enumerated()), id: \.offset) { _, suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .padding(.top, 2)
                    
                    Text(suggestion)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        if score >= 50 { return .orange }
        return .red
    }
}

// MARK: - Supporting Views

struct ScoreBadge: View {
    let title: String
    let score: Int
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(scoreColor(score))
            
            Text("\(score)")
                .font(.system(.title2, design: .rounded, weight: .bold))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 80)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        if score >= 50 { return .orange }
        return .red
    }
}

struct TimingBarChart: View {
    let intervals: [Double]  // in milliseconds
    let expectedInterval: Double
    
    var body: some View {
        GeometryReader { geometry in
            let maxInterval = max(intervals.max() ?? expectedInterval, expectedInterval * 1.5)
            let barWidth = geometry.size.width / CGFloat(intervals.count + 1)
            
            ZStack(alignment: .bottom) {
                // Expected interval line
                let expectedY = geometry.size.height * CGFloat(1 - expectedInterval / maxInterval)
                Rectangle()
                    .fill(Color.green.opacity(0.5))
                    .frame(height: 2)
                    .offset(y: -expectedY)
                
                // Bars
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(intervals.enumerated()), id: \.offset) { index, interval in
                        VStack(spacing: 2) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(interval))
                                .frame(
                                    width: barWidth - 4,
                                    height: geometry.size.height * CGFloat(interval / maxInterval)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func barColor(_ interval: Double) -> Color {
        let deviation = abs(interval - expectedInterval) / expectedInterval
        if deviation < 0.1 { return .green }
        if deviation < 0.2 { return .yellow }
        return .orange
    }
}

struct VolumeBarChart: View {
    let volumes: [Float]
    let loudIndices: Set<Int>
    let quietIndices: Set<Int>
    
    init(volumes: [Float], loudIndices: Set<Int> = [], quietIndices: Set<Int> = []) {
        self.volumes = volumes
        self.loudIndices = loudIndices
        self.quietIndices = quietIndices
    }
    
    var body: some View {
        GeometryReader { geometry in
            let maxVolume = volumes.max() ?? 1.0
            let barWidth = geometry.size.width / CGFloat(volumes.count + 1)
            let avgVolume = volumes.reduce(0, +) / Float(volumes.count)
            
            ZStack(alignment: .bottom) {
                // Average line
                let avgY = geometry.size.height * CGFloat(avgVolume / maxVolume)
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(height: 2)
                    .offset(y: -avgY)
                
                // Bars
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(volumes.enumerated()), id: \.offset) { index, volume in
                        VStack(spacing: 2) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(volumeBarColor(volume, index: index, avg: avgVolume))
                                .frame(
                                    width: barWidth - 4,
                                    height: geometry.size.height * CGFloat(volume / maxVolume)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func volumeBarColor(_ volume: Float, index: Int, avg: Float) -> Color {
        if loudIndices.contains(index) { return .red.opacity(0.8) }
        if quietIndices.contains(index) { return .blue.opacity(0.8) }
        let deviation = abs(volume - avg) / avg
        if deviation < 0.15 { return .blue }
        if deviation < 0.3 { return .yellow }
        return .orange
    }
}
