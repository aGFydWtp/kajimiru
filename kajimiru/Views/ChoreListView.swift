import SwiftUI
import KajimiruKit

struct ChoreListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddChore = false

    var body: some View {
        List {
            if appState.chores.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("家事が登録されていません")
                        .font(.headline)
                    Text("右上の + ボタンから追加できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(appState.chores) { chore in
                    ChoreRow(chore: chore)
                }
            }
        }
        .navigationTitle("家事一覧")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddChore = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddChore) {
            AddChoreSheet()
        }
    }
}

struct ChoreRow: View {
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chore.title)
                .font(.headline)

            HStack(spacing: 12) {
                Label(
                    DisplayFormatters.weightDescription(chore.weight),
                    systemImage: "scalemass"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let notes = chore.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddChoreSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var weight = 1
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let weights = [1, 2, 3, 5, 8]

    var body: some View {
        NavigationStack {
            Form {
                Section("家事の内容") {
                    TextField("家事名", text: $title)
                    TextField("メモ（任意）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("大変度") {
                    Picker("大変度", selection: $weight) {
                        ForEach(weights, id: \.self) { w in
                            Text(DisplayFormatters.weightDescription(w)).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("一番簡単な家事を1として、その何倍大変かを選択")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("家事を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task { await addChore() }
                    }
                    .disabled(title.isEmpty || isSubmitting)
                }
            }
        }
    }

    private func addChore() async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await appState.addChore(
                title: title,
                weight: weight,
                notes: notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        ChoreListView()
            .environmentObject({
                let state = AppState()
                Task { await state.loadMVPData() }
                return state
            }())
    }
}
