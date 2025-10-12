import SwiftUI
import KajimiruKit

struct InviteCodeInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var inviteService = InviteService()

    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMemberLinking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("招待コードでグループに参加")
                            .font(.headline)
                        Text("家族やルームメイトから送られた招待コードを入力してください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("XXXX-XXXX", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: inviteCode) { _, newValue in
                            // Auto-format with hyphen
                            let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
                            if filtered.count == 4 && !filtered.contains("-") {
                                inviteCode = filtered + "-"
                            } else {
                                inviteCode = filtered.prefix(9).map { String($0) }.joined()
                            }
                        }
                } header: {
                    Text("招待コード")
                } footer: {
                    Text("例: ABCD-1234")
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("招待コード入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("次へ") {
                        Task {
                            await validateCodeAndProceed()
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
            .sheet(isPresented: $showMemberLinking) {
                MemberLinkingView(
                    groupId: UUID(),
                    inviteCode: inviteCode.trimmingCharacters(in: .whitespaces)
                )
                .environmentObject(appState)
                .environmentObject(authService)
            }
        }
    }

    private var isValid: Bool {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespaces)
        return trimmedCode.count >= 8
    }

    private func validateCodeAndProceed() async {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespaces)

        isLoading = true
        errorMessage = nil

        do {
            // Validate invite code by calling Cloud Function
            // This will check if the code exists and is valid
            _ = try await inviteService.getGroupMembers(byInviteCode: trimmedCode)
            isLoading = false
            showMemberLinking = true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    InviteCodeInputView()
        .environmentObject(AppState(useMockData: true))
        .environmentObject(AuthenticationService())
}
