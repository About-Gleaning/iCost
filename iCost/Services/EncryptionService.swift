import Foundation
import CryptoKit
import Security

enum EncryptionService {
    private static let keyTag = "com.liurui.icost.symmkey"

    private static func loadKey() throws -> SymmetricKey {
        if let data = Keychain.load(key: keyTag) {
            return SymmetricKey(data: data)
        } else {
            let key = SymmetricKey(size: .bits256)
            let data = key.withUnsafeBytes { Data($0) }
            Keychain.save(key: keyTag, data: data)
            return key
        }
    }

    static func encrypt(data: Data) throws -> Data {
        let key = try loadKey()
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined ?? Data()
    }

    static func decrypt(data: Data) throws -> Data {
        let key = try loadKey()
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }
}

enum Keychain {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: key,
                                    kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    static func load(key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: key,
                                    kSecReturnData as String: true]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess { return item as? Data }
        return nil
    }
}
