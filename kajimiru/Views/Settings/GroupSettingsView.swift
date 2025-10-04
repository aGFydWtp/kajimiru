import SwiftUI
import KajimiruKit

/// View for managing group settings including name, switching groups, creating new groups, and joining groups
struct GroupSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var editedGroupName: String = ""
    @State private var editedGroupIcon: String = ""
    @State private var isEditingName = false
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var currentMember: Member? {
        guard let group = appState.group,
              let authUID = authService.userID else { return nil }
        return appState.members.first { $0.groupId == group.id && $0.firebaseUid == authUID }
    }

    private var isAdmin: Bool {
        currentMember?.role == .admin
    }

    var body: some View {
        List {
            // Current Group Section
            if let group = appState.group {
                Section {
                    if isEditingName && isAdmin {
                        HStack {
                            TextField("グループ名", text: $editedGroupName)
                                .textFieldStyle(.roundedBorder)

                            Button("保存") {
                                Task {
                                    await saveGroupName()
                                }
                            }
                            .disabled(editedGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("キャンセル") {
                                isEditingName = false
                                editedGroupName = group.name
                            }
                        }
                    } else {
                        HStack {
                            Label {
                                Text(group.name)
                                    .font(.headline)
                            } icon: {
                                Image(systemName: group.icon ?? "house.fill")
                            }

                            Spacer()

                            if isAdmin {
                                Button("編集") {
                                    isEditingName = true
                                    editedGroupName = group.name
                                }
                            }
                        }
                    }
                } header: {
                    Text("現在のグループ")
                }

                // Admin-only icon selection
                if isAdmin {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(groupIcons, id: \.self) { icon in
                                    Button {
                                        editedGroupIcon = icon
                                        Task {
                                            await saveGroupIcon()
                                        }
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .frame(width: 50, height: 50)
                                            .background(icon == (group.icon ?? "house.fill") ? Color.blue.opacity(0.2) : Color.clear)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } header: {
                        Text("グループアイコン")
                    }
                }
            }

            // Switch Groups Section
            if appState.availableGroups.count > 1 {
                Section {
                    ForEach(appState.availableGroups.filter { $0.id != appState.group?.id }) { group in
                        Button {
                            Task {
                                await switchToGroup(group)
                            }
                        } label: {
                            HStack {
                                Label {
                                    Text(group.name)
                                } icon: {
                                    Image(systemName: group.icon ?? "house.fill")
                                }

                                Spacer()

                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("グループを切り替え")
                }
            }

            // Create New Group Section
            Section {
                NavigationLink {
                    InitialSetupView()
                        .environmentObject(appState)
                } label: {
                    Label("新しいグループを作成", systemImage: "plus.circle")
                }
            }

            // Join Group Section
            Section {
                NavigationLink {
                    InviteCodeInputView()
                        .environmentObject(appState)
                } label: {
                    Label("招待コードでグループに参加", systemImage: "arrow.right.circle")
                }
            }
        }
        .navigationTitle("グループ設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAvailableGroups()
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func loadAvailableGroups() async {
        do {
            print("🔍 GroupSettingsView: Loading available groups...")
            try await appState.loadAvailableGroups()
            print("✅ GroupSettingsView: Loaded \(appState.availableGroups.count) groups")
        } catch {
            print("❌ GroupSettingsView: Error loading groups - \(error)")
            errorMessage = "グループ一覧の読み込みに失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    private func saveGroupName() async {
        guard let group = appState.group else { return }

        let trimmedName = editedGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        do {
            try await appState.updateGroup(name: trimmedName, icon: group.icon)
            isEditingName = false
        } catch {
            errorMessage = "グループ名の更新に失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    private func saveGroupIcon() async {
        guard let group = appState.group else { return }

        do {
            try await appState.updateGroup(name: group.name, icon: editedGroupIcon)
        } catch {
            errorMessage = "グループアイコンの更新に失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    private func switchToGroup(_ group: KajimiruKit.Group) async {
        do {
            try await appState.switchToGroup(groupId: group.id)
            dismiss()
        } catch {
            errorMessage = "グループの切り替えに失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Icon Options

    private let groupIcons = [
        "house.fill",
        "building.2.fill",
        "person.2.fill",
        "person.3.fill",
        "heart.fill",
        "star.fill",
        "flag.fill",
        "cloud.fill"
    ]
}

#Preview {
    NavigationStack {
        GroupSettingsView()
            .environmentObject(AppState(useMockData: true))
            .environmentObject(AuthenticationService())
    }
}
