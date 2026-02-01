# ScorePulse

An advanced metronome app for iOS with support for rehearsing specific musical pieces.

## Features

- **Simple Metronome Mode**
  - Adjustable BPM (40-240)
  - Multiple time signatures (4/4, 3/4, 2/4, 6/8, 5/4)
  - Quarter note and eighth note subdivisions
  - Visual beat indicator

- **Score Playback Mode**
  - Play metronome with changing time signatures and tempi
  - Practice tempo adjustment (50%-150%)
  - Navigate by bar number or rehearsal marks
  - Rehearsal mode for practicing specific passages
  - Visual position tracking

## Project Setup

To create the Xcode project:

1. Open Xcode
2. Create a new iOS App project:
   - Product Name: **ScorePulse**
   - Organization Identifier: **com.yourname.scorepulse**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Save location: `/Users/anders.abrahamsen/apps/scorepulse`

3. Delete the default `ContentView.swift` file

4. Add all the existing files to the project:
   - Models folder (TimeSignature.swift, Bar.swift, etc.)
   - Audio folder (MetronomeEngine.swift)
   - Views folder (MetronomeView.swift, ScoreListView.swift, ScorePlayerView.swift)
   - Scores folder (bundled-scores.json)
   - Replace ScorePulseApp.swift with the provided version

5. Add bundled-scores.json to the app bundle:
   - Select bundled-scores.json in Xcode
   - In the File Inspector, ensure "Target Membership" includes ScorePulse

6. Build and run on iPhone simulator or device

## Project Structure

```
ScorePulse/
├── ScorePulseApp.swift          # Main app entry
├── Models/
│   ├── Score.swift              # Score data model
│   ├── Bar.swift                # Bar with time signature
│   ├── TimeSignature.swift      # Time signature model
│   ├── TempoChange.swift        # Tempo change at bar
│   ├── RehearsalMark.swift      # Rehearsal mark model
│   └── MetronomeSettings.swift  # Settings & state
├── Audio/
│   └── MetronomeEngine.swift    # Audio engine for clicks
├── Views/
│   ├── MetronomeView.swift      # Simple metronome mode
│   ├── ScoreListView.swift      # List of scores
│   └── ScorePlayerView.swift    # Play score with metronome
└── Scores/
    └── bundled-scores.json      # Bundled score data
```

## Included Scores

The app includes five sample scores:
1. **Beethoven - Symphony No. 5** (2/4, 248 bars)
2. **Strauss - The Blue Danube** (3/4, 168 bars)
3. **Desmond - Take Five** (5/4, 64 bars)
4. **Complex Example** (Multiple time signatures and tempo changes)
5. **Irregular Meters Example** (5/8 [2+3], 7/8 [2+2+3], 7/8 [3+2+2])

## Score Format

Scores are stored in JSON format:

```json
{
  "id": "uuid",
  "title": "Symphony No. 5",
  "composer": "Beethoven",
  "defaultTempo": 108,
  "tempoChanges": [
    {"bar": 1, "tempo": 108, "marking": "Allegro con brio"}
  ],
  "rehearsalMarks": [
    {"name": "A", "bar": 1}
  ],
  "bars": [
    {"number": 1, "timeSignature": "2/4"}
  ],
  "totalBars": 248
}
```

### Irregular/Complex Time Signatures

For irregular meters like 5/8 and 7/8, you can specify custom accent patterns:

```json
{
  "number": 1,
  "timeSignature": {
    "timeSignature": "5/8",
    "accentPattern": [2, 3]
  }
}
```

Common patterns:
- **5/8**: `[2, 3]` (2+3) or `[3, 2]` (3+2)
- **7/8**: `[2, 2, 3]` (2+2+3), `[3, 2, 2]` (3+2+2), or `[2, 3, 2]` (2+3+2)

The pattern defines groupings, and the metronome will accent the first eighth note of each group when using eighth note subdivision.

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Audio

The app uses AVFoundation's AVAudioEngine for precise metronome click generation with:
- Downbeat: 1200 Hz
- Regular beat: 800 Hz
- Short click envelope with exponential decay

## Future Features

- In-app score editor
- Import/export scores
- Custom click sounds
- Visual measure display
- Practice statistics
