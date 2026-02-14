import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings = AppSettings.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            appSettings.appearanceMode = mode
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                Text(mode.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if appSettings.appearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how ScorePulse appears. System follows your device settings.")
                }
                
                Section {
                    ForEach(VolumeLevel.allCases) { level in
                        Button {
                            appSettings.volumeLevel = level
                        } label: {
                            HStack {
                                Image(systemName: level.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                Text(level.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if appSettings.volumeLevel == level {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Click Volume")
                } footer: {
                    Text("Adjust the metronome click volume. High is recommended for rehearsals with multiple players.")
                }
                
                Section {
                    Toggle("Show Sample Scores", isOn: $appSettings.showSampleScores)
                } header: {
                    Text("Scores")
                } footer: {
                    Text("When enabled, example scores will be shown in the Scores tab.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
