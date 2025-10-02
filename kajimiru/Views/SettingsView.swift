import SwiftUI
import KajimiruKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section("グループ情報") {
                if let group = appState.group {
                    HStack {
                        if let icon = group.icon {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(.red)
                        }
                        Text(group.name)
                            .font(.headline)
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
            }

            Section {
                Text("MVP版では、メンバー管理機能は未実装です")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("設定")
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
            .environmentObject({
                let state = AppState()
                Task { await state.loadMVPData() }
                return state
            }())
    }
}
