import SwiftUI
import KajimiruKit

struct InviteCodeDisplayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var inviteCode: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                } else if let code = inviteCode {
                    // Success state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                            .padding(.top, 32)

                        Text("招待コード")
                            .font(.title2.weight(.bold))

                        Text("家族やルームメイトにこのコードを共有してください")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Invite code display
                        Text(code)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            )
                            .padding(.horizontal)

                        // Copy button
                        Button {
                            UIPasteboard.general.string = code
                            showCopiedAlert = true
                        } label: {
                            Label("コードをコピー", systemImage: "doc.on.doc.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        .alert("コピーしました", isPresented: $showCopiedAlert) {
                            Button("OK") {}
                        } message: {
                            Text("招待コードをクリップボードにコピーしました")
                        }

                        // Expiration info
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.secondary)
                                Text("有効期限: 30日間")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                Image(systemName: "infinity")
                                    .foregroundStyle(.secondary)
                                Text("使用回数: 無制限")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()

                        Spacer()
                    }
                } else if let errorMessage = errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)

                        Text("エラー")
                            .font(.title2.weight(.bold))

                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("再試行") {
                            Task {
                                await generateInviteCode()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("招待コード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .task {
                await generateInviteCode()
            }
        }
    }

    private func generateInviteCode() async {
        isLoading = true
        errorMessage = nil
        inviteCode = nil

        do {
            let code = try await appState.generateInviteCode()
            inviteCode = code
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    InviteCodeDisplayView()
        .environmentObject(AppState(useMockData: true))
}
