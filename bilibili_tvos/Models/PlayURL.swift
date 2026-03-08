import Foundation

struct PlayUrlResponse: Codable {
    let quality: Int?
    let format: String?
    let timelength: Int?
    let durl: [VideoDurl]?
}

struct VideoDurl: Codable {
    let order: Int?
    let length: Int?
    let size: Int?
    let url: String?
    let backupUrl: [String]?
    
    enum CodingKeys: String, CodingKey {
        case order, length, size, url
        case backupUrl = "backup_url"
    }
}
