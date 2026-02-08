import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // App header
                    VStack(spacing: 8) {
                        Image(systemName: "metronome.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                        Text("ScorePulse")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Advanced Metronome for Musicians")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Features section
                    SectionHeader(title: "Features")
                    
                    FeatureRow(
                        icon: "metronome",
                        title: "Simple Metronome",
                        description: "Adjustable BPM, multiple time signatures, quarter and eighth note subdivisions"
                    )
                    
                    FeatureRow(
                        icon: "music.note.list",
                        title: "Score Playback",
                        description: "Follow along with changing time signatures and tempi throughout a piece"
                    )
                    
                    FeatureRow(
                        icon: "arrow.up.right",
                        title: "Tempo Transitions",
                        description: "Gradual accelerando and ritardando between tempo changes"
                    )
                    
                    FeatureRow(
                        icon: "repeat",
                        title: "Rehearsal Mode",
                        description: "Practice specific passages with automatic return to start position"
                    )
                    
                    FeatureRow(
                        icon: "hand.raised",
                        title: "Count-in",
                        description: "One bar count-in before playback starts"
                    )
                    
                    FeatureRow(
                        icon: "square.and.arrow.down",
                        title: "Import Scores",
                        description: "Import .scorepulse files or create them from CSV spreadsheets"
                    )
                    
                    // Time signatures section
                    SectionHeader(title: "Supported Time Signatures")
                    
                    Text("Simple meters (4/4, 3/4, 2/4, 5/4), compound meters (6/8, 9/8, 12/8), and irregular meters with custom accent patterns (5/8, 7/8, 11/16, etc.)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // File format section
                    SectionHeader(title: "Score File Format")
                    
                    Text("Scores are .scorepulse files (JSON format). Import them via the + button in the Scores tab, or use \"Open In\" from the Files app.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Each score defines bars with time signatures, tempo changes with optional markings, and rehearsal marks. Only bars where something changes need to be specified.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AboutView()
}
