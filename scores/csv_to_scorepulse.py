#!/usr/bin/env python3
"""
CSV to ScorePulse Converter

Converts a CSV file with bar information into a .scorepulse JSON file.

CSV Format (semicolon-delimited):
BAR NUMBER;TIME SIGNATURE;DIVISION;TEMPO;REHEARSAL MARKING;TEXT MARKING

Usage:
    python csv_to_scorepulse.py input.csv output.scorepulse
"""

import csv
import json
import sys
import uuid
import re
from typing import List, Dict, Optional, Tuple


def generate_uuid() -> str:
    """Generate a UUID string."""
    return str(uuid.uuid4())


def validate_time_signature(ts: str) -> bool:
    """Validate time signature format (e.g., 4/4, 3/4, 5/8)."""
    if not ts:
        return False
    pattern = r'^\d+/\d+$'
    return bool(re.match(pattern, ts))


def parse_division(division: str) -> Optional[List[int]]:
    """Parse division string like '2+2+3' into [2, 2, 3]."""
    if not division or not division.strip():
        return None
    
    try:
        parts = division.strip().split('+')
        pattern = [int(p.strip()) for p in parts]
        if all(p > 0 for p in pattern):
            return pattern
        return None
    except (ValueError, AttributeError):
        return None


def validate_division_matches_time_signature(division: List[int], time_signature: str) -> Tuple[bool, str]:
    """
    Validate that the division (accent pattern) sums to the numerator of the time signature.
    Returns (is_valid, error_message).
    """
    parts = time_signature.split('/')
    numerator = int(parts[0])
    
    division_sum = sum(division)
    if division_sum != numerator:
        return False, f"Division '{'+'.join(map(str, division))}' sums to {division_sum}, but time signature '{time_signature}' requires {numerator}"
    
    return True, ""


def validate_tempo(tempo: str) -> Tuple[bool, Optional[int]]:
    """Validate tempo value. Returns (is_valid, tempo_int)."""
    try:
        tempo_int = int(tempo)
        if 20 <= tempo_int <= 300:
            return True, tempo_int
        return False, None
    except (ValueError, TypeError):
        return False, None


def parse_csv(csv_path: str) -> List[Dict]:
    """Parse CSV file and return list of bar data."""
    bars_data = []
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=';')
        
        for row in reader:
            bar_num_str = row.get('BAR NUMBER', '').strip()
            if not bar_num_str:
                continue
                
            try:
                bar_num = int(bar_num_str)
            except ValueError:
                print(f"Warning: Invalid bar number '{bar_num_str}', skipping row")
                continue
            
            bar_data = {
                'bar_number': bar_num,
                'time_signature': row.get('TIME SIGNATURE', '').strip(),
                'division': row.get('DIVISION', '').strip(),
                'tempo': row.get('TEMPO', '').strip(),
                'rehearsal_marking': row.get('REHEARSAL MARKING', '').strip(),
                'text_marking': row.get('TEXT MARKING', '').strip()
            }
            bars_data.append(bar_data)
    
    # Sort by bar number
    bars_data.sort(key=lambda x: x['bar_number'])
    
    return bars_data


