import SwiftUI
import KajimiruKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingSignOutAlert = false
    @State private var showingAddMember = false
    @State private var showingInviteCode = false

    var body: some View {
        List {
            Section("グループ情報") {
                if let group = appState.group {
                    NavigationLink {
                        GroupSettingsView()
                            .environmentObject(appState)
                    } label: {
                        HStack {
                            if let icon = group.icon {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(.red)
                            }
                            Text(group.name)
                                .font(.headline)
                            
                            Spacer()
                        }
                    }
                }
            }

            Section("メンバー") {
                if appState.members.isEmpty {
                    Text("メンバーがいません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.members.filter { !$0.isDeleted }) { member in
                        MemberRow(member: member)
                    }
                }

                Button {
                    showingAddMember = true
                } label: {
                    Label("メンバーを追加", systemImage: "person.badge.plus.fill")
                }
            }

            Section {
                Button {
                    showingInviteCode = true
                } label: {
                    Label("招待コードを表示", systemImage: "qrcode")
                }
            } header: {
                Text("家族・ルームメイトを招待")
            } footer: {
                Text("招待コードを共有して、家族やルームメイトをグループに招待できます")
            }

            Section("アカウント") {
                if let email = authService.userEmail {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ログイン中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(email)
                            .font(.body)
                    }
                }

                Button(role: .destructive) {
                    showingSignOutAlert = true
                } label: {
                    Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

        }
        .navigationTitle("設定")
        .sheet(isPresented: $showingAddMember) {
            AddMemberView()
        }
        .sheet(isPresented: $showingInviteCode) {
            InviteCodeDisplayView()
        }
        .alert("サインアウト", isPresented: $showingSignOutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("サインアウト", role: .destructive) {
                do {
                    try authService.signOut()
                } catch {
                    // Error handling
                }
            }
        } message: {
            Text("サインアウトしますか？")
        }
    }
}

struct MemberRow: View {
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.displayName.prefix(1))
                        .font(.headline)
                        .foregroundStyle(.red)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.body)

                if let userId = member.userId {
                    Text("ユーザーID: \(userId.uuidString.prefix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("アカウント未連携")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
