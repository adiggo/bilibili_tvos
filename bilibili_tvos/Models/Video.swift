import Foundation

struct BilibiliApiResponse<T: Codable>: Codable {
    let code: Int?
    let message: String?
    let data: T?
    let result: T?
    
    var anyData: T? { data ?? result }
}

struct VideoListResponse: Codable {
    let items: [VideoItem]?
    let list: [VideoItem]?
    let cards: [VideoItem]?
    let archives: [VideoItem]?
    
    var allItems: [VideoItem] {
        return items ?? list ?? cards ?? archives ?? []
    }
}

struct FeedResponse: Codable {
    let items: [VideoItem]?
    let item: [VideoItem]?
    
    var allItems: [VideoItem] {
        return items ?? item ?? []
    }
}

struct SearchResponse: Codable {
    // Search result can be an array of SearchResult (mixed) or an array of VideoItem (typed)
    let result: FlexibleSearchResult?
    
    var allVideos: [VideoItem] {
        switch result {
        case .nested(let items):
            return items.compactMap { $0.data }.flatMap { $0 }
        case .flat(let videos):
            return videos
        case .none:
            return []
        }
    }
}

enum FlexibleSearchResult: Codable {
    case nested([SearchResult])
    case flat([VideoItem])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let nested = try? container.decode([SearchResult].self) {
            self = .nested(nested)
        } else if let flat = try? container.decode([VideoItem].self) {
            self = .flat(flat)
        } else {
            // If neither, just return empty flat array
            self = .flat([])
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .nested(let nested): try container.encode(nested)
        case .flat(let flat): try container.encode(flat)
        }
    }
}

struct SearchResult: Codable {
    let resultType: String?
    let data: [VideoItem]?
    
    enum CodingKeys: String, CodingKey {
        case resultType = "result_type"
        case data
    }
}

struct VideoItem: Codable, Identifiable, Hashable {
    // We MUST have a stable ID for tvOS focus and navigation to work.
    // If Bilibili doesn't provide one, we generate one from the title.
    var id: String {
        if let bvidValue = bvidValue, !bvidValue.isEmpty { return bvidValue }
        if let aidValue = aidValue { return "aid_\(aidValue)" }
        if let p = param, !p.isEmpty { return p }
        if let t = title, !t.isEmpty { return "title_\(t.hashValue)" }
        return fallbackId
    }
    
    // This is a temporary ID generated only if everything else is missing
    private let fallbackId = UUID().uuidString
    
    let title: String?
    let name: String?
    let cover: String?
    let pic: String?
    let uri: String?
    let param: String?
    let goto: String?
    let desc: String?
    
    let args: VideoArgs?
    let playerArgs: VideoPlayerArgs?

