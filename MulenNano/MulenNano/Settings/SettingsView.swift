//
//  SettingsView.swift
//  MulenNano
//
//  Nastavení — zatím API klíče (Keychain). Další sekce přibudou.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            APIKeysSettings()
                .tabItem { Label("API klíče", systemImage: "key") }
            StorageSettings()
                .tabItem { Label("Úložiště", systemImage: "folder") }
        }
        .frame(width: 480, height: 320)
        .font(.dsStandard)
        .tracking(0)
        .lineSpacing(0)
    }
}

struct StorageSettings: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Form {
            Section {
                LabeledContent("Aktuální složka") {
                    Text(env.library.folder.path)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Změnit složku…") { chooseFolder() }
                    Button("Otevřít ve Finderu") {
                        NSWorkspace.shared.open(env.library.folder)
                    }
                }
                if let error = env.library.lastErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.dsCaption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Kam se ukládají vygenerované obrázky a metadata. Lze i externí disk.")
                    .font(.dsSmall).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = env.library.folder
        if panel.runModal() == .OK, let url = panel.url {
            env.library.setFolder(url)
        }
    }
}

struct APIKeysSettings: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Form {
            Section {
                keyField(for: .gemini, label: "Gemini API klíč",
                         hint: "Google AI Studio → API key")
                keyField(for: .chatgpt, label: "ChatGPT API klíč",
                         hint: "OpenAI → API keys (model gpt-image-2)")
                keyField(for: .replicate, label: "Replicate API klíč",
                         hint: "Replicate → Account → API tokens (creative upscale / Clarity)")
            } header: {
                Text("Klíče se ukládají bezpečně do macOS Keychain.")
                    .font(.dsSmall).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func keyField(for kind: AIProviderKind, label: String, hint: String) -> some View {
        @Bindable var registry = env.providers
        KeyRow(kind: kind, label: label, hint: hint, registry: registry)
    }
}

private struct KeyRow: View {
    let kind: AIProviderKind
    let label: String
    let hint: String
    let registry: ProviderRegistry

    @State private var value: String = ""
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.dsStandardMedium)
                Spacer()
                if registry.hasKey(for: kind) {
                    Label("uloženo", systemImage: "checkmark.circle.fill")
                        .font(.dsSmall)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }
            HStack {
                SecureField("vlož klíč…", text: $value)
                    .textFieldStyle(.roundedBorder)
                Button(registry.hasKey(for: kind) ? "Nahradit" : "Uložit") {
                    save()
                }
                .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if registry.hasKey(for: kind) {
                    Button("Odstranit", role: .destructive) {
                        delete()
                    }
                }
            }
            Text(hint).font(.dsSmall).foregroundStyle(.secondary)
            if let statusMessage {
                Text(statusMessage)
                    .font(.dsSmall)
                    .foregroundStyle(.green)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.dsSmall)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
        .onAppear(perform: loadCurrentValue)
        .onChange(of: registry.keyPresence) { _, _ in
            loadCurrentValue()
        }
    }

    private func loadCurrentValue() {
        value = registry.apiKey(for: kind) ?? ""
    }

    private func save() {
        errorMessage = nil
        do {
            try registry.setAPIKey(value, for: kind)
            statusMessage = "Klíč uložen do Keychain."
            loadCurrentValue()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func delete() {
        errorMessage = nil
        do {
            try registry.deleteAPIKey(for: kind)
            value = ""
            statusMessage = "Klíč odstraněn z Keychain."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
