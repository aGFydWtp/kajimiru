import SwiftUI
import KajimiruKit

struct ChoreListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddChore = false
    @State private var editingChore: Chore?
    @State private var choreToDelete: Chore?
    @State private var showingDeleteAlert = false
    @State private var recordingChore: Chore?

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
    @State private var isFavorite = false
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
                
                Section {
                    Toggle("お気に入り", isOn: $isFavorite)
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
                isFavorite: isFavorite,
                notes: notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

struct EditChoreSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let chore: Chore

    @State private var title: String
    @State private var weight: Int
    @State private var notes: String
    @State private var isFavorite: Bool
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let weights = [1, 2, 3, 5, 8]

    init(chore: Chore) {
        self.chore = chore
        _title = State(initialValue: chore.title)
        _weight = State(initialValue: chore.weight)
        _notes = State(initialValue: chore.notes ?? "")
        _isFavorite = State(initialValue: chore.isFavorite)
    }

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

                Section {
                    Toggle("お気に入り", isOn: $isFavorite)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("家事を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await updateChore() }
                    }
                    .disabled(title.isEmpty || isSubmitting)
                }
            }
        }
    }

    private func updateChore() async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await appState.updateChore(
                choreId: chore.id,
                title: title,
                weight: weight,
                notes: notes.isEmpty ? nil : notes,
                isFavorite: isFavorite
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