    var displayTitle: String { 
        (title ?? name ?? "Untitled Video")
            .replacingOccurrences(of: "<em class=\"keyword\">", with: "")
            .replacingOccurrences(of: "</em>", with: "")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
    var displayCover: String { 
        let url = pic ?? cover ?? ""
        return url.httpsUrl 
    }
    var displayAuthor: String { args?.upName ?? owner?.name ?? author ?? "Unknown Author" }
    var displayFace: String { (face ?? owner?.face ?? "").httpsUrl }
    
    var videoAid: Int? {
        // UGC Videos (Standard)
        if let aidValue = aidValue, aidValue > 100 { return aidValue }
        if let avidValue = avid, avidValue > 100 { return avidValue }
        if let playerAid = playerArgs?.aid, playerAid > 100 { return playerAid }
        if let searchIdValue = searchId?.intValue, searchIdValue > 100 && (goto == "av" || goto == nil) { return searchIdValue }
        
        // Try parsing from URI or arcurl for standard videos
        for source in [uri, arcurl].compactMap({ $0 }) {
            if let range = source.range(of: "(av|/av)(\\d+)", options: .regularExpression) {
                let avNumberStr = source[range].replacingOccurrences(of: "/av", with: "").replacingOccurrences(of: "av", with: "")
                if let i = Int(avNumberStr) { return i }
            }
        }
        return nil
    }
    
    var videoBvid: String? {
        if let bvidValue = bvidValue, !bvidValue.isEmpty { return bvidValue }
        if let p = param, p.hasPrefix("BV") { return p }
        if let searchIdValue = searchId?.stringValue, searchIdValue.hasPrefix("BV") { return searchIdValue }
        
        // Try parsing from URI or arcurl
        for source in [uri, arcurl].compactMap({ $0 }) {
            if let range = source.range(of: "BV[a-zA-Z0-9]+", options: .regularExpression) {
                return String(source[range])
            }
        }
        return nil
    }
    
    // Bangumi / Media specific IDs
    var episodeId: Int? { 
        if let eid = ep_id, eid > 0 { return eid }
        if let p = param, p.hasPrefix("ep"), let i = Int(p.replacingOccurrences(of: "ep", with: "")) { return i }
        if let uri = uri, let range = uri.range(of: "ep(\\d+)", options: .regularExpression) {
            return Int(uri[range].replacingOccurrences(of: "ep", with: ""))
        }
        return nil
    }
    
    var seasonId: Int? { 
        if let sid = season_id, sid > 0 { return sid }
        if let p = param, p.hasPrefix("ss"), let i = Int(p.replacingOccurrences(of: "ss", with: "")) { return i }
        if let uri = uri, let range = uri.range(of: "ss(\\d+)", options: .regularExpression) {
            return Int(uri[range].replacingOccurrences(of: "ss", with: ""))
        }
        return nil
    }
    
    var isBangumi: Bool {
        return goto == "bangumi" || goto == "pgc" || ep_id != nil || season_id != nil || 
               (uri?.contains("bangumi") ?? false) || (uri?.contains("/ss") ?? false) || (uri?.contains("/ep") ?? false)
    }

    let play: Int?
    let owner: VideoOwner?
    let author: String?
    let face: String?
    let idx: Int?
    let arcurl: String?
    let avid: Int?
    private let ep_id: Int?
    private let season_id: Int?
    let media_id: Int?
    
    // Multi-type support for search results
    private let aid: DynamicValue?
    private let bvid: DynamicValue?
    private let searchId: DynamicValue? 
    
    var aidValue: Int? { aid?.intValue }
    var bvidValue: String? { bvid?.stringValue }

    enum CodingKeys: String, CodingKey {
        case title, name, cover, pic, uri, param, goto, desc, play, aid, bvid, owner, face, args, idx, author, arcurl, avid, ep_id, season_id, media_id
        case searchId = "id"
        case playerArgs = "player_args"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.id == rhs.id
    }
}

// Helper for Bilibili's inconsistent JSON types (string vs int)
enum DynamicValue: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.typeMismatch(DynamicValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let i): try container.encode(i)
        case .string(let s): try container.encode(s)
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .string(let s): return Int(s)
        }
    }

    var stringValue: String? {
        switch self {
        case .int(let i): return String(i)
        case .string(let s): return s
        }
    }
}

struct VideoArgs: Codable, Hashable {
    let upName: String?
    enum CodingKeys: String, CodingKey {
        case upName = "up_name"
    }
}

struct VideoPlayerArgs: Codable, Hashable {
    let aid: Int?
    let cid: Int?
}

struct VideoDetailResponse: Codable {
    let aid: Int?
    let bvid: String?
    let cid: Int?
    let title: String?
    let desc: String?
    let pic: String?
    let owner: VideoOwner?
    let stat: VideoStat?
    let pages: [VideoPage]?
}

struct VideoOwner: Codable, Hashable {
    let name: String?
    let face: String?
}

struct VideoStat: Codable, Hashable {
    let view: Int?
}

struct VideoPage: Codable, Hashable {
    let cid: Int?
    let part: String?
}

struct BangumiDetailResponse: Codable {
    let title: String?
    let evaluate: String?
    let cover: String?
    let episodes: [BangumiEpisode]?
}

struct BangumiEpisode: Codable {
    let id: Int? // This is the ep_id
    let aid: Int?
    let cid: Int?
    let bvid: String?
    let title: String?
    let longTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case id, aid, cid, bvid, title
        case longTitle = "long_title"
    }
}

extension String {
    var httpsUrl: String {
        if self.hasPrefix("//") {
            return "https:" + self
        }
        if self.hasPrefix("http://") {
            return self.replacingOccurrences(of: "http://", with: "https://")
        }
        return self
    }
}
