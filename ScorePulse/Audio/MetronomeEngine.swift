import AVFoundation
import Foundation
import Combine
import UIKit

/// Scheduled click with sample position and type
private struct ScheduledClick {
    let sampleTime: Int64      // Sample position when click should play
    let frequency: Float       // Click frequency
    let bar: Int               // Bar number (-1 for count-in)
    let beat: Int              // Beat number for UI
    let tempo: Int             // Tempo for UI display
}

/// Audio engine for metronome click generation with sample-accurate timing
class MetronomeEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentBeat = 1
    @Published var currentBar = 1
    
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sampleRate: Double = 44100.0
    private let appSettings = AppSettings.shared
    
    // Audio generation state (accessed from audio thread)
    private let lock = NSLock()
    private var clickQueue: [ScheduledClick] = []
    private var currentSampleTime: Int64 = 0
    private var activeClickFrequency: Float = 0
    private var phase: Float = 0
    private var amplitude: Float = 0
    private var shouldSilence: Bool = false  // Flag to immediately stop sound
    
    // UI update callback (called from scheduling task)
    private var positionUpdateCallback: ((Int, Int, Int) -> Void)?
    
    // Playback control
    private var schedulingTask: Task<Void, Never>?
    private var playbackStartTime: Date?
    private var playbackStartSampleTime: Int64 = 0
    private var playbackGeneration: Int = 0  // Increments each start to invalidate old UI callbacks
    
    // Click sound frequencies
    private let downbeatFrequency: Float = 1200.0
    private let beatAccentFrequency: Float = 1000.0
    private let regularBeatFrequency: Float = 800.0
    
    init() {
        setupAudioSession()
        setupAudioEngine()
        setupBackgroundHandling()
    }
    
    private func setupBackgroundHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillResignActive() {
        if isPlaying {
            stop()
        }
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
        sampleRate = format.sampleRate
        let sampleRateFloat = Float(sampleRate)
        
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let twoPi = Float.pi * 2
            
            self.lock.lock()
            var sampleTime = self.currentSampleTime
            var clickQueue = self.clickQueue
            var activeFrequency = self.activeClickFrequency
            var phase = self.phase
            var amplitude = self.amplitude
            let shouldSilence = self.shouldSilence
            self.lock.unlock()
            
            // If silenced, output silence and skip processing
            if shouldSilence {
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    for frame in 0..<Int(frameCount) {
                        buf?[frame] = 0
                    }
                }
                self.lock.lock()
                self.currentSampleTime = sampleTime + Int64(frameCount)
                self.lock.unlock()
                return noErr
            }
            
            for frame in 0..<Int(frameCount) {
                // Check if we should trigger a new click
                while let nextClick = clickQueue.first, nextClick.sampleTime <= sampleTime {
                    activeFrequency = nextClick.frequency
                    phase = 0
                    amplitude = self.appSettings.volumeLevel.amplitude
                    clickQueue.removeFirst()
                }
                
                // Generate sine wave
                var sample: Float = 0
                if activeFrequency > 0 && amplitude > 0.001 {
                    let phaseIncrement = (activeFrequency / sampleRateFloat) * twoPi
                    sample = sin(phase) * amplitude
                    phase += phaseIncrement
                    if phase > twoPi {
                        phase -= twoPi
                    }
                    // Exponential decay
                    amplitude *= 0.9995
                }
                
                // Write to all channels
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
                
                sampleTime += 1
            }
            
            // Write back updated state
            self.lock.lock()
            self.currentSampleTime = sampleTime
            self.clickQueue = clickQueue
            self.activeClickFrequency = activeFrequency
            self.phase = phase
            self.amplitude = amplitude
            self.lock.unlock()
            
            return noErr
        }
        
        guard let sourceNode = sourceNode else { return }
        
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: mainMixer, format: format)
        audioEngine.connect(mainMixer, to: outputNode, format: format)
        
        // Volume will be set from settings when playback starts
        mainMixer.outputVolume = 1.0
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// Click type for different pitch levels
    private enum ClickType {
        case downbeat
        case beatAccent
        case offbeat
        
        var frequency: Float {
            switch self {
            case .downbeat: return 1200.0
            case .beatAccent: return 1000.0
            case .offbeat: return 800.0
            }
        }
    }
    
    /// Schedule a click at a specific sample time
    private func scheduleClick(at sampleTime: Int64, type: ClickType, bar: Int, beat: Int, tempo: Int) {
        let click = ScheduledClick(
            sampleTime: sampleTime,
            frequency: type.frequency,
            bar: bar,
            beat: beat,
            tempo: tempo
        )
        lock.lock()
        clickQueue.append(click)
        lock.unlock()
        
        // Schedule UI update based on wall-clock time from playback start
        guard let startTime = playbackStartTime else { return }
        let samplesFromStart = sampleTime - playbackStartSampleTime
        let secondsFromStart = Double(samplesFromStart) / sampleRate
        let fireTime = startTime.addingTimeInterval(secondsFromStart)
        let delay = max(0, fireTime.timeIntervalSinceNow)
        
        let generation = playbackGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isPlaying, self.playbackGeneration == generation else { return }
            if bar > 0 {
                self.currentBar = bar
            }
            self.currentBeat = beat
            self.positionUpdateCallback?(bar, beat, tempo)
        }
    }
    
    /// Get current sample time
    private func getCurrentSampleTime() -> Int64 {
        lock.lock()
        let time = currentSampleTime
        lock.unlock()
        return time
    }
    
    /// Clear all scheduled clicks
    private func clearScheduledClicks() {
        lock.lock()
        clickQueue.removeAll()
        activeClickFrequency = 0
        amplitude = 0
        shouldSilence = true
        lock.unlock()
    }
    
    /// Convert duration in seconds to samples
    private func samplesToSeconds(_ samples: Int64) -> Double {
        return Double(samples) / sampleRate
    }
    
    private func secondsToSamples(_ seconds: Double) -> Int64 {
        return Int64(seconds * sampleRate)
    }
    
    /// Start simple metronome with fixed tempo and time signature
    func startMetronome(bpm: Int, timeSignature: TimeSignature, subdivision: SubdivisionMode) {
        stop()
        
        // Disable screen idle timer to keep screen on during playback
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Apply volume settings
        audioEngine.mainMixerNode.outputVolume = appSettings.volumeLevel.mixerVolume
        
        clearScheduledClicks()
        
        // Reset sample counter and enable audio
        lock.lock()
        currentSampleTime = 0
        shouldSilence = false
        lock.unlock()
        
        schedulingTask = Task { @MainActor in
            self.isPlaying = true
            self.currentBeat = 1
            self.currentBar = 1
            
            // Record playback start for UI timing
            self.playbackStartSampleTime = self.lock.withLock { self.currentSampleTime }
            self.playbackStartTime = Date()
            
            let isGroupedEighth = timeSignature.hasGroupings && timeSignature.beatUnit == 8
            let isSixteenth = timeSignature.isSixteenthBased && timeSignature.hasGroupings
            let actualBeats = timeSignature.actualBeatsPerBar
            
            let quarterNoteDuration = 60.0 / Double(bpm)
            let eighthNoteDuration = quarterNoteDuration / 2.0
            let sixteenthNoteDuration = quarterNoteDuration / 4.0
            
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
            
            var nextClickSampleTime: Int64 = self.getCurrentSampleTime() + self.secondsToSamples(0.05) // Small initial delay
            var clickIndex = 0
            var currentBarNum = 1
            
            // Pre-schedule a large buffer of clicks (100 bars worth)
            let barsToSchedule = 100
            let totalClicksToSchedule = barsToSchedule * totalClicksPerBar
            
            // Schedule initial buffer
            for _ in 0..<totalClicksToSchedule {
                if Task.isCancelled { break }
                
                let positionInBar = clickIndex % totalClicksPerBar
                
                // Determine click type
                let clickType: ClickType
                if isSixteenth || (timeSignature.hasGroupings && subdivision == .quarter) {
                    clickType = positionInBar == 0 ? .downbeat : .offbeat
                } else if subdivision == .eighth {
                    if positionInBar == 0 {
                        clickType = .downbeat
                    } else if timeSignature.hasGroupings {
                        let positions = timeSignature.accentPositions()
                        clickType = positions.contains(positionInBar) ? .beatAccent : .offbeat
                    } else {
                        clickType = (positionInBar % 2 == 0) ? .beatAccent : .offbeat
                    }
                } else {
                    clickType = positionInBar == 0 ? .downbeat : .offbeat
                }
                
                // Calculate beat number for UI
                let beatNumber: Int
                if isSixteenth || (isGroupedEighth && subdivision == .quarter) {
                    beatNumber = positionInBar + 1
                } else if isGroupedEighth && subdivision == .eighth {
                    let accentPositions = timeSignature.accentPositions()
                    var beatNum = 1
                    for (idx, pos) in accentPositions.enumerated() {
                        if positionInBar >= pos {
                            beatNum = idx + 1
                        }
                    }
                    beatNumber = beatNum
                } else if subdivision == .quarter {
                    beatNumber = positionInBar + 1
                } else {
                    beatNumber = (positionInBar / 2) + 1
                }
                
                self.scheduleClick(at: nextClickSampleTime, type: clickType, bar: currentBarNum, beat: beatNumber, tempo: bpm)
                
                // Calculate duration for this click
                let clickDuration: Double
                if isSixteenth {
                    if let pattern = timeSignature.effectiveAccentPattern {
                        clickDuration = sixteenthNoteDuration * Double(pattern[positionInBar])
                    } else {
                        clickDuration = sixteenthNoteDuration
                    }
                } else if isGroupedEighth && subdivision == .quarter {
                    if let pattern = timeSignature.effectiveAccentPattern {
                        clickDuration = eighthNoteDuration * Double(pattern[positionInBar])
                    } else {
                        clickDuration = eighthNoteDuration
                    }
                } else if subdivision == .eighth {
                    if isGroupedEighth {
                        clickDuration = eighthNoteDuration
                    } else {
                        clickDuration = quarterNoteDuration / 2.0
                    }
                } else {
                    clickDuration = quarterNoteDuration
                }
                
                nextClickSampleTime += self.secondsToSamples(clickDuration)
                clickIndex += 1
                
                if clickIndex % totalClicksPerBar == 0 {
                    currentBarNum += 1
                }
            }
            
            // Continue scheduling more clicks as playback progresses
            while !Task.isCancelled {
                let currentTime = self.getCurrentSampleTime()
                let timeUntilLastScheduled = self.samplesToSeconds(nextClickSampleTime - currentTime)
                
                // When we're down to 50 bars of buffer, schedule another 100 bars
                let barDuration = (60.0 / Double(bpm)) * Double(timeSignature.beatsPerBar)
                let barsRemaining = timeUntilLastScheduled / barDuration
                
                if barsRemaining < 50 {
                    // Schedule another batch
                    for _ in 0..<totalClicksToSchedule {
                        if Task.isCancelled { break }
                        
                        let positionInBar = clickIndex % totalClicksPerBar
                        
                        let clickType: ClickType
                        if isSixteenth || (timeSignature.hasGroupings && subdivision == .quarter) {
                            clickType = positionInBar == 0 ? .downbeat : .offbeat
                        } else if subdivision == .eighth {
                            if positionInBar == 0 {
                                clickType = .downbeat
                            } else if timeSignature.hasGroupings {
                                let positions = timeSignature.accentPositions()
                                clickType = positions.contains(positionInBar) ? .beatAccent : .offbeat
                            } else {
                                clickType = (positionInBar % 2 == 0) ? .beatAccent : .offbeat
                            }
                        } else {
                            clickType = positionInBar == 0 ? .downbeat : .offbeat
                        }
                        
                        let beatNumber: Int
                        if isSixteenth || (isGroupedEighth && subdivision == .quarter) {
                            beatNumber = positionInBar + 1
                        } else if isGroupedEighth && subdivision == .eighth {
                            let accentPositions = timeSignature.accentPositions()
                            var beatNum = 1
                            for (idx, pos) in accentPositions.enumerated() {
                                if positionInBar >= pos {
                                    beatNum = idx + 1
                                }
                            }
                            beatNumber = beatNum
                        } else if subdivision == .quarter {
                            beatNumber = positionInBar + 1
                        } else {
                            beatNumber = (positionInBar / 2) + 1
                        }
                        
                        self.scheduleClick(at: nextClickSampleTime, type: clickType, bar: currentBarNum, beat: beatNumber, tempo: bpm)
                        
                        let clickDuration: Double
                        if isSixteenth {
                            if let pattern = timeSignature.effectiveAccentPattern {
                                clickDuration = sixteenthNoteDuration * Double(pattern[positionInBar])
                            } else {
                                clickDuration = sixteenthNoteDuration
                            }
                        } else if isGroupedEighth && subdivision == .quarter {
                            if let pattern = timeSignature.effectiveAccentPattern {
                                clickDuration = eighthNoteDuration * Double(pattern[positionInBar])
                            } else {
                                clickDuration = eighthNoteDuration
                            }
                        } else if subdivision == .eighth {
                            if isGroupedEighth {
                                clickDuration = eighthNoteDuration
                            } else {
                                clickDuration = quarterNoteDuration / 2.0
                            }
                        } else {
                            clickDuration = quarterNoteDuration
                        }
                        
                        nextClickSampleTime += self.secondsToSamples(clickDuration)
                        clickIndex += 1
                        
                        if clickIndex % totalClicksPerBar == 0 {
                            currentBarNum += 1
                        }
                    }
                }
                
                // Check less frequently since we have a large buffer
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }
        }
    }
    
    /// Start score playback with changing time signatures and tempi
    func startScorePlayback(score: Score, startBar: Int, tempoMultiplier: Double, subdivision: SubdivisionMode, countIn: Bool = false, onPositionUpdate: @escaping (Int, Int, Int) -> Void) {
        stop()
        
        // Disable screen idle timer to keep screen on during playback
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Apply volume settings
        audioEngine.mainMixerNode.outputVolume = appSettings.volumeLevel.mixerVolume
        
        clearScheduledClicks()
        
        // Reset sample counter and enable audio
        lock.lock()
        currentSampleTime = 0
        shouldSilence = false
        lock.unlock()
        
        positionUpdateCallback = onPositionUpdate
        
        schedulingTask = Task { @MainActor in
            self.isPlaying = true
            
            // Record playback start for UI timing
            self.playbackStartSampleTime = self.lock.withLock { self.currentSampleTime }
            self.playbackStartTime = Date()
            
            var nextClickSampleTime: Int64 = self.getCurrentSampleTime() + self.secondsToSamples(0.05)
            
            // Schedule count-in if enabled
            if countIn {
                nextClickSampleTime = await self.scheduleCountIn(
                    score: score,
                    startBar: startBar,
                    tempoMultiplier: tempoMultiplier,
                    subdivision: subdivision,
                    startingSampleTime: nextClickSampleTime
                )
            }
            
            // Pre-calculate and schedule all clicks for the score
            var barNumber = startBar
            
            while barNumber <= score.totalBars && !Task.isCancelled {
                let timeSignature = score.timeSignature(at: barNumber)
                let isInTransition = score.isInTransition(at: barNumber)
                
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
                
                for clickIndex in 0..<totalClicksPerBar {
                    if Task.isCancelled { break }
                    
                    let beatProgress = Double(clickIndex) / Double(totalClicksPerBar)
                    
                    let baseTempo: Int
                    if isInTransition {
                        baseTempo = score.tempo(at: barNumber, beatProgress: beatProgress)
                    } else {
                        baseTempo = score.tempo(at: barNumber)
                    }
                    let effectiveTempo = Int(Double(baseTempo) * tempoMultiplier)
                    
                    let quarterNoteDuration = 60.0 / Double(effectiveTempo)
                    let eighthNoteDuration = quarterNoteDuration / 2.0
                    let sixteenthNoteDuration = quarterNoteDuration / 4.0
                    
                    // Determine click type
                    let clickType: ClickType
                    if isSixteenth || (timeSignature.hasGroupings && subdivision == .quarter) {
                        clickType = clickIndex == 0 ? .downbeat : .offbeat
                    } else if subdivision == .eighth {
                        if clickIndex == 0 {
                            clickType = .downbeat
                        } else if timeSignature.hasGroupings {
                            let positions = timeSignature.accentPositions()
                            clickType = positions.contains(clickIndex) ? .beatAccent : .offbeat
                        } else {
                            clickType = (clickIndex % 2 == 0) ? .beatAccent : .offbeat
                        }
                    } else {
                        clickType = clickIndex == 0 ? .downbeat : .offbeat
                    }
                    
                    // Calculate beat number
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
                        beatNumber = (clickIndex / 2) + 1
                    }
                    
                    self.scheduleClick(at: nextClickSampleTime, type: clickType, bar: barNumber, beat: beatNumber, tempo: effectiveTempo)
                    
                    // Calculate duration
                    let clickDuration: Double
                    if isSixteenth {
                        if let pattern = timeSignature.effectiveAccentPattern {
                            clickDuration = sixteenthNoteDuration * Double(pattern[clickIndex])
                        } else {
                            clickDuration = sixteenthNoteDuration
                        }
                    } else if isGroupedEighth && subdivision == .quarter {
                        if let pattern = timeSignature.effectiveAccentPattern {
                            clickDuration = eighthNoteDuration * Double(pattern[clickIndex])
                        } else {
                            clickDuration = eighthNoteDuration
                        }
                    } else if subdivision == .eighth {
                        if isGroupedEighth {
                            clickDuration = eighthNoteDuration
                        } else {
                            clickDuration = quarterNoteDuration / 2.0
                        }
                    } else {
                        clickDuration = quarterNoteDuration
                    }
                    
                    nextClickSampleTime += self.secondsToSamples(clickDuration)
                }
                
                barNumber += 1
            }
            
            // Monitor playback to detect completion
            let finalSampleTime = nextClickSampleTime
            while !Task.isCancelled {
                let currentTime = self.getCurrentSampleTime()
                
                // Check if we've finished
                if currentTime >= finalSampleTime {
                    break
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
            self.isPlaying = false
        }
    }
    
    /// Schedule count-in clicks and return the sample time for the first score click
    private func scheduleCountIn(score: Score, startBar: Int, tempoMultiplier: Double, subdivision: SubdivisionMode, startingSampleTime: Int64) async -> Int64 {
        let timeSignature = score.timeSignature(at: startBar)
        let baseTempo = score.tempo(at: startBar)
        let effectiveTempo = Int(Double(baseTempo) * tempoMultiplier)
        
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
        
        var nextClickSampleTime = startingSampleTime
        
        for clickIndex in 0..<totalClicksPerBar {
            let clickType: ClickType = clickIndex == 0 ? .downbeat : .offbeat
            
            // Beat number calculation
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
                beatNumber = (clickIndex / 2) + 1
            }
            
            scheduleClick(at: nextClickSampleTime, type: clickType, bar: -1, beat: beatNumber, tempo: effectiveTempo)
            
            // Calculate duration
            let clickDuration: Double
            if isSixteenth {
                if let pattern = timeSignature.effectiveAccentPattern {
                    clickDuration = sixteenthNoteDuration * Double(pattern[clickIndex])
                } else {
                    clickDuration = sixteenthNoteDuration
                }
            } else if isGroupedEighth && subdivision == .quarter {
                if let pattern = timeSignature.effectiveAccentPattern {
                    clickDuration = eighthNoteDuration * Double(pattern[clickIndex])
                } else {
                    clickDuration = eighthNoteDuration
                }
            } else if subdivision == .eighth {
                if isGroupedEighth {
                    clickDuration = eighthNoteDuration
                } else {
                    clickDuration = quarterNoteDuration / 2.0
                }
            } else {
                clickDuration = quarterNoteDuration
            }
            
            nextClickSampleTime += secondsToSamples(clickDuration)
        }
        
        return nextClickSampleTime
    }
    
    /// Stop playback
    func stop() {
        schedulingTask?.cancel()
        schedulingTask = nil
        playbackGeneration += 1  // Invalidate any pending UI callbacks
        clearScheduledClicks()
        isPlaying = false
        positionUpdateCallback = nil
        
        // Re-enable screen idle timer when stopped
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    deinit {
        audioEngine.stop()
    }
}
