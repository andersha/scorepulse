# CSV to ScorePulse Converter

A command-line tool to create `.scorepulse` files from CSV spreadsheets.

## Quick Start

```bash
python3 csv_to_scorepulse.py input.csv output.scorepulse
```

You'll be prompted to enter the score title and composer name.

## CSV Format

Create a CSV file with semicolon (`;`) delimiters and the following columns:

```
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING
```

### Columns

- **BAR NUMBER** (required): Sequential bar numbers starting from 1
- **TIME SIGNATURE**: Time signature in format like `4/4`, `3/4`, `5/8`, `7/8` (required in at least one bar)
- **DIVISION**: Irregular timing division for accent patterns (e.g., `2+3` for 5/8, `2+2+3` for 7/8)
- **TEMPO**: Tempo in BPM (20-300) (required in at least one bar)
- **REHEARSAL MARKING**: Letters (A, B, C) or numbers (1, 2, 3) or text (Intro, Head, etc.)
- **TEXT MARKING**: Text descriptions for tempo changes (Allegro, Adagio, etc.)

### Rules

- **Leave cells empty** if there's no change/marking at that bar
- **Time signatures persist** until changed - you only need to specify when it changes
- **First tempo** becomes the default tempo for the score
- **First time signature** becomes the initial time signature
- **Bar numbers must be sequential** starting from 1

## Example

See `example-score.csv`:

```csv
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING
1;4/4;;120;A;
2;;;;;
3;3/4;;;;
4;;;;;
5;;;;;
6;;;;1;
7;;;;;
8;;;;;
9;4/4;;140;;Allegro
10;;;;;
20;7/8;2+2+3;80;;Adagio
```

This creates:
- 4/4 at bar 1, changes to 3/4 at bar 3, back to 4/4 at bar 9, then 7/8 with 2+2+3 division at bar 20
- Default tempo 120 BPM, changes to 140 BPM at bar 9 with "Allegro" marking, then 80 BPM at bar 20 with "Adagio"
- Rehearsal marks: "A" at bar 1, "1" at bar 6
- The 7/8 bar with `2+2+3` division creates an accent pattern [2, 2, 3] for irregular meter

## Generated Output

The tool creates a valid `.scorepulse` JSON file that can be imported into the ScorePulse iOS app:

```json
{
  "id": "uuid",
  "title": "Your Title",
  "composer": "Your Composer",
  "defaultTempo": 120,
  "tempoChanges": [...],
  "rehearsalMarks": [...],
  "bars": [...],
  "totalBars": 20
}
```

## Tips for Creating CSV Files

### Using Excel or Numbers
1. Create your spreadsheet with the columns above
2. Use semicolon as delimiter
3. Save as CSV (`.csv`)

### Using Google Sheets
1. Create your spreadsheet
2. File → Download → Comma-separated values (.csv)
3. You may need to convert commas to semicolons using a text editor

### Using a Text Editor
Just type the data with semicolons separating columns:

```
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING
1;4/4;;120;;
2;;;;;
3;;;;;
```

## Common Use Cases

### Score with constant time signature
Only specify the time signature once in bar 1:

```csv
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING
1;4/4;;120;;
2;;;;;
3;;;;;
```

### Score with only bar number rehearsal marks
Use numbers in the REHEARSAL MARKING column:

```csv
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING
1;4/4;;120;1;
17;;;;2;
33;;;;3;
```

### Complex score with tempo changes
Combine TEMPO and TEXT MARKING columns:

```csv
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING
1;4/4;;120;;Allegro
25;;;88;;Meno mosso
50;;;144;;Presto
```

### Irregular meters with divisions
Use the DIVISION column to specify accent patterns for irregular meters:

```csv
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING
1;5/8;2+3;120;;
17;7/8;2+2+3;;;
33;7/8;3+2+2;;;
```

Common divisions:
- **5/8**: `2+3` or `3+2`
- **7/8**: `2+2+3`, `3+2+2`, or `2+3+2`

## Error Messages

- **"Bar numbers must be sequential starting from 1"** - Make sure your bars are numbered 1, 2, 3... with no gaps
- **"No tempo found in CSV"** - At least one bar must have a tempo value
- **"No time signature found in CSV"** - At least one bar must have a time signature
- **"Invalid time signature"** - Use format like `4/4`, `3/4`, `6/8`
- **"Invalid tempo"** - Tempo must be a number between 20 and 300

## Importing to ScorePulse App

1. Generate the `.scorepulse` file using this tool
2. Transfer the file to your iOS device (AirDrop, iCloud, etc.)
3. Open the ScorePulse app
4. Tap the "+" button in the Scores tab
5. Select your `.scorepulse` file
6. The score will be imported and ready to use!
