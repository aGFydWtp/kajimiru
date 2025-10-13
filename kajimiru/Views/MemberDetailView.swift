import SwiftUI
import KajimiruKit

struct MemberDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService

    let member: Member

    @State private var displayName: String
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @State private var showingLinkAlert = false
    @State private var showingMemberSelection = false
    @State private var errorMessage: String?

    init(member: Member) {
        self.member = member
        _displayName = State(initialValue: member.displayName)
    }

    var isCurrentUser: Bool {
        member.userId == authService.userID
    }

    var currentMember: Member? {
        guard let userId = authService.userID else { return nil }
        return appState.members.first(where: { $0.userId == userId })
    }

    var canEdit: Bool {
        // Admin can edit all, or user can edit their own
        if let currentMember = currentMember {
            return currentMember.role == .admin || isCurrentUser
        }
        return false
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(displayName.prefix(1))
                                .font(.largeTitle)
                                .foregroundStyle(.red)
                        )
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section() {
                if isEditing {
                    TextField("名前", text: $displayName)
                        .autocorrectionDisabled()
                } else {
                    HStack {
                        Text("名前")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(displayName)
                    }
                }
            }

            Section("アカウント連携") {
                if let userId = member.userId {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("アカウントに連携済み")
                        }

                        Text("User ID: \(userId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("アカウント未連携")
                        }
                        Text("この住人はアカウントと連携されていません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingMemberSelection = true
                    } label: {
                        Label("アカウントと紐づける", systemImage: "arrow.left.arrow.right")
                    }

                    if isCurrentUser {
                        Button {
                            showingLinkAlert = true
                        } label: {
                            Label("この住人と紐づける", systemImage: "link.badge.plus")
                        }
                    }
                }
            }

            if canEdit && member.userId == nil {
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("住人を削除する", systemImage: "trash")
                    }
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
        .navigationTitle("住人の情報")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if canEdit {
                    if isEditing {
                        Button("保存") {
                            Task {
                                await saveMember()
                            }
                        }
                        .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button("編集") {
                            isEditing = true
                        }
                    }
                }
            }

            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        displayName = member.displayName
                        isEditing = false
                    }
                }
            }
        }
        .alert("住人を削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                Task {
                    await deleteMember()
                }
            }
        } message: {
            Text("この住人を削除しますか？この操作は取り消せません。")
        }
        .alert("アカウントに連携", isPresented: $showingLinkAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("連携") {
                Task {
                    await linkMember()
                }
            }
        } message: {
            Text("この住人を現在のアカウントに連携しますか？")
        }
        .sheet(isPresented: $showingMemberSelection) {
            MemberSelectionSheet(targetMember: member)
                .environmentObject(appState)
        }
    }

    private func saveMember() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        do {
            try await appState.updateMember(
                memberId: member.id,
                displayName: trimmedName
            )
            isEditing = false
            errorMessage = nil
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }

    private func deleteMember() async {
        do {
            try await appState.deleteMember(memberId: member.id)
            dismiss()
        } catch {
            errorMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }

    private func linkMember() async {
        guard let firebaseUid = authService.userID else {
            errorMessage = "認証情報が見つかりません"
            return
        }

        do {
            try await appState.linkMemberToUser(
                memberId: member.id,
                firebaseUid: firebaseUid
            )
            errorMessage = nil
        } catch {
            errorMessage = "連携に失敗しました: \(error.localizedDescription)"
        }
    }

    private func unlinkMember() async {
        do {
            try await appState.unlinkMember(memberId: member.id)
            errorMessage = nil
        } catch {
            errorMessage = "連携解除に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        MemberDetailView(member: Member(
            userId: "user123",
            displayName: "太郎",
            groupId: UUID(),
            role: .admin,
            createdBy: "admin",
            updatedBy: "admin"
        ))
        .environmentObject(AppState(useMockData: true))
        .environmentObject(AuthenticationService())
    }
}
