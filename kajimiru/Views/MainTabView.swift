import SwiftUI
import KajimiruKit

struct MainTabView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("ホーム", systemImage: "house.fill")
            }

            NavigationStack {
                ChoreListView()
            }
            .tabItem {
                Label("家事リスト", systemImage: "list.bullet")
            }

            NavigationStack {
                ChoreLogHistoryView()
            }
            .tabItem {
                Label("記録", systemImage: "clock.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape.fill")
            }
        }
        .environmentObject(appState)
        .task {
            await appState.loadMVPData()
        }
    }
}

struct RecordChoreSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let preselectedChore: Chore

    @State private var selectedChoreId: UUID?
    @State private var selectedPerformerIds: Set<UUID> = []
    @State private var memo = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(preselectedChore: Chore) {
        self.preselectedChore = preselectedChore
        _selectedChoreId = State(initialValue: preselectedChore.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Text(preselectedChore.title)
                
                Section("実施者") {
                    ForEach(appState.members.filter { !$0.isDeleted }) { member in
                        Toggle(isOn: Binding(
                            get: { selectedPerformerIds.contains(member.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedPerformerIds.insert(member.id)
                                } else {
                                    selectedPerformerIds.remove(member.id)
                                }
                            }
                        )) {
                            Text(member.displayName)
                        }
                    }
                }

                Section("メモ（任意）") {
                    TextField("メモ", text: $memo, axis: .vertical)
                        .padding( .vertical, 8)
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
                    .disabled(selectedChoreId == nil || selectedPerformerIds.isEmpty || isSubmitting)
                }
            }
        }
    }

    private func recordChore() async {
        guard let choreId = selectedChoreId,
              !selectedPerformerIds.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await appState.recordChore(
                choreId: choreId,
                performerIds: Array(selectedPerformerIds),
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
