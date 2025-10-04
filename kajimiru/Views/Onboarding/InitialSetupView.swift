import SwiftUI

struct InitialSetupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService

    @State private var groupName = "私の家"
    @State private var yourName = ""
    @State private var memberNames: [String] = []
    @State private var showError = false
    @State private var showingInviteCodeInput = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kajimiruへようこそ！")
                            .font(.title2.weight(.bold))
                        Text("まずはグループとメンバーを作成しましょう")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                Section {
                    TextField("例: 私の家", text: $groupName)
                        .autocorrectionDisabled()
                } header: {
                    Text("家事を管理する家の名前")
                }

                Section {
                    TextField("あなたの名前", text: $yourName)
                        .autocorrectionDisabled()
                } header: {
                    Text("あなたの名前")
                } footer: {
                    Text("あなたのアカウントに紐付けられます")
                }

                Section {
                    ForEach(memberNames.indices, id: \.self) { index in
                        HStack {
                            TextField("メンバー名", text: $memberNames[index])
                                .autocorrectionDisabled()

                            Button(role: .destructive) {
                                memberNames.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        memberNames.append("")
                    } label: {
                        Label("メンバーを追加", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("メンバー（任意）")
                } footer: {
                    Text("あなた以外の家族やルームメイトを追加できます")
                }

                Section {
                    Button {
                        Task {
                            await createGroup()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if appState.isLoading {
                                ProgressView()
                            } else {
                                Text("作成して始める")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || appState.isLoading)
                }

                Section {
                    Button {
                        showingInviteCodeInput = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("招待コードで参加")
                                .font(.headline)
                            Spacer()
                        }
                    }
                } footer: {
                    Text("既存のグループに招待コードで参加できます")
                }
            }
            .navigationTitle("初期設定")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingInviteCodeInput) {
                InviteCodeInputView()
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                }
            }
            .onAppear {
                // Set default name from Firebase Auth
                if yourName.isEmpty, let displayName = authService.userDisplayName {
                    yourName = displayName
                }
            }
        }
    }

    private var isValid: Bool {
        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespaces)
        let trimmedYourName = yourName.trimmingCharacters(in: .whitespaces)
        return !trimmedGroupName.isEmpty && !trimmedYourName.isEmpty
    }

    private func createGroup() async {
        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespaces)
        let trimmedYourName = yourName.trimmingCharacters(in: .whitespaces)
        let trimmedMemberNames = memberNames
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            try await appState.createInitialGroup(
                groupName: trimmedGroupName,
                yourName: trimmedYourName,
                memberNames: trimmedMemberNames
            )
        } catch {
            showError = true
        }
    }
}

#Preview {
    InitialSetupView()
        .environmentObject(AppState(useMockData: true))
}
