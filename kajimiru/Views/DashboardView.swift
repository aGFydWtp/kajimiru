import SwiftUI
import KajimiruKit

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var weeklySnapshot: WorkloadSnapshot?
    @State private var selectedPeriod: Period = .weekly
    @State private var editingChore: Chore?
    @State private var choreToDelete: Chore?
    @State private var showingDeleteAlert = false
    @State private var recordingChore: Chore?

    enum Period: String, CaseIterable {
        case weekly = "週次"
        case monthly = "月次"
    }

    var favoriteChores: [Chore] {
        appState.chores.filter { $0.isFavorite }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Dashboard Section
                dashboardSection
                
                // Quick Actions Section
                quickActionsSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ホーム")
        .sheet(item: $editingChore) { chore in
            EditChoreSheet(chore: chore)
        }
        .sheet(item: $recordingChore) { chore in
            RecordChoreSheet(preselectedChore: chore)
        }
        .alert("家事を削除", isPresented: $showingDeleteAlert, presenting: choreToDelete) { chore in
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                Task {
                    await appState.deleteChore(choreId: chore.id)
                }
            }
        } message: { chore in
            Text("「\(chore.title)」を削除しますか？")
        }
        .task {
            await loadSnapshot()
        }
        .onChange(of: selectedPeriod) {
            Task { await loadSnapshot() }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("クイックアクション")
                .font(.title2.weight(.bold))
                .padding(.horizontal)

            if favoriteChores.isEmpty {
                quickActionsEmptyState
            } else {
                quickActionsGrid
            }
        }
    }

    private var quickActionsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("お気に入りの家事を設定すると、ここに表示されます")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }

    private var quickActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(favoriteChores) { chore in
                ChoreTile(chore: chore)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        recordingChore = chore
                    }
                    .contextMenu {
                        Button {
                            editingChore = chore
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            choreToDelete = chore
                            showingDeleteAlert = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal)
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
    }

    private func workloadCard(snapshot: WorkloadSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(DisplayFormatters.intervalDescription(snapshot.interval))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(snapshot.contributions, id: \.userId) { summary in
                    contributionRow(summary, totalWeight: snapshot.totalWeight)
                }
            }
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
            }

            ProgressView(value: summary.shareOfTotalWeight(totalWeight))
                .tint(.accentColor)

            HStack {
                Text(percentageString(summary.shareOfTotalWeight(totalWeight)))
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

struct ChoreTile: View {
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Spacer()
                Text(DisplayFormatters.weightDescription(chore.weight))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(chore.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let notes = chore.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
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
