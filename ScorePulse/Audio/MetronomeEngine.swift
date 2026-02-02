import AVFoundation
import Foundation
import Combine

/// Audio engine for metronome click generation
class MetronomeEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentBeat = 1
    @Published var currentBar = 1
    
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    
    // Audio generation state
    private let lock = NSLock()
    private var clickFrequency: Float = 0
    private var phase: Float = 0
    private var amplitude: Float = 0
    
    // Playback control
    private var playbackTask: Task<Void, Never>?
    
    // Click sound frequencies
    private let downbeatFrequency: Float = 1200.0      // First beat of bar (high)
    private let beatAccentFrequency: Float = 1000.0    // Other beat starts in eighth mode (middle)
    private let regularBeatFrequency: Float = 800.0    // Off-beats / other beats in quarter mode (low)
    
    // Envelope parameters for short click
    private let attackTime: Float = 0.001   // 1ms
    private let decayTime: Float = 0.030    // 30ms
    private let releaseTime: Float = 0.020  // 20ms
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        let mainMixer = audioEngine.mainMixerNode
        let outputNode = audioEngine.outputNode
        let format = outputNode.inputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let twoPi = Float.pi * 2
            
            for frame in 0..<Int(frameCount) {
                self.lock.lock()
                let frequency = self.clickFrequency
                var phase = self.phase
                var amplitude = self.amplitude
                self.lock.unlock()
                
                // Generate sine wave
                var sample: Float = 0
                if frequency > 0 {
                    let phaseIncrement = (frequency / sampleRate) * twoPi
                    sample = sin(phase) * amplitude
                    phase += phaseIncrement
                    if phase > twoPi {
                        phase -= twoPi
                    }
                }
                
                // Exponential decay
                amplitude *= 0.9995
                
                // Write back updated state
                self.lock.lock()
                self.phase = phase
                self.amplitude = amplitude
                self.lock.unlock()
                
                // Write to all channels
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }
            
            return noErr
        }
        
        guard let sourceNode = sourceNode else { return }
        
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: mainMixer, format: format)
        audioEngine.connect(mainMixer, to: outputNode, format: format)
        
        mainMixer.outputVolume = 0.6
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// Click type for different pitch levels
    private enum ClickType {
        case downbeat      // First beat of bar (high pitch)
        case beatAccent    // Other beat starts in eighth mode (middle pitch)
        case offbeat       // Off-beats / other beats in quarter mode (low pitch)
    }
    
    /// Play a single click with specified type
    private func playClick(type: ClickType) {
        lock.lock()
        switch type {
        case .downbeat:
            clickFrequency = downbeatFrequency
        case .beatAccent:
            clickFrequency = beatAccentFrequency
        case .offbeat:
            clickFrequency = regularBeatFrequency
        }
        phase = 0
        amplitude = 0.5
        lock.unlock()
    }
    
    /// Play a single click (legacy compatibility)
    private func playClick(isDownbeat: Bool) {
        playClick(type: isDownbeat ? .downbeat : .offbeat)
    }
    
    /// Start simple metronome with fixed tempo and time signature
    func startMetronome(bpm: Int, timeSignature: TimeSignature, subdivision: SubdivisionMode) {
        stop()
        
        playbackTask = Task { @MainActor in
            await MainActor.run {
                self.isPlaying = true
                self.currentBeat = 1
                self.currentBar = 1
            }
            
            // For /8 meters with groupings (both compound and irregular)
            let isGroupedEighth = timeSignature.hasGroupings && timeSignature.beatUnit == 8
            // For /16 meters (always grouped, pattern required)
            let isSixteenth = timeSignature.isSixteenthBased && timeSignature.hasGroupings
            
            // Calculate durations: tempo marking is always for quarter notes
            let quarterNoteDuration = 60.0 / Double(bpm)
            let eighthNoteDuration = quarterNoteDuration / 2.0
            let sixteenthNoteDuration = quarterNoteDuration / 4.0
            let beatDuration = quarterNoteDuration
            
            let clickDuration: Double
            let totalClicksPerBar: Int
            
            // Use actual beats per bar (handles compound time like 6/8)
            let actualBeats = timeSignature.actualBeatsPerBar
            
            switch subdivision {
            case .quarter:
                if isSixteenth {
                    // For /16 meters: play one click per group (same as eighth mode)
                    // Each group's duration is the sum of its sixteenth notes
                    clickDuration = sixteenthNoteDuration  // Base duration, adjusted per group below
                    totalClicksPerBar = actualBeats  // Number of groups
                } else if isGroupedEighth {
                    // For /8 meters: play one click per group
                    // Each group's duration is the sum of its eighth notes
                    clickDuration = eighthNoteDuration  // Base duration, adjusted per group below
                    totalClicksPerBar = actualBeats  // Number of groups
                } else {
                    clickDuration = beatDuration
                    totalClicksPerBar = actualBeats
                }
            case .eighth:
                if isSixteenth {
                    // For /16 meters: same as quarter mode (one click per group)
                    clickDuration = sixteenthNoteDuration
                    totalClicksPerBar = actualBeats
                } else if isGroupedEighth {
                    // Play all eighth notes at eighth note tempo
                    clickDuration = eighthNoteDuration
                    totalClicksPerBar = timeSignature.beatsPerBar
                } else {
                    clickDuration = beatDuration / 2.0
                    totalClicksPerBar = actualBeats * 2
                }
            }
            var clickIndex = 0
            
            while !Task.isCancelled {
                // Determine click type and duration
                let clickType: ClickType
                let currentClickDuration: Double
                let positionInBar = clickIndex % totalClicksPerBar
                
                if isSixteenth {
                    // /16 meters: one click per group, first beat = downbeat, others = offbeat
                    clickType = positionInBar == 0 ? .downbeat : .offbeat
                    if let pattern = timeSignature.effectiveAccentPattern {
                        currentClickDuration = sixteenthNoteDuration * Double(pattern[positionInBar])
                    } else {
                        currentClickDuration = clickDuration
                    }
                } else if timeSignature.hasGroupings && subdivision == .quarter {
                    // Quarter mode for /8 meters: one click per group
                    // First beat = downbeat, others = offbeat
                    clickType = positionInBar == 0 ? .downbeat : .offbeat
                    if let pattern = timeSignature.effectiveAccentPattern {
                        currentClickDuration = eighthNoteDuration * Double(pattern[positionInBar])
                    } else {
                        currentClickDuration = clickDuration
                    }
                } else if subdivision == .eighth {
                    currentClickDuration = clickDuration
                    // Eighth mode: 3-tier system
                    // First beat of bar = downbeat (high)
                    // Other beat starts = beatAccent (middle)
                    // Off-beats = offbeat (low)
                    if positionInBar == 0 {
                        clickType = .downbeat
                    } else if timeSignature.hasGroupings {
                        // /8 meters: check if on a group boundary
                        let positions = timeSignature.accentPositions()
                        clickType = positions.contains(positionInBar) ? .beatAccent : .offbeat
                    } else {
                        // Simple time in eighth mode: even positions are beats, odd are off-beats
                        clickType = (positionInBar % 2 == 0) ? .beatAccent : .offbeat
                    }
                } else {
                    // Quarter mode for simple time
                    currentClickDuration = clickDuration
                    clickType = positionInBar == 0 ? .downbeat : .offbeat
                }
                
                self.playClick(type: clickType)
                
                await MainActor.run {
                    let positionInBar = clickIndex % totalClicksPerBar
                    if isSixteenth || (isGroupedEighth && subdivision == .quarter) {
                        // For /16 or /8 meters in quarter mode: show which group (1, 2, 3...)
                        self.currentBeat = positionInBar + 1
                    } else if isGroupedEighth && subdivision == .eighth {
                        // For /8 meters in eighth mode: show which group we're in
                        let accentPositions = timeSignature.accentPositions()
                        var beatNum = 1
                        for (idx, pos) in accentPositions.enumerated() {
                            if positionInBar >= pos {
                                beatNum = idx + 1
                            }
                        }
                        self.currentBeat = beatNum
                    } else if subdivision == .quarter {
                        self.currentBeat = (clickIndex % actualBeats) + 1
                    } else {
                        self.currentBeat = (clickIndex / 2 % actualBeats) + 1
                    }
                    
                    if clickIndex > 0 && clickIndex % totalClicksPerBar == 0 {
                        self.currentBar += 1
                    }
                }
                
                try? await Task.sleep(nanoseconds: UInt64(currentClickDuration * 1_000_000_000))
                clickIndex += 1
            }
        }
    }
    
    /// Start score playback with changing time signatures and tempi
    func startScorePlayback(score: Score, startBar: Int, tempoMultiplier: Double, subdivision: SubdivisionMode, countIn: Bool = false, onPositionUpdate: @escaping (Int, Int, Int) -> Void) {
        stop()
        
        playbackTask = Task { @MainActor in
            await MainActor.run {
                self.isPlaying = true
            }
            
            // Play count-in bar if enabled
            if countIn {
                await playCountInBar(
                    score: score,
                    startBar: startBar,
                    tempoMultiplier: tempoMultiplier,
                    subdivision: subdivision,
                    onPositionUpdate: onPositionUpdate
                )
            }
            
            if Task.isCancelled { return }
            
            var barNumber = startBar
            
            while barNumber <= score.totalBars && !Task.isCancelled {
                let timeSignature = score.timeSignature(at: barNumber)
                let isInTransition = score.isInTransition(at: barNumber)
                
                // For /8 meters with groupings (both compound and irregular)
                let isGroupedEighth = timeSignature.hasGroupings && timeSignature.beatUnit == 8
                // For /16 meters (always grouped, pattern required)
                let isSixteenth = timeSignature.isSixteenthBased && timeSignature.hasGroupings
                
                // Use actual beats per bar (handles compound time like 6/8)
                let actualBeats = timeSignature.actualBeatsPerBar
                
                let totalClicksPerBar: Int
                switch subdivision {
                case .quarter:
                    if isSixteenth || isGroupedEighth {
                        totalClicksPerBar = actualBeats
                    } else {
                        totalClicksPerBar = actualBeats
                    }
                case .eighth:
                    if isSixteenth {
                        totalClicksPerBar = actualBeats
                    } else if isGroupedEighth {
                        totalClicksPerBar = timeSignature.beatsPerBar
                    } else {
                        totalClicksPerBar = actualBeats * 2
                    }
                }
                
                // Play all clicks in this bar
                var lastClickDuration: Double = 0
                for clickIndex in 0..<totalClicksPerBar {
                    if Task.isCancelled { break }
                    
                    // Calculate beat progress for tempo interpolation during transitions
                    let beatProgress = Double(clickIndex) / Double(totalClicksPerBar)
                    
                    // Get tempo for this beat (interpolated if in transition)
                    let baseTempo: Int
                    if isInTransition {
                        baseTempo = score.tempo(at: barNumber, beatProgress: beatProgress)
                    } else {
                        baseTempo = score.tempo(at: barNumber)
                    }
                    let effectiveTempo = Int(Double(baseTempo) * tempoMultiplier)
                    
                    // Calculate durations based on current tempo
                    let quarterNoteDuration = 60.0 / Double(effectiveTempo)
                    let eighthNoteDuration = quarterNoteDuration / 2.0
                    let sixteenthNoteDuration = quarterNoteDuration / 4.0
                    let beatDuration = quarterNoteDuration
                    
                    // Determine click type and duration
                    let clickType: ClickType
                    let currentClickDuration: Double
                    
                    if isSixteenth {
                        // /16 meters: one click per group, first beat = downbeat, others = offbeat
                        clickType = clickIndex == 0 ? .downbeat : .offbeat
                        if let pattern = timeSignature.effectiveAccentPattern {
                            currentClickDuration = sixteenthNoteDuration * Double(pattern[clickIndex])
                        } else {
                            currentClickDuration = sixteenthNoteDuration
                        }
                    } else if timeSignature.hasGroupings && subdivision == .quarter {
                        // Quarter mode for /8 meters: one click per group
                        clickType = clickIndex == 0 ? .downbeat : .offbeat
                        if let pattern = timeSignature.effectiveAccentPattern {
                            currentClickDuration = eighthNoteDuration * Double(pattern[clickIndex])
                        } else {
                            currentClickDuration = eighthNoteDuration
                        }
                    } else if subdivision == .eighth {
                        if isGroupedEighth {
                            currentClickDuration = eighthNoteDuration
                        } else {
                            currentClickDuration = beatDuration / 2.0
                        }
                        // Eighth mode: 3-tier system
                        if clickIndex == 0 {
                            clickType = .downbeat
                        } else if timeSignature.hasGroupings {
                            let positions = timeSignature.accentPositions()
                            clickType = positions.contains(clickIndex) ? .beatAccent : .offbeat
                        } else {
                            // Simple time: even positions are beats, odd are off-beats
                            clickType = (clickIndex % 2 == 0) ? .beatAccent : .offbeat
                        }
                    } else {
                        // Quarter mode for simple time
                        currentClickDuration = beatDuration
                        clickType = clickIndex == 0 ? .downbeat : .offbeat
                    }
                    
                    lastClickDuration = currentClickDuration
                    self.playClick(type: clickType)
                    
                    let beatNumber: Int
                    if isSixteenth || (isGroupedEighth && subdivision == .quarter) {
                        // For /16 or /8 meters in quarter mode: show which group (1, 2, 3...)
                        beatNumber = clickIndex + 1
                    } else if isGroupedEighth && subdivision == .eighth {
                        // For /8 meters in eighth mode: show which group we're in
                        let accentPositions = timeSignature.accentPositions()
                        var beatNum = 1
                        for (idx, pos) in accentPositions.enumerated() {
                            if clickIndex >= pos {
                                beatNum = idx + 1
                            }
                        }
                        beatNumber = beatNum
                    } else if subdivision == .quarter {
                        beatNumber = clickIndex + 1
                    } else {
                        beatNumber = (clickIndex / 2) + 1
                    }
                    
                    // Pass current effective tempo to callback
                    let displayTempo = Int(Double(baseTempo) * tempoMultiplier)
                    await MainActor.run {
                        onPositionUpdate(barNumber, beatNumber, displayTempo)
                    }
                    
                    if clickIndex < totalClicksPerBar - 1 {
                        try? await Task.sleep(nanoseconds: UInt64(currentClickDuration * 1_000_000_000))
                    }
                }
                
                // Wait for last beat duration before next bar
                try? await Task.sleep(nanoseconds: UInt64(lastClickDuration * 1_000_000_000))
                barNumber += 1
            }
            
            // Playback finished
            await MainActor.run {
                self.isPlaying = false
            }
        }
    }
    
    /// Play a count-in bar before starting score playback
    private func playCountInBar(score: Score, startBar: Int, tempoMultiplier: Double, subdivision: SubdivisionMode, onPositionUpdate: @escaping (Int, Int, Int) -> Void) async {
        let timeSignature = score.timeSignature(at: startBar)
        let baseTempo = score.tempo(at: startBar)
        let effectiveTempo = Int(Double(baseTempo) * tempoMultiplier)
        
        // Calculate durations
        let quarterNoteDuration = 60.0 / Double(effectiveTempo)
        let eighthNoteDuration = quarterNoteDuration / 2.0
        let sixteenthNoteDuration = quarterNoteDuration / 4.0
        
        let isGroupedEighth = timeSignature.hasGroupings && timeSignature.beatUnit == 8
        let isSixteenth = timeSignature.isSixteenthBased && timeSignature.hasGroupings
        let actualBeats = timeSignature.actualBeatsPerBar
        
        let totalClicksPerBar: Int
        switch subdivision {
        case .quarter:
            totalClicksPerBar = actualBeats
        case .eighth:
            if isSixteenth {
                totalClicksPerBar = actualBeats
            } else if isGroupedEighth {
                totalClicksPerBar = timeSignature.beatsPerBar
            } else {
                totalClicksPerBar = actualBeats * 2
            }
        }
        
        // Play count-in clicks
        for clickIndex in 0..<totalClicksPerBar {
            if Task.isCancelled { break }
            
            let clickType: ClickType = clickIndex == 0 ? .downbeat : .offbeat
            let currentClickDuration: Double
            
            if isSixteenth {
                if let pattern = timeSignature.effectiveAccentPattern {
                    currentClickDuration = sixteenthNoteDuration * Double(pattern[clickIndex])
                } else {
                    currentClickDuration = sixteenthNoteDuration
                }
            } else if isGroupedEighth && subdivision == .quarter {
                if let pattern = timeSignature.effectiveAccentPattern {
                    currentClickDuration = eighthNoteDuration * Double(pattern[clickIndex])
                } else {
                    currentClickDuration = eighthNoteDuration
                }
            } else if subdivision == .eighth {
                if isGroupedEighth {
                    currentClickDuration = eighthNoteDuration
                } else {
                    currentClickDuration = quarterNoteDuration / 2.0
                }
            } else {
                currentClickDuration = quarterNoteDuration
            }
            
            self.playClick(type: clickType)
            
            // Calculate beat number (same logic as main playback)
            let beatNumber: Int
            if isSixteenth || (isGroupedEighth && subdivision == .quarter) {
                beatNumber = clickIndex + 1
            } else if isGroupedEighth && subdivision == .eighth {
                let accentPositions = timeSignature.accentPositions()
                var beatNum = 1
                for (idx, pos) in accentPositions.enumerated() {
                    if clickIndex >= pos {
                        beatNum = idx + 1
                    }
                }
                beatNumber = beatNum
            } else if subdivision == .quarter {
                beatNumber = clickIndex + 1
            } else {
                // Eighth mode for simple time: show beat number, not click number
                beatNumber = (clickIndex / 2) + 1
            }
            
            // Don't update bar number during count-in (pass -1 to signal count-in)
            await MainActor.run {
                onPositionUpdate(-1, beatNumber, effectiveTempo)
            }
            
            try? await Task.sleep(nanoseconds: UInt64(currentClickDuration * 1_000_000_000))
        }
    }
    
    /// Stop playback
    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }
    
    deinit {
        audioEngine.stop()
    }
}
