import SwiftUI

struct MetronomeView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var bpm: Double = 120
    @State private var selectedTimeSignature = TimeSignature.fourFour
    @State private var subdivision = SubdivisionMode.quarter
    @State private var beatPulse = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Visual beat indicator
                Circle()
                    .fill(beatPulse ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 0.1), value: beatPulse)
                    .overlay(
                        VStack {
                            Text("Beat")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("\(engine.currentBeat)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                    )
                
                // Tempo display
                VStack(spacing: 8) {
                    Text("♩ = \(Int(bpm))")
                        .font(.system(size: 48, weight: .bold))
                    
                    Slider(value: $bpm, in: 40...240, step: 1)
                        .padding(.horizontal, 40)
                        .disabled(engine.isPlaying)
                    
                    Text("Tempo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Time signature picker
                VStack(spacing: 8) {
                    Text(selectedTimeSignature.displayString)
                        .font(.system(size: 32, weight: .semibold))
                    
                    Picker("Time Signature", selection: $selectedTimeSignature) {
                        ForEach(TimeSignature.common, id: \.self) { ts in
                            Text(ts.displayString).tag(ts)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)
                    .disabled(engine.isPlaying)
                    
                    Text("Time Signature")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Subdivision toggle
                VStack(spacing: 8) {
                    Picker("Subdivision", selection: $subdivision) {
                        ForEach(SubdivisionMode.allCases) { mode in
                            Text(mode.displaySymbol).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 80)
                    .disabled(engine.isPlaying)
                    
                    Text("Subdivision")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Play/Stop button
                Button(action: togglePlayback) {
                    HStack {
                        Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                        Text(engine.isPlaying ? "Stop" : "Start")
                    }
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(engine.isPlaying ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Metronome")
            .onChange(of: engine.currentBeat) { _, _ in
                // Trigger beat pulse animation
                beatPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    beatPulse = false
                }
            }
        }
    }
    
    private func togglePlayback() {
        if engine.isPlaying {
            engine.stop()
        } else {
            engine.startMetronome(
                bpm: Int(bpm),
                timeSignature: selectedTimeSignature,
                subdivision: subdivision
            )
        }
    }
}

#Preview {
    MetronomeView()
}
