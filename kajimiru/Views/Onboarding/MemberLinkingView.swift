import SwiftUI
import KajimiruKit

struct MemberLinkingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var inviteService = InviteService()

    let groupId: UUID
    let inviteCode: String

    @State private var linkedMembers: [InviteService.MemberInfo] = []
    @State private var unlinkedMembers: [InviteService.MemberInfo] = []
    @State private var selectedMemberId: String?
    @State private var newMemberName = ""
    @State private var selectionMode: SelectionMode = .selectExisting
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum SelectionMode {
        case selectExisting
        case createNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メンバーの紐付け")
                            .font(.headline)
                        Text("既存のメンバーとして参加するか、新しいメンバーを作成します")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                // Section 1: Already linked members (read-only, grayed out)
                if !linkedMembers.isEmpty {
                    Section {
                        ForEach(linkedMembers, id: \.id) { member in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(member.name)
                                        .foregroundStyle(.secondary)
                                    Text("既に接続されています")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    } header: {
                        Text("接続済みメンバー")
                    } footer: {
                        Text("これらのメンバーは既に他のアカウントと接続されています")
                    }
                }

                // Section 2: Unlinked members (selectable)
                if !unlinkedMembers.isEmpty {
                    Section {
                        ForEach(unlinkedMembers, id: \.id) { member in
                            Button {
                                selectionMode = .selectExisting
                                selectedMemberId = member.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.name)
                                            .foregroundStyle(.primary)
                                        Text("未接続")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectionMode == .selectExisting && selectedMemberId == member.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("未接続のメンバーから選択")
                    } footer: {
                        Text("このメンバーとしてログインできるようになります")
                    }
                }

                // Section 3: Create new member
                Section {
                    Button {
                        selectionMode = .createNew
                        selectedMemberId = nil
                    } label: {
                        HStack {
                            Text("新しいメンバーとして参加")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectionMode == .createNew {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }

                    if selectionMode == .createNew {
                        TextField("あなたの名前", text: $newMemberName)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("新規メンバー作成")
                } footer: {
                    if selectionMode == .createNew {
                        Text("新しいメンバーとしてグループに参加します")
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("メンバー選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("参加") {
                        Task {
                            await joinGroup()
                        }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .task {
                await loadMembers()
                // Set default name from Firebase Auth
                if newMemberName.isEmpty, let displayName = authService.userDisplayName {
                    newMemberName = displayName
                }
            }
        }
    }

    private var isValid: Bool {
        switch selectionMode {
        case .selectExisting:
            return selectedMemberId != nil
        case .createNew:
            return !newMemberName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func loadMembers() async {
        do {
            let response = try await inviteService.getGroupMembers(byInviteCode: inviteCode)

            linkedMembers = response.userConnectedMembers
            unlinkedMembers = response.nonConnectedMembers

            // Auto-select first unlinked member if available
            if !unlinkedMembers.isEmpty {
                selectionMode = .selectExisting
                selectedMemberId = unlinkedMembers.first?.id
            } else {
                selectionMode = .createNew
            }
        } catch {
            errorMessage = "メンバーの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    private func joinGroup() async {
        guard let firebaseUid = authService.userID else {
            errorMessage = "認証情報が見つかりません"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let memberName: String
            let existingMemberId: UUID?

            switch selectionMode {
            case .selectExisting:
                guard let selectedId = selectedMemberId,
                      let memberUUID = UUID(uuidString: selectedId) else {
                    errorMessage = "メンバーが選択されていません"
                    isLoading = false
                    return
                }
                existingMemberId = memberUUID
                memberName = unlinkedMembers.first { $0.id == selectedId }?.name ?? ""
            case .createNew:
                existingMemberId = nil
                memberName = newMemberName.trimmingCharacters(in: .whitespaces)
            }

            // Call Cloud Function to add/link member
            let response = try await inviteService.addMember(
                withInviteCode: inviteCode,
                existingMemberId: existingMemberId,
                memberName: memberName,
                firebaseUid: firebaseUid
            )

            // Create or update User document
            guard let groupUUID = UUID(uuidString: response.groupId) else {
                errorMessage = "グループIDの形式が不正です"
                isLoading = false
                return
            }

            try await appState.createOrUpdateUserAfterJoin(
                firebaseUid: firebaseUid,
                displayName: memberName,
                groupId: groupUUID
            )

            // Switch to the joined group
            try await appState.switchToGroup(groupId: groupUUID)

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    MemberLinkingView(
        groupId: UUID(),
        inviteCode: "ABCD-1234"
    )
    .environmentObject(AppState(useMockData: true))
    .environmentObject(AuthenticationService())
}
