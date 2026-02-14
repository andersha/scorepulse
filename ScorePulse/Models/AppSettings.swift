import Foundation
import SwiftUI

/// Appearance mode options
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

/// Click volume level options
enum VolumeLevel: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var id: String { rawValue }
    
    var amplitude: Float {
        switch self {
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.9
        }
    }
    
    var mixerVolume: Float {
        switch self {
        case .low: return 0.6
        case .medium: return 0.8
        case .high: return 1.0
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "speaker.wave.1.fill"
        case .medium: return "speaker.wave.2.fill"
        case .high: return "speaker.wave.3.fill"
        }
    }
}

/// Global app settings with persistence
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("showSampleScores") var showSampleScores: Bool = true
    @AppStorage("volumeLevel") private var volumeLevelRaw: String = VolumeLevel.high.rawValue
    
    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set {
            appearanceModeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var volumeLevel: VolumeLevel {
        get { VolumeLevel(rawValue: volumeLevelRaw) ?? .high }
        set {
            volumeLevelRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    private init() {}
}