def process_bars_data(bars_data: List[Dict]) -> Dict:
    """Process bar data and create score structure."""
    if not bars_data:
        raise ValueError("No valid bar data found in CSV")
    
    # Validate sequential bar numbers starting from 1
    expected_bar = 1
    for bar in bars_data:
        if bar['bar_number'] != expected_bar:
            raise ValueError(f"Bar numbers must be sequential starting from 1. Expected {expected_bar}, got {bar['bar_number']}")
        expected_bar += 1
    
    # Find first tempo and time signature
    default_tempo = None
    first_time_signature = None
    
    for bar in bars_data:
        if bar['tempo'] and default_tempo is None:
            is_valid, tempo_val = validate_tempo(bar['tempo'])
            if is_valid:
                default_tempo = tempo_val
            else:
                raise ValueError(f"Invalid tempo '{bar['tempo']}' at bar {bar['bar_number']}")
        
        if bar['time_signature'] and first_time_signature is None:
            if validate_time_signature(bar['time_signature']):
                first_time_signature = bar['time_signature']
            else:
                raise ValueError(f"Invalid time signature '{bar['time_signature']}' at bar {bar['bar_number']}")
        
        if default_tempo and first_time_signature:
            break
    
    if not default_tempo:
        raise ValueError("No tempo found in CSV. At least one bar must have a tempo value.")
    if not first_time_signature:
        raise ValueError("No time signature found in CSV. At least one bar must have a time signature.")
    
    # Process bars, tempo changes, and rehearsal marks
    bars = []
    tempo_changes = []
    rehearsal_marks = []
    
    current_time_signature = None
    current_accent_pattern = None
    
    for bar in bars_data:
        bar_num = bar['bar_number']
        
        # Parse division/accent pattern if present
        accent_pattern = None
        if bar['division']:
            accent_pattern = parse_division(bar['division'])
            if accent_pattern is None:
                raise ValueError(f"Invalid division '{bar['division']}' at bar {bar_num}. Use format like '2+3' or '2+2+3'")
        
        # Track time signature changes
        time_sig_changed = False
        if bar['time_signature']:
            if not validate_time_signature(bar['time_signature']):
                raise ValueError(f"Invalid time signature '{bar['time_signature']}' at bar {bar_num}")
            
            if bar['time_signature'] != current_time_signature:
                time_sig_changed = True
                current_time_signature = bar['time_signature']
        
        # Validate accent pattern matches time signature (if both present)
        if accent_pattern and current_time_signature:
            is_valid, error_msg = validate_division_matches_time_signature(accent_pattern, current_time_signature)
            if not is_valid:
                raise ValueError(f"At bar {bar_num}: {error_msg}")
        
        # /16 time signatures require an accent pattern
        if current_time_signature and current_time_signature.endswith('/16'):
            if time_sig_changed and not accent_pattern:
                raise ValueError(f"At bar {bar_num}: Time signature '{current_time_signature}' requires a division (e.g., '3+3+3+2' for 11/16)")
        
        # Check if accent pattern changed (even without time signature change)
        accent_pattern_changed = accent_pattern != current_accent_pattern and accent_pattern is not None
        
        # Add bar entry if time signature or accent pattern changed
        if time_sig_changed or accent_pattern_changed:
            if accent_pattern:
                current_accent_pattern = accent_pattern
            elif time_sig_changed:
                # Time signature changed but no new accent pattern - reset to None
                current_accent_pattern = None
            
            # Create time signature object
            if current_accent_pattern:
                time_sig_obj = {
                    'timeSignature': current_time_signature,
                    'accentPattern': current_accent_pattern
                }
            else:
                time_sig_obj = current_time_signature
            
            bars.append({
                'id': generate_uuid(),
                'number': bar_num,
                'timeSignature': time_sig_obj
            })
        
        # Track tempo changes
        if bar['tempo']:
            is_valid, tempo_val = validate_tempo(bar['tempo'])
            if not is_valid:
                raise ValueError(f"Invalid tempo '{bar['tempo']}' at bar {bar_num}")
            
            tempo_change = {
                'id': generate_uuid(),
                'bar': bar_num,
                'tempo': tempo_val
            }
            
            # Add text marking if present
            if bar['text_marking']:
                tempo_change['marking'] = bar['text_marking']
            
            tempo_changes.append(tempo_change)
        
        # Track rehearsal marks
        if bar['rehearsal_marking']:
            rehearsal_marks.append({
                'id': generate_uuid(),
                'name': bar['rehearsal_marking'],
                'bar': bar_num
            })
    
    total_bars = bars_data[-1]['bar_number']
    
    return {
        'default_tempo': default_tempo,
        'bars': bars,
        'tempo_changes': tempo_changes,
        'rehearsal_marks': rehearsal_marks,
        'total_bars': total_bars
    }


def create_score(bars_data: List[Dict], title: str, composer: str) -> Dict:
    """Create complete score object."""
    processed = process_bars_data(bars_data)
    
    score = {
        'id': generate_uuid(),
        'title': title,
        'composer': composer,
        'defaultTempo': processed['default_tempo'],
        'tempoChanges': processed['tempo_changes'],
        'rehearsalMarks': processed['rehearsal_marks'],
        'bars': processed['bars'],
        'totalBars': processed['total_bars']
    }
    
    return score


def main():
    if len(sys.argv) != 3:
        print("Usage: python csv_to_scorepulse.py input.csv output.scorepulse")
        sys.exit(1)
    
    input_csv = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        # Parse CSV
        print(f"Reading CSV file: {input_csv}")
        bars_data = parse_csv(input_csv)
        print(f"Found {len(bars_data)} bars")
        
        # Get metadata from user
        print("\nEnter score metadata:")
        title = input("Title: ").strip()
        if not title:
            print("Error: Title is required")
            sys.exit(1)
        
        composer = input("Composer: ").strip()
        if not composer:
            print("Error: Composer is required")
            sys.exit(1)
        
        # Create score
        print("\nProcessing...")
        score = create_score(bars_data, title, composer)
        
        # Write output
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(score, f, indent=2, ensure_ascii=False)
        
        print(f"\n✓ Successfully created {output_file}")
        print(f"  Title: {title}")
        print(f"  Composer: {composer}")
        print(f"  Total bars: {score['totalBars']}")
        print(f"  Default tempo: {score['defaultTempo']} BPM")
        print(f"  Time signature changes: {len(score['bars'])}")
        print(f"  Tempo changes: {len(score['tempoChanges'])}")
        print(f"  Rehearsal marks: {len(score['rehearsalMarks'])}")
        
    except FileNotFoundError:
        print(f"Error: File '{input_csv}' not found")
        sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
