import SwiftUI
import KajimiruKit

struct GroupSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingInviteCodeInput = false
    @State private var showingGroupCreation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("グループを選択")
                        .font(.title2.weight(.bold))
                    Text("参加しているグループから選択してください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGroupedBackground))

                // Group List
                if appState.availableGroups.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()

                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 8) {
                                Text("グループがありません")
                                    .font(.headline)
                                Text("新しいグループを作成するか、招待コードで参加してください")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Button {
                            showingGroupCreation = true
                        } label: {
                            Label("新しいグループを作成", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)

                        Spacer()
                    }
                } else {
                    List {
                        ForEach(appState.availableGroups) { group in
                            GroupRow(group: group)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task {
                                        await appState.selectGroup(group)
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                // Invite Code Button
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        showingInviteCodeInput = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode")
                            Text("招待コードで参加")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingInviteCodeInput) {
                InviteCodeInputView()
            }
            .sheet(isPresented: $showingGroupCreation) {
                InitialSetupView(
                    title: "新しいグループを作成",
                    isInitialSetup: false,
                    showInviteOption: false
                )
            }
            .overlay {
                if appState.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
}

struct GroupRow: View {
    let group: KajimiruKit.Group
    @EnvironmentObject var appState: AppState

    private var memberCount: Int {
        // This is an approximation - we don't have member count in Group model
        // In a real app, you'd fetch this or store it in the Group
        appState.members.filter { $0.groupId == group.id }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            // Group Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: group.icon ?? "house.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            // Group Info
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(memberCount)人", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(formatDate(group.updatedAt), systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    GroupSelectionView()
        .environmentObject(AppState(useMockData: true))
}
