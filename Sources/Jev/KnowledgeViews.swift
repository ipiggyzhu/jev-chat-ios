import SwiftUI

struct KnowledgeView: View {
    @EnvironmentObject var store: AppState
    @State private var editingNote: Note?
    @State private var editingContact: Contact?
    @State private var addingNote = false
    @State private var addingContact = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("记录聊天历史（只存本机）", isOn: $store.recordHistory)
                    Stepper("分析时带最近 \(store.historyCount) 条历史", value: $store.historyCount, in: 0...100, step: 5)
                    Button("清空知识库与历史", role: .destructive) {
                        store.clearKnowledgeAndHistory()
                    }
                } header: {
                    Text("分析")
                } footer: {
                    Text("常驻笔记每次分析都带；其它笔记要标签或标题出现在最近消息里才带，最多 5 条。联系人按会话标题匹配姓名或别名生效。")
                }

                Section("笔记") {
                    ForEach(store.notes) { note in
                        Button { editingNote = note } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(note.title).foregroundStyle(.primary)
                                    Text(note.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if note.pinned { Text("常驻").font(.caption).foregroundStyle(.blue) }
                            }
                        }
                    }
                    .onDelete { store.notes.remove(atOffsets: $0) }
                    Button("新增笔记") { addingNote = true }
                }

                Section("联系人") {
                    ForEach(store.contacts) { c in
                        Button { editingContact = c } label: {
                            VStack(alignment: .leading) {
                                Text(c.name).foregroundStyle(.primary)
                                if !c.relationship.isEmpty {
                                    Text(c.relationship).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { store.contacts.remove(atOffsets: $0) }
                    Button("新增联系人") { addingContact = true }
                }
            }
            .navigationTitle("知识库")
            .sheet(isPresented: $addingNote) { NoteEditor(note: Note(title: "", content: "")) { store.notes.append($0) } }
            .sheet(item: $editingNote) { note in
                NoteEditor(note: note) { updated in
                    if let i = store.notes.firstIndex(where: { $0.id == updated.id }) { store.notes[i] = updated }
                }
            }
            .sheet(isPresented: $addingContact) { ContactEditor(contact: Contact(name: "")) { store.contacts.append($0) } }
            .sheet(item: $editingContact) { c in
                ContactEditor(contact: c) { updated in
                    if let i = store.contacts.firstIndex(where: { $0.id == updated.id }) { store.contacts[i] = updated }
                }
            }
        }
    }
}

struct NoteEditor: View {
    @Environment(\.dismiss) var dismiss
    @State var note: Note
    var onSave: (Note) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("标题", text: $note.title)
                TextField("标签（逗号分隔）", text: $note.tags)
                Toggle("常驻（每次都带）", isOn: $note.pinned)
                TextEditor(text: $note.content).frame(minHeight: 140)
            }
            .navigationTitle("笔记")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(note); dismiss() }.disabled(note.title.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct ContactEditor: View {
    @Environment(\.dismiss) var dismiss
    @State var contact: Contact
    var onSave: (Contact) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("姓名", text: $contact.name)
                TextField("别名（每行一个）", text: $contact.aliases, axis: .vertical)
                TextField("关系", text: $contact.relationship)
                TextField("备注", text: $contact.remark, axis: .vertical)
            }
            .navigationTitle("联系人")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(contact); dismiss() }.disabled(contact.name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
