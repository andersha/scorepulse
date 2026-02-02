# ScorePulse - Copilot Instructions

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -project ScorePulse.xcodeproj -scheme ScorePulse \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run CSV to ScorePulse converter
python3 scores/csv_to_scorepulse.py input.csv output.scorepulse
```

## Architecture

### Two-Layer Data Model

The app uses a sparse data model where only **changes** are stored:

- **`bars`** array only contains bars where time signature changes (not every bar)
- **`tempoChanges`** array only contains bars where tempo changes
- **`rehearsalMarks`** array only contains bars with rehearsal marks

To get the value at any bar, use lookup methods that find the most recent change:
```swift
score.tempo(at: barNumber)           // Returns current tempo
score.timeSignature(at: barNumber)   // Returns current time signature
score.tempo(at: barNumber, beatProgress: 0.5)  // Interpolated tempo during transitions
```

### Audio Playback (MetronomeEngine)

`MetronomeEngine.swift` handles all audio generation:
- Uses `AVAudioSourceNode` with sine wave generation (not audio files)
- Three pitch levels: downbeat (1200 Hz), beat accent (1000 Hz), offbeat (800 Hz)
- `startMetronome()` - simple fixed tempo/time signature mode
- `startScorePlayback()` - follows score with changing tempi and meters

The playback loop recalculates tempo per-beat when in transition bars (acc/rit).

**Known Issue**: Click timing uses `Task.sleep` which is not sample-accurate. At high BPM, clicks may occasionally be missed. A future improvement would pre-schedule clicks based on audio sample counts within the `AVAudioSourceNode` callback.

### Time Signature Handling

Time signatures support two JSON formats:
```json
// Simple
"timeSignature": "4/4"

// With accent pattern (for irregular meters)
"timeSignature": {
  "timeSignature": "7/8",
  "accentPattern": [2, 2, 3]
}
```

The `effectiveAccentPattern` property returns explicit patterns or generates defaults for /8 meters.

### Tempo Transitions

Tempo changes support gradual transitions (accelerando/ritardando):
- `transition: "none"` - instant tempo change (default)
- `transition: "acc"` - gradual increase to next tempo
- `transition: "rit"` - gradual decrease to next tempo

Transition-only bars have `tempo: null` in JSON.

## Key Conventions

### File Formats

- **`.scorepulse`** files are JSON with the `Score` structure
- **CSV input** uses semicolon (`;`) delimiters, not commas
- All IDs must be valid UUIDs

### Storage

- Bundled scores: `ScorePulse/Scores/bundled-scores.json` (read-only, in app bundle)
- User scores: `Documents/Scores/*.scorepulse` (managed by `ScoreStorageManager`)

### Subdivision Modes

Two modes affect click patterns:
- **Quarter mode**: One click per beat/group
- **Eighth mode**: Subdivides beats, uses 3-tier accent system

For /8 and /16 meters, clicks follow the accent pattern groups, not raw beat units.
