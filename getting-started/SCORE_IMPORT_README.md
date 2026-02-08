# Score Import Feature

The ScorePulse app now supports importing and managing custom score files.

## Features Implemented

### 1. Custom File Format
- **File Extension**: `.scorepulse`
- **Format**: JSON containing a single Score object
- **UTI**: `com.scorepulse.score` (registered with iOS)

### 2. Storage Architecture
- **User Scores**: Stored in `Documents/Scores/` directory
- **Bundled Scores**: Remain in app bundle as examples
- **File Naming**: `{scoreId}.scorepulse`

### 3. Import Methods

#### Manual Import (Files App)
1. Open ScorePulse app
2. Go to the "Scores" tab
3. Tap the "+" button in the top-right
4. Select a `.scorepulse` or `.json` file from Files app
5. Score is imported and appears under "My Scores"

#### Open-In / Share
1. Find a `.scorepulse` file in Safari, Mail, or another app
2. Tap "Share" → "Open in ScorePulse"
3. Score is automatically imported and app switches to Scores tab

### 4. Score Management
- **Two Sections**: 
  - "My Scores" (user-imported, can be deleted)
  - "Example Scores" (bundled, cannot be deleted)
- **Delete**: Swipe left on any score in "My Scores" section
- **Search**: Works across both bundled and user scores

## Creating Score Files

A `.scorepulse` file is a JSON file with this structure:

```json
{
  "id": "UUID-STRING",
  "title": "Score Title",
  "composer": "Composer Name",
  "defaultTempo": 120,
  "tempoChanges": [
    {
      "id": "UUID-STRING",
      "bar": 1,
      "tempo": 120,
      "marking": "Allegro"
    }
  ],
  "rehearsalMarks": [
    {
      "id": "UUID-STRING",
      "name": "A",
      "bar": 1
    }
  ],
  "bars": [
    {
      "id": "UUID-STRING",
      "number": 1,
      "timeSignature": "4/4"
    }
  ],
  "totalBars": 48
}
```

### Example Files
- A test score is included at: `test-score.scorepulse`
- All bundled example scores in `ScorePulse/Scores/bundled-scores.json`

## Implementation Details

### New Files
1. **ScoreStorageManager.swift** - Manages file I/O and persistence
2. **DocumentPicker.swift** - UIKit wrapper for file picking

### Modified Files
1. **MetronomeSettings.swift** - Loads from both bundled and user sources
2. **ScoreListView.swift** - Sections, import UI, delete functionality
3. **ScorePulseApp.swift** - Open-In URL handling
4. **Info.plist** - UTI declaration and document type registration

### Key Classes

#### ScoreStorageManager
- `saveScore(_:)` - Save score to Documents
- `loadAllScores()` - Load all user scores
- `deleteScore(_:)` - Remove score from storage
- `importScore(from:)` - Import and validate external score

#### MetronomeSettings
- `bundledScores` - Read-only example scores
- `userScores` - Imported scores from storage
- `availableScores` - Combined list
- `importScore(from:)` - Import new score
- `deleteUserScore(_:)` - Delete user score
- `isBundledScore(_:)` - Check if score is bundled

## Testing

To test the import functionality:

1. **Build and run** the app in simulator or device
2. **Test manual import**:
   - Use AirDrop or iCloud to transfer `test-score.scorepulse` to your device
   - Open Files app and locate the file
   - Open ScorePulse and tap "+" to import
3. **Test Open-In**:
   - Email yourself the test file
   - Open Mail and tap the attachment
   - Select "Share" → "ScorePulse"

## Error Handling

The app validates imported files and shows error alerts for:
- Invalid JSON format
- Missing required fields
- File read failures
- Permission issues

All errors are surfaced to the user via alert dialogs.
