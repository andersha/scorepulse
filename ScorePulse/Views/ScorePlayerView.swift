import SwiftUI

struct ScorePlayerView: View {
    let score: Score
    
    @StateObject private var engine = MetronomeEngine()
    @State private var currentBar = 1
    @State private var currentBeat = 1
    @State private var currentDisplayTempo: Int? = nil  // Live tempo during playback
    @State private var tempoMultiplier: Double = 1.0
    @State private var subdivision = SubdivisionMode.quarter
    @State private var rehearsalMode = false
    @State private var countIn = true  // Count one bar before starting
    @State private var isCountingIn = false  // True during count-in bar
    @State private var playStartBar = 1  // The bar we started playing from
    @State private var showingBarInput = false
    @State private var barInputText = ""
    @State private var beatPulse = false
    
    var currentTimeSignature: TimeSignature {
        score.timeSignature(at: currentBar)
    }
    
    var currentTempo: Int {
        score.tempo(at: currentBar)
    }
    
    var effectiveTempo: Int {
        // Use live tempo during playback, otherwise calculate from score
        currentDisplayTempo ?? Int(Double(currentTempo) * tempoMultiplier)
    }
    
    var currentRehearsalMark: RehearsalMark? {
        score.rehearsalMark(at: currentBar)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Score info header
                VStack(spacing: 4) {
                    Text(score.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(score.composer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                // Beat indicator and current position side by side
                HStack(spacing: 16) {
                    // Visual beat indicator
                    Circle()
                        .fill(beatPulse ? (isCountingIn ? Color.blue : Color.green) : Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .animation(.easeInOut(duration: 0.1), value: beatPulse)
                        .overlay(
                            VStack {
                                Text(isCountingIn ? "Count-in" : "Beat")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                Text("\(currentBeat)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        )
                    
                    // Current position display
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if let mark = currentRehearsalMark {
                                Text(mark.displayText)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            Text("Bar \(currentBar) / \(score.totalBars)")
                                .font(.headline)
                        }
                        
                        HStack(spacing: 12) {
                            Text(currentTimeSignature.displayString)
                                .font(.subheadline)
                            Text("♩=\(effectiveTempo)")
                                .font(.subheadline)
                        }
                        
                        if let marking = score.tempoMarking(at: currentBar) {
                            Text(marking)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Tempo adjustment
                VStack(spacing: 6) {
                    HStack {
                        Text("Tempo: \(Int(tempoMultiplier * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Reset") {
                            tempoMultiplier = 1.0
                        }
                        .font(.caption)
                        .disabled(tempoMultiplier == 1.0)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { adjustTempo(-0.05) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        
                        Slider(value: $tempoMultiplier, in: 0.5...1.5, step: 0.05)
                            .disabled(engine.isPlaying)
                        
                        Button(action: { adjustTempo(0.05) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Navigation controls
                VStack(spacing: 8) {
                    HStack {
                        Button(action: goToPreviousMark) {
                            Label("Prev", systemImage: "chevron.left")
                                .font(.body)
                        }
                        .disabled(score.previousRehearsalMark(before: currentBar) == nil || engine.isPlaying)
                        
                        Spacer()
                        
                        Button(action: { showingBarInput = true }) {
                            Label("Go to Bar", systemImage: "music.note.list")
                                .font(.body)
                        }
                        .disabled(engine.isPlaying)
                        
                        Spacer()
                        
                        Button(action: goToNextMark) {
                            Label("Next", systemImage: "chevron.right")
                                .font(.body)
                        }
                        .disabled(score.nextRehearsalMark(after: currentBar) == nil || engine.isPlaying)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(currentBar) },
                        set: { currentBar = Int($0) }
                    ), in: 1...Double(score.totalBars), step: 1)
                    .disabled(engine.isPlaying)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Rehearsal mode and subdivision in one row
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Rehearsal", isOn: $rehearsalMode)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .disabled(engine.isPlaying)
                        Text(rehearsalMode ? "Restart from bar \(playStartBar)" : "Continue playing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(rehearsalMode ? 0.1 : 0.05))
                    .cornerRadius(12)
                    
                    VStack(spacing: 4) {
                        Text("Subdivision")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $subdivision) {
                            ForEach(SubdivisionMode.allCases) { mode in
                                Text(mode.displaySymbol).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(engine.isPlaying)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Count-in toggle
                Toggle("Count-in", isOn: $countIn)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .disabled(engine.isPlaying)
                    .padding()
                    .background(Color.orange.opacity(countIn ? 0.1 : 0.05))
                    .cornerRadius(12)
                
                // Play/Stop button
                Button(action: togglePlayback) {
                    HStack {
                        Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                        Text(engine.isPlaying ? "Stop" : "Start")
                    }
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(engine.isPlaying ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .navigationTitle("Player")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Go to Bar", isPresented: $showingBarInput) {
            TextField("Bar number", text: $barInputText)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {
                barInputText = ""
            }
            Button("Go") {
                if let bar = Int(barInputText), bar >= 1 && bar <= score.totalBars {
                    currentBar = bar
                }
                barInputText = ""
            }
        } message: {
            Text("Enter a bar number (1-\(score.totalBars))")
        }
        .onAppear {
            currentBar = 1
            playStartBar = 1
        }
        .onChange(of: currentBeat) { _, _ in
            beatPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                beatPulse = false
            }
        }
    }
    
    private func togglePlayback() {
        if engine.isPlaying {
            engine.stop()
            currentDisplayTempo = nil  // Reset to calculated tempo
            isCountingIn = false
            if rehearsalMode {
                // Return to where we started
                currentBar = playStartBar
            }
        } else {
            // Remember where we're starting from
            playStartBar = currentBar
            
            engine.startScorePlayback(
                score: score,
                startBar: currentBar,
                tempoMultiplier: tempoMultiplier,
                subdivision: subdivision,
                countIn: countIn
            ) { bar, beat, tempo in
                // bar == -1 means count-in, don't update bar position
                isCountingIn = (bar < 0)
                if bar >= 0 {
                    currentBar = bar
                }
                currentBeat = beat
                currentDisplayTempo = tempo
            }
        }
    }
    
    private func adjustTempo(_ amount: Double) {
        tempoMultiplier = min(max(tempoMultiplier + amount, 0.5), 1.5)
    }
    
    private func goToPreviousMark() {
        if let mark = score.previousRehearsalMark(before: currentBar) {
            currentBar = mark.bar
        }
    }
    
    private func goToNextMark() {
        if let mark = score.nextRehearsalMark(after: currentBar) {
            currentBar = mark.bar
        }
    }
}

#Preview {
    NavigationView {
        ScorePlayerView(score: Score(
            title: "Test Score",
            composer: "Test Composer",
            defaultTempo: 120,
            tempoChanges: [
                TempoChange(bar: 1, tempo: 120, marking: "Moderato")
            ],
            rehearsalMarks: [
                RehearsalMark(name: "A", bar: 1),
                RehearsalMark(name: "B", bar: 17)
            ],
            bars: [
                Bar(number: 1, timeSignature: .fourFour)
            ],
            totalBars: 32
        ))
    }
}
