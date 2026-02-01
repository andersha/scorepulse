# Quick Start: Testing File Import

## Important First Steps

After building and installing the app, you **MUST** complete these steps for file import to work:

1. **Delete any existing version of the app** from your device
2. **Build and install** the new version from Xcode
3. **Restart your iPhone/iPad** - This is critical!
4. **Wait 1-2 minutes** after restart for iOS to register the file types

## Testing Import (2 Methods)

### Method 1: Manual Import (Easiest)

1. **Transfer test file to your device:**
   ```bash
   # From your Mac, AirDrop the test file:
   # test-score.scorepulse
   ```

2. **On your device:**
   - File should appear in Downloads
   - Open **ScorePulse app**
   - Tap **Scores** tab
   - Tap **+** button (top right)
   - Navigate to Downloads
   - Tap **test-score.scorepulse**
   - File should import and appear under "My Scores"

### Method 2: "Open In" (Tests system integration)

1. **AirDrop or email** `test-score.scorepulse` to your device

2. **In Files app or Mail:**
   - Long-press the file
   - Tap **Share** button
   - Scroll down and select **ScorePulse**
   - App opens and imports automatically

## If It Doesn't Work

**Most common issue:** iOS hasn't registered the file types yet

**Solution:**
1. Delete the app completely
2. Restart your device (important!)
3. Rebuild and reinstall
4. Wait a few minutes after install
5. Try again

**Alternative test:**
- Rename `test-score.scorepulse` to `test-score.json`
- Try importing the `.json` file
- The app accepts both `.scorepulse` and `.json` files

## What to Look For

### Success:
- File appears under "My Scores" section
- Shows: "Test Waltz" by "Test Composer"
- 48 bars, tempo 132

### Failure:
- Error alert appears (tells you what's wrong)
- App opens but nothing imports
- Can't find file in picker

## Next Steps

Once import works:
- Try creating your own score files
- Use the CSV converter tool (see CSV_CONVERTER.md)
- Delete scores by swiping left in "My Scores"

## File Format Quick Reference

Minimum valid `.scorepulse` file:

```json
{
  "id": "12345678-1234-1234-1234-123456789012",
  "title": "My Score",
  "composer": "Composer",
  "defaultTempo": 120,
  "tempoChanges": [],
  "rehearsalMarks": [],
  "bars": [
    {
      "id": "12345678-1234-1234-1234-123456789013",
      "number": 1,
      "timeSignature": "4/4"
    }
  ],
  "totalBars": 32
}
```

All IDs must be valid UUIDs (8-4-4-4-12 format with hex digits).
