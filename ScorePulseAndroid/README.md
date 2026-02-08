# ScorePulse Android

Android version of the ScorePulse score-aware metronome app.

## Features

- **Simple Metronome**: Fixed tempo and time signature practice
- **Score Playback**: Follow scores with changing tempi and time signatures
- **Tempo Transitions**: Supports accelerando and ritardando
- **Irregular Meters**: 5/8, 7/8, and custom accent patterns
- **Rehearsal Mode**: Loop from a specific starting point
- **Count-in**: Optional count-in bar before playback
- **Subdivision Modes**: Quarter note and eighth note click patterns

## Build Instructions

### Requirements
- Android Studio Arctic Fox or later (recommended)
- JDK 17
- Android SDK 34
- Gradle 8.13

### Setup

1. Set your Android SDK location by either:
   - Setting the `ANDROID_HOME` environment variable
   - Creating `local.properties` with `sdk.dir=/path/to/android/sdk`

On macOS with Android Studio, the SDK is typically at:
`/Users/YOUR_USERNAME/Library/Android/sdk`

### Command Line Build

```bash
# Debug build
./gradlew assembleDebug

# Release build
./gradlew assembleRelease

# Install debug APK to connected device
./gradlew installDebug

# Run tests
./gradlew test

# Clean build
./gradlew clean
```

The debug APK will be located at:
`app/build/outputs/apk/debug/app-debug.apk`

### Android Studio

1. Open the `ScorePulseAndroid` directory in Android Studio
2. Wait for Gradle sync to complete
3. Click Run or press Shift+F10

## Project Structure

```
ScorePulseAndroid/
├── app/
│   ├── src/main/
│   │   ├── java/com/scorepulse/
│   │   │   ├── model/          # Data models (Score, TimeSignature, etc.)
│   │   │   ├── audio/          # MetronomeEngine with AudioTrack
│   │   │   ├── data/           # Score storage manager
│   │   │   └── ui/
│   │   │       ├── screens/    # Compose UI screens
│   │   │       ├── viewmodel/  # ViewModels
│   │   │       └── theme/      # Material 3 theme
│   │   ├── assets/             # Bundled scores JSON
│   │   └── res/                # Android resources
│   └── build.gradle.kts
├── build.gradle.kts
├── settings.gradle.kts
└── gradlew
```

## Data Model

Same sparse data model as iOS version:
- `bars` array only contains bars where time signature changes
- `tempoChanges` array only contains bars where tempo changes
- `rehearsalMarks` array only contains bars with rehearsal marks

## Score File Format

`.scorepulse` files are JSON format. Example:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "title": "Symphony No. 5",
  "composer": "Ludwig van Beethoven",
  "defaultTempo": 108,
  "tempoChanges": [
    { "id": "...", "bar": 1, "tempo": 108, "marking": "Allegro" }
  ],
  "rehearsalMarks": [
    { "id": "...", "name": "A", "bar": 1 }
  ],
  "bars": [
    { "id": "...", "number": 1, "timeSignature": "2/4" }
  ],
  "totalBars": 248
}
```

## Audio Implementation

Uses Android's `AudioTrack` API with sine wave generation:
- Downbeat: 1200 Hz
- Beat accent: 1000 Hz  
- Offbeat: 800 Hz

Click timing uses coroutines with delay, similar to the iOS implementation.
