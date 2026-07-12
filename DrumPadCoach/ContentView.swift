import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var recorderVM = RecorderViewModel()
    @StateObject private var analysisVM = AnalysisViewModel()
    @StateObject private var calibrationVM = CalibrationViewModel()
    @State private var analysisData: AnalysisPayload?
    @State private var showCalibration = false
    
    var body: some View {
        TabView {
            // Practice Tab
            NavigationView {
                ScrollView {
                    VStack(spacing: 0) {
                        RecorderView(viewModel: recorderVM, showAnalysis: Binding(
                            get: { analysisData != nil },
                            set: { if !$0 { analysisData = nil } }
                        ), analysisData: Binding(
                            get: { analysisData.map { ($0.audioData, $0.sampleRate, $0.bpm, $0.timeSignature, $0.accentMode) } },
                            set: { newValue in
                                if let v = newValue {
                                    analysisData = AnalysisPayload(audioData: v.0, sampleRate: v.1, bpm: v.2, timeSignature: v.3, accentMode: v.4)
                                }
                            }
                        ), showCalibration: $showCalibration)
                    }
                }
                .navigationTitle("DrumPad 练习助手")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("练习", systemImage: "metronome.fill")
            }
            
            // History Tab
            NavigationView {
                HistoryView()
                    .navigationTitle("历史记录")
            }
            .tabItem {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }
        }
        .fullScreenCover(item: $analysisData) { data in
            AnalysisContainerView(
                viewModel: analysisVM,
                isPresented: Binding(
                    get: { analysisData != nil },
                    set: { if !$0 { analysisData = nil } }
                ),
                audioData: data.audioData,
                sampleRate: data.sampleRate,
                bpm: data.bpm,
                timeSignature: data.timeSignature,
                calibration: CalibrationStore.shared.profile,
                accentMode: data.accentMode
            )
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationView(viewModel: calibrationVM, isPresented: $showCalibration)
        }
    }
}

struct AnalysisPayload: Identifiable {
    let id = UUID()
    let audioData: [Float]
    let sampleRate: Float
    let bpm: Int
    let timeSignature: TimeSignature
    let accentMode: AccentMode
}

/// Container view that triggers analysis when appearing
struct AnalysisContainerView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    let audioData: [Float]
    let sampleRate: Float
    let bpm: Int
    let timeSignature: TimeSignature
    let calibration: CalibrationProfile?
    let accentMode: AccentMode
    
    var body: some View {
        AnalysisView(viewModel: viewModel, isPresented: $isPresented)
            .onAppear {
                viewModel.analyze(audioData: audioData, sampleRate: sampleRate,
                                  bpm: bpm, timeSignature: timeSignature,
                                  calibration: calibration,
                                  accentMode: accentMode)
            }
            .onDisappear {
                // Save to history when closing analysis
                if let result = viewModel.analysisResult {
                    let record = PracticeHistoryRecord(
                        date: Date(),
                        duration: audioData.count > 0 ? Double(audioData.count) / Double(sampleRate) : 0,
                        bpm: bpm,
                        timeSignature: timeSignature,
                        overallScore: result.overallScore,
                        timingScore: result.timingScore,
                        volumeScore: result.volumeScore,
                        hitCount: result.hits.count,
                        suggestions: result.suggestions,
                        accentMode: accentMode
                    )
                    modelContext.insert(record)
                }
                viewModel.reset()
            }
    }
}

#Preview {
    ContentView()
}
