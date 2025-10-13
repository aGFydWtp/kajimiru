import SwiftUI
import KajimiruKit

/// View for managing group settings including name, switching groups, creating new groups, and joining groups
struct GroupSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var editedGroupName: String = ""
    @State private var editedGroupIcon: String = ""
    @State private var showEditNameDialog = false
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteAlert = false

    private var currentMember: Member? {
        guard let group = appState.group,
              let authUID = authService.userID else { return nil }
        return appState.members.first { $0.groupId == group.id && $0.userId == authUID }
    }

    private var isAdmin: Bool {
        currentMember?.role == .admin
    }

    var body: some View {
        List {
            // Current Group Section
            if let group = appState.group {
                Section {
                    // Group name row
                    HStack {
                        Label {
                            Text(group.name)
                                .font(.headline)
                        } icon: {
                            Image(systemName: group.icon ?? "house.fill")
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        if isAdmin {
                            Button("編集") {
                                editedGroupName = group.name
                                showEditNameDialog = true
                            }
                        }
                    }

                    // Icon selection (admin only)
                    if isAdmin {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("アイコン")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

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
                                                .foregroundStyle(icon == (group.icon ?? "house.fill") ? .blue : .primary)
                                                .frame(width: 50, height: 50)
                                                .background(icon == (group.icon ?? "house.fill") ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Delete Group Section (Admin only)
                if isAdmin {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("住まいをを削除", systemImage: "trash")
                        }
                    } footer: {
                        Text("住まいをを削除すると、関連するすべてのデータが完全に削除されます。この操作は取り消せません。")
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
                    Text("住まいを切り替える")
                }
            }

            Section {
                Button {
                    showCreateGroup = true
                } label: {
                    Label("新しい住まいを作成", systemImage: "plus.circle")
                }

                Button {
                    showJoinGroup = true
                } label: {
                    Label("招待コードで住まいに参加", systemImage: "arrow.right.circle")
                }
            }
        }
        .navigationTitle("住まいの情報")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateGroup) {
            InitialSetupView(title: "新しい住まいを作成", isInitialSetup: false, showInviteOption: false).environmentObject(appState)
        }
        .sheet(isPresented: $showJoinGroup) {
            InviteCodeInputView()
        }
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
        .alert("住まいの名称を編集", isPresented: $showEditNameDialog) {
            TextField("住まいの名称", text: $editedGroupName)
            Button("保存") {
                Task {
                    await saveGroupName()
                }
            }
            Button("キャンセル", role: .cancel) {
                showEditNameDialog = false
            }
        } message: {
            Text("新しい住まいの名称を入力してください")
        }
        .alert("住まいを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                Task {
                    await deleteGroup()
                }
            }
        } message: {
            Text("この住まいを削除しますか？住まいに関連するすべてのデータが完全に削除されます。この操作は取り消せません。")
        }
    }

    // MARK: - Actions

    private func loadAvailableGroups() async {
        do {
            try await appState.loadAvailableGroups()
        } catch {
            errorMessage = "住まいの一覧の読み込みに失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    private func saveGroupName() async {
        guard let group = appState.group else {
            showEditNameDialog = false
            return
        }

        let trimmedName = editedGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "住まいの名称を入力してください"
            showEditNameDialog = false
            showError = true
            return
        }

        do {
            try await appState.updateGroup(name: trimmedName, icon: group.icon)
            showEditNameDialog = false
        } catch {
            errorMessage = "住まいの名称の更新に失敗しました: \(error.localizedDescription)"
            showEditNameDialog = false
            showError = true
        }
    }

    private func saveGroupIcon() async {
        guard let group = appState.group else {
            return
        }

        do {
            try await appState.updateGroup(name: group.name, icon: editedGroupIcon)
        } catch {
            errorMessage = "住まいのアイコンの更新に失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    private func switchToGroup(_ group: KajimiruKit.Group) async {
        do {
            try await appState.switchToGroup(groupId: group.id)
            dismiss()
        } catch {
            errorMessage = "住まいの切り替えに失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    private func deleteGroup() async {
        do {
            try await appState.deleteGroup()
            dismiss()
        } catch {
            errorMessage = "住まいの削除に失敗しました: \(error.localizedDescription)"
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
