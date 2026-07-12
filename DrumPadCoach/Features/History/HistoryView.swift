import SwiftUI
import SwiftData

/// SwiftData model for persisting practice history
@Model
class PracticeHistoryRecord {
    var date: Date
    var duration: TimeInterval
    var bpm: Int
    var timeSignatureRaw: String
    var overallScore: Int
    var timingScore: Int
    var volumeScore: Int
    var hitCount: Int
    var suggestions: [String]
    var accentModeRaw: String
    
    init(date: Date, duration: TimeInterval, bpm: Int, timeSignature: TimeSignature,
         overallScore: Int, timingScore: Int, volumeScore: Int, hitCount: Int, suggestions: [String],
         accentMode: AccentMode = .downbeat) {
        self.date = date
        self.duration = duration
        self.bpm = bpm
        self.timeSignatureRaw = timeSignature.rawValue
        self.overallScore = overallScore
        self.timingScore = timingScore
        self.volumeScore = volumeScore
        self.hitCount = hitCount
        self.suggestions = suggestions
        self.accentModeRaw = accentMode.rawValue
    }
    
    var timeSignature: TimeSignature {
        TimeSignature(rawValue: timeSignatureRaw) ?? .fourFour
    }
    
    var accentMode: AccentMode {
        AccentMode(rawValue: accentModeRaw) ?? .downbeat
    }
}

struct HistoryView: View {
    @Query(sort: \PracticeHistoryRecord.date, order: .reverse) private var records: [PracticeHistoryRecord]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("完成一次练习后，记录将显示在这里")
                )
            } else {
                List {
                    ForEach(records) { record in
                        HistoryRowView(record: record)
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

struct HistoryRowView: View {
    let record: PracticeHistoryRecord
    
    var body: some View {
        HStack(spacing: 16) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(scoreColor, lineWidth: 3)
                    .frame(width: 48, height: 48)
                
                Text("\(record.overallScore)")
                    .font(.system(.headline, design: .rounded))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date, format: .dateTime.month().day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    Label("\(record.bpm) BPM", systemImage: "metronome")
                    Label(record.timeSignatureRaw, systemImage: "music.note")
                    Label(record.accentMode.displayName, systemImage: record.accentMode.iconName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Text("时值 \(record.timingScore)")
                    Text("音量 \(record.volumeScore)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(formatDuration(record.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var scoreColor: Color {
        if record.overallScore >= 85 { return .green }
        if record.overallScore >= 70 { return .yellow }
        if record.overallScore >= 50 { return .orange }
        return .red
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
