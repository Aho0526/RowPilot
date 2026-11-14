import Foundation
import Security

enum KeychainHelper {
    private static let service = "aho-project.RowPilot.auth"

    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 1. iCloud同期Keychainに保存を試みる
        let syncQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
        SecItemDelete(syncQuery as CFDictionary)

        var syncAdd = syncQuery
        syncAdd[kSecValueData as String] = data
        syncAdd[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let syncStatus = SecItemAdd(syncAdd as CFDictionary, nil)

        // 2. ローカルKeychainにもフォールバック保存（iCloud Keychain無効端末対策）
        let localQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        SecItemDelete(localQuery as CFDictionary)

        var localAdd = localQuery
        localAdd[kSecValueData as String] = data
        localAdd[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let localStatus = SecItemAdd(localAdd as CFDictionary, nil)

        if syncStatus != errSecSuccess && localStatus != errSecSuccess {
            print("[KeychainHelper] Save warning for \(key): sync=\(syncStatus), local=\(localStatus)")
        }
    }

    static func read(key: String) -> String? {
        // 1. iCloud同期Keychainを優先して参照
        if let synced = readSingle(key: key, synchronizable: kCFBooleanTrue) {
            return synced
        }
        // 2. ローカルKeychainを参照
        return readSingle(key: key, synchronizable: kCFBooleanFalse)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func readSingle(key: String, synchronizable: CFBoolean) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: synchronizable,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              !string.isEmpty else {
            return nil
        }
        return string
    }
}
