import Foundation
import CryptoKit

struct BilibiliSignature {
    // Android TV YST App Key & Secret
    static let appKey = "4409e2f1fb3795a8"
    static let appSecret = "59b43e04ad6965f34319062b478f83dd"

    static func generate(parameters: [String: String]) -> String {
        // 1. Collect and sort parameters alphabetically
        var sortedParams = parameters
        sortedParams["appkey"] = appKey
        
        let sortedKeys = sortedParams.keys.sorted()
        
        // 2. Concatenate as a query string
        let queryString = sortedKeys.map { key in
            let value = sortedParams[key] ?? ""
            return "\(key)=\(value)"
        }.joined(separator: "&")
        
        // 3. Append AppSecret
        let signString = queryString + appSecret
        
        // 4. Calculate MD5
        return md5(signString)
    }
    
    private static func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

struct WbiSignature {
    private static let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13
    ]
    
    static func key(from urlString: String?) -> String? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        return url.deletingPathExtension().lastPathComponent
    }
    
    static func sign(parameters: [String: String], imgKey: String, subKey: String) -> [String: String] {
        var params = parameters
        params["wts"] = String(Int(Date().timeIntervalSince1970))
        
        let mixinKey = mixinKeyValue(imgKey: imgKey, subKey: subKey)
        let sortedKeys = params.keys.sorted()
        let query = sortedKeys.map { key -> String in
            let value = params[key] ?? ""
            let filtered = value.replacingOccurrences(of: "[!'()*]", with: "", options: .regularExpression)
            return "\(key)=\(filtered)"
        }.joined(separator: "&")
        
        let wRid = md5(query + mixinKey)
        params["w_rid"] = wRid
        return params
    }
    
    private static func mixinKeyValue(imgKey: String, subKey: String) -> String {
        let raw = imgKey + subKey
        let mixed = mixinKeyEncTab.compactMap { index in
            guard raw.indices.contains(raw.index(raw.startIndex, offsetBy: index)) else { return nil }
            return String(raw[raw.index(raw.startIndex, offsetBy: index)])
        }.joined()
        return String(mixed.prefix(32))
    }
    
    private static func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
