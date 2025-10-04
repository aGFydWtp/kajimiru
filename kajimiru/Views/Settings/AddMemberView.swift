import SwiftUI

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var memberName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("メンバーの名前", text: $memberName)
                        .autocorrectionDisabled()
                } header: {
                    Text("新しいメンバー")
                } footer: {
                    Text("家族やルームメイトを追加します。アカウント未連携のメンバーとして登録されます。")
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("メンバーを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task {
                            await addMember()
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
        }
    }

    private var isValid: Bool {
        !memberName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addMember() async {
        let trimmedName = memberName.trimmingCharacters(in: .whitespaces)

        isLoading = true
        errorMessage = nil

        do {
            try await appState.addMember(displayName: trimmedName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    AddMemberView()
        .environmentObject(AppState(useMockData: true))
}
