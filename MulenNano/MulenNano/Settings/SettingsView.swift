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
            } header: {
                Text("Kam se ukládají vygenerované obrázky a metadata. Lze i externí disk.")
                    .font(.caption).foregroundStyle(.secondary)
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
                         hint: "OpenAI → API keys (model gpt-image-1)")
            } header: {
                Text("Klíče se ukládají bezpečně do macOS Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
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
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.callout.weight(.medium))
                Spacer()
                if registry.hasKey(for: kind) {
                    Label("uloženo", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }
            HStack {
                SecureField("vlož klíč…", text: $value)
                    .textFieldStyle(.roundedBorder)
                Button("Uložit") {
                    registry.setAPIKey(value, for: kind)
                    value = ""
                    saved = true
                }
                .disabled(value.isEmpty)
            }
            Text(hint).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
