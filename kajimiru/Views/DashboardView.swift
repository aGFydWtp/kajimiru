import SwiftUI
import KajimiruKit

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var weeklySnapshot: WorkloadSnapshot?
    @State private var selectedPeriod: Period = .weekly

    enum Period: String, CaseIterable {
        case weekly = "週次"
        case monthly = "月次"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Period selector
                Picker("表示期間", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Workload snapshot
                if let snapshot = weeklySnapshot, snapshot.totalCount > 0 {
                    workloadCard(snapshot: snapshot)
                } else {
                    emptyStateCard
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ダッシュボード")
        .task {
            await loadSnapshot()
        }
        .onChange(of: selectedPeriod) {
            Task { await loadSnapshot() }
        }
    }

    private func workloadCard(snapshot: WorkloadSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("家事分担状況")
                .font(.headline)

            Text(DisplayFormatters.intervalDescription(snapshot.interval))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(snapshot.contributions, id: \.userId) { summary in
                    contributionRow(summary, totalWeight: snapshot.totalWeight)
                }
            }

            HStack {
                Text("合計")
                Spacer()
                Text("\(snapshot.totalCount)件 / \(DisplayFormatters.weightDescription(snapshot.totalWeight))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }

    private func contributionRow(_ summary: ContributorSummary, totalWeight: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(appState.memberDisplayName(for: summary.userId))
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("データがありません")
                .font(.headline)
            Text("家事を記録すると、ここに分担状況が表示されます")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }

    private func loadSnapshot() async {
        weeklySnapshot = try? await appState.getWeeklySnapshot()
    }

    private func percentageString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject({
                let state = AppState()
                Task { await state.loadMVPData() }
                return state
            }())
    }
}
