import SwiftUI
import KajimiruKit

struct ChoreLogHistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMonth = Date()

    private var filteredLogs: [ChoreLog] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        return appState.choreLogs.filter { log in
            log.createdAt >= monthStart && log.createdAt <= monthEnd
        }
    }

    private var groupedLogs: [(date: Date, logs: [ChoreLog])] {
        let calendar = Calendar.current

        // batchIdごとに重複を排除（複数実施者の場合は1つのログのみ表示）
        var seenBatchIds = Set<UUID>()
        let uniqueLogs = filteredLogs.sorted { $0.createdAt > $1.createdAt }.filter { log in
            if seenBatchIds.contains(log.batchId) {
                return false
            }
            seenBatchIds.insert(log.batchId)
            return true
        }

        let grouped = Dictionary(grouping: uniqueLogs) { log in
            calendar.startOfDay(for: log.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, logs: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            monthPicker

            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredLogs.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedLogs, id: \.date) { group in
                            dateDivider(date: group.date)

                            ForEach(group.logs) { log in
                                ChoreLogCard(log: log)
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                            }
                        }
                    }
                }
                .padding(.top)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("記録")
    }

    private var monthPicker: some View {
        HStack {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text(formatMonthYear(selectedMonth))
                .font(.headline)

            Spacer()

            if !isCurrentMonth {
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.clear)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        return selectedComponents.year == currentComponents.year &&
               selectedComponents.month == currentComponents.month
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("記録がありません")
                .font(.headline)
            Text("家事を記録すると、ここに履歴が表示されます")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    private func dateDivider(date: Date) -> some View {
        ZStack {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
                .padding(.horizontal)

            Text(formatDate(date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .background(Color(.systemGroupedBackground))
        }
        .padding(.vertical, 12)
        .padding(.bottom, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今日"
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日(E)"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        }
    }

    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct ChoreLogCard: View {
    @EnvironmentObject var appState: AppState
    let log: ChoreLog

    private var choreName: String {
        appState.chores.first { $0.id == log.choreId }?.title ?? "不明な家事"
    }

    private var performerNames: String {
        if log.performerCount > 1 {
            // 同じbatchIdを持つすべてのログを取得して実施者名を集める
            let batchLogs = appState.choreLogs.filter { $0.batchId == log.batchId }
            let names = batchLogs.map { appState.memberDisplayName(for: $0.performerId) }
            return names.joined(separator: "、")
        } else {
            return appState.memberDisplayName(for: log.performerId)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            VStack(spacing: 2) {
                Text(formatTime(log.createdAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 50, alignment: .leading)

            // Card content
            VStack(alignment: .leading, spacing: 8) {
                Text(choreName)
                    .font(.headline)

                Label(performerNames, systemImage: "person.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let memo = log.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ChoreLogHistoryView()
            .environmentObject({
                let state = AppState()
                Task { await state.loadMVPData() }
                return state
            }())
    }
}
