import SwiftUI
import KajimiruKit

struct MemberSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let targetMember: Member

    @State private var selectedSourceMember: Member?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var linkedMembers: [Member] {
        appState.members.filter { $0.userId != nil && $0.id != targetMember.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("アカウントを紐づける住人")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(targetMember.displayName.prefix(1))
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                )
                            Text(targetMember.displayName)
                                .font(.headline)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    if linkedMembers.isEmpty {
                        Text("連携済みの住人がいません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(linkedMembers) { member in
                            Button {
                                selectedSourceMember = member
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(member.displayName.prefix(1))
                                                .font(.headline)
                                                .foregroundStyle(.red)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        if let userId = member.userId {
                                            Text(userId)
                                                .foregroundStyle(.primary)
                                        }
                                        Text("現在紐づいている住人：\(member.displayName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if selectedSourceMember?.id == member.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("紐づけしなおすアカウントを選択してください")
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("住人にアカウントを紐づける")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        Task {
                            await transferLink()
                        }
                    }
                    .disabled(selectedSourceMember == nil || isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }

    private func transferLink() async {
        guard let sourceMember = selectedSourceMember,
              let userId = sourceMember.userId else {
            errorMessage = "紐づけられるアカウントが見つかりません"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            try await appState.transferMemberLink(
                fromMemberId: sourceMember.id,
                toMemberId: targetMember.id,
                userId: userId
            )
            dismiss()
        } catch {
            errorMessage = "アカウントの紐づけに失敗しました: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}

#Preview {
    MemberSelectionSheet(targetMember: Member(
        displayName: "未連携の住人",
        groupId: UUID(),
        role: .member,
        createdBy: "admin",
        updatedBy: "admin"
    ))
    .environmentObject(AppState(useMockData: true))
}
