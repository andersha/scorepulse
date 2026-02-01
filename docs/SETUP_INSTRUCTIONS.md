# ScorePulse - Xcode Project Setup Instructions

All the Swift source files and resources have been created. Now you need to create the Xcode project to build the app.

## Quick Setup Steps

1. **Open Xcode**

2. **Create New Project**
   - File → New → Project
   - Choose "iOS" → "App"
   - Click "Next"

3. **Project Settings**
   - Product Name: `ScorePulse`
   - Team: Select your development team
   - Organization Identifier: `com.yourdomain.scorepulse` (or your preferred identifier)
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Click "Next"
   - Save in: `/Users/anders.abrahamsen/apps/scorepulse`
   - **IMPORTANT**: Uncheck "Create Git repository" (to avoid conflicts)
   - Click "Create"

4. **Clean Up Default Files**
   - Delete `ContentView.swift` (Xcode creates this by default)
   - The existing `ScorePulseApp.swift` will replace it

5. **Add Existing Files to Project**
   - In Xcode's Project Navigator (left sidebar), right-click on the "ScorePulse" folder
   - Select "Add Files to ScorePulse..."
   - Navigate to `/Users/anders.abrahamsen/apps/scorepulse/ScorePulse/`
   - Select the following folders (hold Cmd to select multiple):
     - `Models`
     - `Audio`
     - `Views`
     - `Scores`
   - **IMPORTANT**: In the dialog, check:
     - ✅ "Copy items if needed" (UNCHECK this - files are already in place)
     - ✅ "Create groups"
     - ✅ Add to targets: ScorePulse
   - Click "Add"

6. **Replace App Entry File**
   - Delete the Xcode-generated `ScorePulseApp.swift` if it exists in the project
   - Drag the existing `ScorePulseApp.swift` file into the project
   - Or add it via "Add Files to ScorePulse..." as above

7. **Verify bundled-scores.json is in the target**
   - Click on `bundled-scores.json` in the Project Navigator
   - In the File Inspector (right sidebar), check "Target Membership"
   - Ensure "ScorePulse" is checked

8. **Set Deployment Target**
   - Click on the project in the Project Navigator
   - Select the "ScorePulse" target
   - In "General" tab, set "Minimum Deployments" to iOS 15.0 or later

9. **Build and Run**
   - Select a simulator or device (iPhone 14 or later recommended)
   - Press Cmd+R or click the "Play" button
   - The app should build and run successfully

## Project Structure in Xcode

After adding files, your project should look like:

```
ScorePulse
├── ScorePulseApp.swift
├── Models
│   ├── TimeSignature.swift
│   ├── Bar.swift
│   ├── TempoChange.swift
│   ├── RehearsalMark.swift
│   ├── Score.swift
│   └── MetronomeSettings.swift
├── Audio
│   └── MetronomeEngine.swift
├── Views
│   ├── MetronomeView.swift
│   ├── ScoreListView.swift
│   └── ScorePlayerView.swift
├── Scores
│   └── bundled-scores.json
└── Assets.xcassets
    └── AppIcon.appiconset
```

## Troubleshooting

### "Cannot find 'MetronomeSettings' in scope"
- Make sure all files in the Models folder are added to the target
- Check that each .swift file has "ScorePulse" checked under Target Membership

### "Could not find bundled-scores.json"
- Select bundled-scores.json in Project Navigator
- Verify "Target Membership" includes ScorePulse in File Inspector
- The file should appear in "Copy Bundle Resources" build phase

### Build errors about missing imports
- Clean the build: Product → Clean Build Folder (Cmd+Shift+K)
- Rebuild: Product → Build (Cmd+B)

### Audio not playing
- Make sure you're testing on a physical device or simulator with audio enabled
- Check that the volume is up on the simulator/device
- The app requests audio session permission automatically

## Testing the App

### Simple Metronome Tab
1. Adjust BPM slider
2. Select time signature
3. Choose subdivision (quarter or eighth notes)
4. Tap "Start" - you should hear clicks with the downbeat at higher pitch

### Scores Tab
1. Browse the 4 included scores
2. Tap on a score to open the player
3. Adjust practice tempo (50%-150%)
4. Try navigation controls (Previous/Next Mark, Go to Bar)
5. Enable Rehearsal Mode and set a start bar
6. Tap "Start" - the metronome should follow the score's time signatures and tempi

## Next Steps

Once the project is working:
- Add app icons to Assets.xcassets/AppIcon.appiconset
- Test on physical device
- Create additional score files
- Customize the UI colors and styling
- Add your own musical pieces to bundled-scores.json

Enjoy using ScorePulse for your rehearsals!
