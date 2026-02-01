import SwiftUI

struct ScoreListView: View {
    @EnvironmentObject var settings: MetronomeSettings
    @State private var searchText = ""
    @State private var showingDocumentPicker = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    
    var filteredBundledScores: [Score] {
        filterScores(settings.bundledScores)
    }
    
    var filteredUserScores: [Score] {
        filterScores(settings.userScores)
    }
    
    private func filterScores(_ scores: [Score]) -> [Score] {
        if searchText.isEmpty {
            return scores
        }
        return scores.filter { score in
            score.title.localizedCaseInsensitiveContains(searchText) ||
            score.composer.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !filteredUserScores.isEmpty {
                    Section(header: Text("My Scores")) {
                        ForEach(filteredUserScores) { score in
                            scoreRow(for: score)
                        }
                        .onDelete { indexSet in
                            deleteScores(at: indexSet, from: filteredUserScores)
                        }
                    }
                }
                
                if !filteredBundledScores.isEmpty {
                    Section(header: Text("Example Scores")) {
                        ForEach(filteredBundledScores) { score in
                            scoreRow(for: score)
                        }
                    }
                }
            }
            .navigationTitle("Scores")
            .searchable(text: $searchText, prompt: "Search scores")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(isPresented: $showingDocumentPicker) { url in
                    importScore(from: url)
                }
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
    }
    
    private func scoreRow(for score: Score) -> some View {
        NavigationLink(destination: ScorePlayerView(score: score)) {
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
                    if let firstBar = score.bars.first {
                        Text("•")
                        Text(firstBar.timeSignature.displayString)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func importScore(from url: URL) {
        do {
            try settings.importScore(from: url)
        } catch {
            importErrorMessage = "Failed to import score: \(error.localizedDescription)"
            showingImportError = true
        }
    }
    
    private func deleteScores(at offsets: IndexSet, from scores: [Score]) {
        for index in offsets {
            let score = scores[index]
            do {
                try settings.deleteUserScore(score)
            } catch {
                importErrorMessage = "Failed to delete score: \(error.localizedDescription)"
                showingImportError = true
            }
        }
    }
}

#Preview {
    ScoreListView()
        .environmentObject(MetronomeSettings())
}
