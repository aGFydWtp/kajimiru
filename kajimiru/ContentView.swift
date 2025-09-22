import SwiftUI
import KajimiruKit

private typealias HouseholdGroup = KajimiruKit.Group

struct ContentView: View {
    @StateObject private var viewModel: ChoreDashboardViewModel

    @MainActor
    init(viewModel: @autoclosure @escaping @MainActor () -> ChoreDashboardViewModel = ChoreDashboardViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.group == nil {
                    loadingView
                } else if let group = viewModel.group {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            groupHeader(group)
                            choreSection(viewModel.chores)
                            workloadSection()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Kajimiru")
        }
        .task {
            await viewModel.loadDemoData()
        }
    }
}

private extension ContentView {
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("サンプルデータを読み込み中…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("データの読み込みに失敗しました")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: {
                Task { await viewModel.loadDemoData() }
            }) {
                Text("再試行")
                    .font(.body)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "house")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Kajimiru へようこそ")
                .font(.title3.weight(.semibold))
            Text("家族やチームでの家事ログがここに集約されます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func groupHeader(_ group: HouseholdGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let icon = group.icon {
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title2.bold())
                    Text("メンバー \(viewModel.groupMembers.count)人")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if viewModel.groupMembers.isEmpty == false {
                Text(viewModel.groupMembers.map { $0.displayName }.joined(separator: "・"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func choreSection(_ chores: [Chore]) -> some View {
        sectionCard(title: "共有中の家事") {
            if chores.isEmpty {
                Text("まだ家事が登録されていません。サンプルデータを読み込むと一覧が表示されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chores) { chore in
                        choreCard(chore)
                    }
                }
            }
        }
    }

    private func choreCard(_ chore: Chore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chore.title)
                .font(.subheadline.weight(.semibold))

            infoRow(icon: "scalemass", text: DisplayFormatters.weightDescription(chore.weight))

            if let notes = chore.notes, notes.isEmpty == false {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }

    private func workloadSection() -> some View {
        sectionCard(title: "直近の貢献状況") {
            if let snapshot = viewModel.latestWeeklySnapshot, snapshot.totalCount > 0 {
                Text(DisplayFormatters.intervalDescription(snapshot.interval))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.contributions, id: \.userId) { summary in
                        contributionRow(summary, totalWeight: snapshot.totalWeight, totalCount: snapshot.totalCount)
                    }
                }

                Text("合計 \(snapshot.totalCount)件 / \(DisplayFormatters.weightDescription(snapshot.totalWeight))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("まだ十分な実績がありません。家事の実施を記録するとここでバランスを確認できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func contributionRow(_ summary: ContributorSummary, totalWeight: Int, totalCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.userDisplayName(for: summary.userId))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(summary.completedCount)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: summary.shareOfTotalWeight(totalWeight))
                .tint(.accentColor)

            HStack {
                Text(percentageString(summary.shareOfTotalWeight(totalWeight)))
                Spacer()
                Text(DisplayFormatters.weightDescription(summary.totalWeight))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func percentageString(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value)) ?? "0%"
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    ContentView(viewModel: ChoreDashboardViewModel.preview())
}
