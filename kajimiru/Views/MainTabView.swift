import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @State private var showingRecordSheet = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                NavigationStack {
                    DashboardView()
                }
                .tabItem {
                    Label("ダッシュボード", systemImage: "chart.bar.fill")
                }

                NavigationStack {
                    ChoreListView()
                }
                .tabItem {
                    Label("家事一覧", systemImage: "list.bullet")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
            }
            .environmentObject(appState)

            // Floating Action Button
            Button {
                showingRecordSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
            .sheet(isPresented: $showingRecordSheet) {
                RecordChoreSheet()
                    .environmentObject(appState)
            }
        }
        .task {
            await appState.loadMVPData()
        }
    }
}

struct RecordChoreSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var selectedChoreId: UUID?
    @State private var selectedPerformerId: UUID?
    @State private var memo = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("家事") {
                    Picker("実施した家事", selection: $selectedChoreId) {
                        Text("選択してください").tag(nil as UUID?)
                        ForEach(appState.chores) { chore in
                            Text(chore.title).tag(chore.id as UUID?)
                        }
                    }
                }

                Section("実施者") {
                    Picker("誰がやった？", selection: $selectedPerformerId) {
                        Text("選択してください").tag(nil as UUID?)
                        ForEach(appState.members.filter { !$0.isDeleted }) { member in
                            Text(member.displayName).tag(member.id as UUID?)
                        }
                    }
                }

                Section("メモ（任意）") {
                    TextField("メモ", text: $memo, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("家事を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("記録") {
                        Task { await recordChore() }
                    }
                    .disabled(selectedChoreId == nil || selectedPerformerId == nil || isSubmitting)
                }
            }
        }
    }

    private func recordChore() async {
        guard let choreId = selectedChoreId,
              let performerId = selectedPerformerId else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await appState.recordChore(
                choreId: choreId,
                performerId: performerId,
                memo: memo.isEmpty ? nil : memo
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

#Preview {
    MainTabView()
}
