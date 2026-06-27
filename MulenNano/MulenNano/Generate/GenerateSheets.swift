//
//  GenerateSheets.swift
//  MulenNano
//
//  Modální okna generování — šablony, uložení promptu, kolekce.
//

import SwiftUI

// MARK: - Šablony promptů
struct TemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onInsert: (String) -> Void

    @State private var selected: PromptTemplate?
    @State private var values: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Šablony promptů")
            Divider()
            if let template = selected {
                fillForm(template)
            } else {
                list
            }
        }
        .frame(width: 460, height: 420)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                ForEach(PromptTemplate.defaults) { t in
                    Button {
                        selected = t
                        values = [:]
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name).font(.dsLabel)
                            Text(t.template).font(.dsCaption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Space.s)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.m).fill(DS.Palette.fieldBackground))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Space.l)
        }
    }

    private func fillForm(_ template: PromptTemplate) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    ForEach(template.variables, id: \.self) { v in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v).font(.dsCaption).foregroundStyle(.secondary)
                            TextField(v.lowercased(), text: Binding(
                                get: { values[v] ?? "" },
                                set: { values[v] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(DS.Space.l)
            }
            Spacer()
            HStack {
                Button("Zpět") { selected = nil }
                Spacer()
                Button("Vložit") {
                    onInsert(template.fill(values))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(DS.Space.l)
        }
    }

    private func header(_ title: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button("Hotovo") { dismiss() }
        }
        .padding(DS.Space.l)
    }
}

// MARK: - Uložení promptu
struct SavePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    let prompt: String
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Uložit prompt").font(.headline)
            TextField("Název", text: $name)
                .textFieldStyle(.roundedBorder)
            Text(prompt).font(.dsCaption).foregroundStyle(.secondary).lineLimit(3)
            Spacer()
            HStack {
                Spacer()
                Button("Zrušit") { dismiss() }
                Button("Uložit") {
                    env.savedPrompts.add(name: name.isEmpty ? String(prompt.prefix(24)) : name, prompt: prompt)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.isEmpty)
            }
        }
        .padding(DS.Space.l)
        .frame(width: 380, height: 200)
    }
}

// MARK: - Správa promptů
struct ManagePromptsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    var onPickPrompt: (String) -> Void

    @State private var search = ""
    @State private var editingID: UUID?
    @State private var editName = ""
    @State private var editPrompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                Text("Uložené prompty").font(.headline)
                Spacer()
                Button("Hotovo") { dismiss() }
            }

            TextField("Hledat prompt…", text: $search)
                .textFieldStyle(.roundedBorder)

            Divider()

            if filteredPrompts.isEmpty {
                Spacer()
                Text("Žádné odpovídající prompty.")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: DS.Space.s) {
                        ForEach(filteredPrompts) { saved in
                            if editingID == saved.id {
                                editCard(for: saved)
                            } else {
                                promptCard(for: saved)
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.Space.l)
        .frame(width: 520, height: 460)
    }

    private var filteredPrompts: [SavedPrompt] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return env.savedPrompts.prompts }
        return env.savedPrompts.prompts.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.prompt.localizedCaseInsensitiveContains(query)
        }
    }

    private func promptCard(for saved: SavedPrompt) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack {
                Text(saved.name)
                    .font(.dsLabel)
                Spacer()
                Button("Použít") {
                    onPickPrompt(saved.prompt)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button {
                    editingID = saved.id
                    editName = saved.name
                    editPrompt = saved.prompt
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                Button(role: .destructive) {
                    env.savedPrompts.delete(saved.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }

            Text(saved.prompt)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Space.s)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(DS.Palette.fieldBackground)
        )
    }

    private func editCard(for saved: SavedPrompt) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            TextField("Název", text: $editName)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $editPrompt)
                .font(.dsLabel)
                .scrollContentBackground(.hidden)
                .frame(height: 100)
                .padding(DS.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(DS.Palette.fieldBackground)
                )

            HStack {
                Spacer()
                Button("Zrušit") {
                    editingID = nil
                    editName = ""
                    editPrompt = ""
                }
                Button("Uložit") {
                    env.savedPrompts.update(
                        saved.id,
                        name: editName.trimmingCharacters(in: .whitespacesAndNewlines),
                        prompt: editPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    editingID = nil
                    editName = ""
                    editPrompt = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          editPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Space.s)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(DS.Palette.fieldBackground)
        )
    }
}

// MARK: - Správa kolekcí
struct CollectionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                Text("Kolekce").font(.headline)
                Spacer()
                Button("Hotovo") { dismiss() }
            }
            HStack {
                TextField("Nová kolekce", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("Vytvořit") {
                    guard !newName.isEmpty else { return }
                    env.library.createCollection(newName)
                    newName = ""
                }
            }
            Divider()
            if env.library.collections.isEmpty {
                Text("Zatím žádné kolekce.").font(.dsCaption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: DS.Space.xs) {
                        ForEach(env.library.collections) { c in
                            HStack {
                                Image(systemName: "rectangle.stack").foregroundStyle(.secondary)
                                Text(c.name)
                                Spacer()
                                Text("\(env.library.images(in: c.id).count)")
                                    .font(.dsCaption).foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    env.library.deleteCollection(c.id)
                                } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain).foregroundStyle(.red)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(DS.Space.l)
        .frame(width: 400, height: 360)
    }
}

// MARK: - Přidání obrázku do kolekce
struct AssignCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    let image: LibraryImage
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Přidat do kolekce").font(.headline)
            HStack {
                TextField("Nová kolekce", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("Vytvořit") {
                    guard !newName.isEmpty else { return }
                    let c = env.library.createCollection(newName)
                    env.library.toggleMembership(imageID: image.id, collectionID: c.id)
                    newName = ""
                }
            }
            Divider()
            ScrollView {
                VStack(spacing: DS.Space.xs) {
                    ForEach(env.library.collections) { c in
                        let isIn = currentImage?.collectionIDs.contains(c.id) ?? false
                        Button {
                            env.library.toggleMembership(imageID: image.id, collectionID: c.id)
                        } label: {
                            HStack {
                                Image(systemName: isIn ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isIn ? Color.accentColor : .secondary)
                                Text(c.name)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
            HStack { Spacer(); Button("Hotovo") { dismiss() }.buttonStyle(.borderedProminent) }
        }
        .padding(DS.Space.l)
        .frame(width: 380, height: 340)
    }

    private var currentImage: LibraryImage? {
        env.library.images.first { $0.id == image.id }
    }
}
