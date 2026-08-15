//
//  Keychain.swift
//  refind
//
//  Session tokens live here, not in UserDefaults. UserDefaults is a plist in
//  the app container — readable from a backup, and not encrypted at rest.
//

import Foundation
import Security

enum Keychain {

    /// `kSecAttrAccessibleAfterFirstUnlock`: the app needs the token in a
    /// background refresh, so it cannot be `WhenUnlocked`. It never leaves the
    /// device — no iCloud sync.
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlock

    static func set(_ value: String?, for key: String) {
        guard let value, let data = value.data(using: .utf8) else {
            remove(key)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = accessibility
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static let service = "ch.nick.refind.session"

    enum Key {
        static let accessToken = "accessToken"
        static let refreshToken = "refreshToken"
    }
}
