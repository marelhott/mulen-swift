//
//  AppEnvironment.swift
//  MulenNano
//
//  Sdílené prostředí aplikace — registr providerů + knihovna.
//

import SwiftUI
import Observation

@Observable
final class AppEnvironment {
    let providers = ProviderRegistry()
    let library = LibraryStore()
    let savedPrompts = SavedPromptStore()
}
