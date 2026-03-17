// Superbrain/App/AppearanceManager.swift
import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

final class AppearanceManager: ObservableObject {
    @AppStorage("appearanceMode") var mode: AppearanceMode = .system {
        willSet { objectWillChange.send() }
    }
}
