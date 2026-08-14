//
//  AppTab.swift
//  refind
//

import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case gesuche, entdecken, chat, profil

    var id: String { rawValue }

    /// Tab labels are Archivo caps 9 pt — written here in sentence case and
    /// uppercased by the label style, so VoiceOver reads a word, not shouting.
    var title: String {
        switch self {
        case .gesuche:   return "Gesuche"
        case .entdecken: return "Entdecken"
        case .chat:      return "Chat"
        case .profil:    return "Profil"
        }
    }
}
