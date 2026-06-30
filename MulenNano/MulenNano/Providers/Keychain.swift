//
//  Keychain.swift
//  MulenNano
//
//  Bezpečné uložení API klíčů v macOS Keychain. Klíče nikdy nejdou do souborů ani gitu.
//

import Foundation
import Security

enum KeychainError: LocalizedError {
    case operationFailed(operation: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case let .operationFailed(operation, status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Keychain \(operation) selhal: \(systemMessage) (\(status))."
        }
    }
}

enum Keychain {
    private static let service = "com.mulen.MulenNano.apikeys"

    static func set(_ value: String, for account: String) throws {
        try delete(account)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.operationFailed(operation: "write", status: status)
        }
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operationFailed(operation: "delete", status: status)
        }
    }
}
