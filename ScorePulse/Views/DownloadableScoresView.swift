import SwiftUI

struct DownloadableScoresView: View {
    @StateObject private var downloadService = ScoreDownloadService.shared
    @EnvironmentObject var settings: MetronomeSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var downloadingScoreID: UUID?
    @State private var downloadError: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            Group {
                if downloadService.isLoading {
                    ProgressView("Loading scores...")
                } else if let errorMessage = downloadService.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(errorMessage)
                            .font(.headline)
                        Button("Retry") {
                            Task {
                                await downloadService.fetchAvailableScores()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if downloadService.availableScores.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No scores available")
                            .font(.headline)
                    }
                } else {
                    scoresList
                }
            }
            .navigationTitle("Download Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await downloadService.fetchAvailableScores()
        }
        .alert("Download Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadError ?? "Failed to download score")
        }
    }
    
    private var scoresList: some View {
        List {
            ForEach(downloadService.availableScores) { score in
                scoreRow(for: score)
            }
        }
    }
    
    private func scoreRow(for score: DownloadableScore) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(score.title)
                    .font(.headline)
                Text(score.composer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    Text("\(score.totalBars) bars")
                    Text("•")
                    Text("♩=\(score.defaultTempo)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isScoreDownloaded(score) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else if downloadingScoreID == score.id {
                ProgressView()
            } else {
                Button {
                    downloadScore(score)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func isScoreDownloaded(_ downloadableScore: DownloadableScore) -> Bool {
        settings.userScores.contains { $0.id == downloadableScore.id }
    }
    
    private func downloadScore(_ downloadableScore: DownloadableScore) {
        downloadingScoreID = downloadableScore.id
        
        Task {
            do {
                _ = try await downloadService.downloadScore(downloadableScore)
                // Reload user scores to show the newly downloaded score
                settings.loadUserScores()
                downloadingScoreID = nil
            } catch {
                downloadingScoreID = nil
                downloadError = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    DownloadableScoresView()
        .environmentObject(MetronomeSettings())
}
