import Foundation

class BilibiliApiService {
    static let shared = BilibiliApiService()
    static let authDidChangeNotification = Notification.Name("BilibiliAuthDidChange")
    private let session = URLSession.shared
    
    private let appBaseUrl = "https://app.bilibili.com"
    private let apiBaseUrl = "https://api.bilibili.com"
    private let passportBaseUrl = "https://passport.bilibili.com"
    
    private let platform = "android"
    private let mobiApp = "android_tv_yst"
    private let device = "android"
    private let build = "102800"
    
    // Consistent User-Agent across all requests
    private let userAgent = "Mozilla/5.0 (Linux; Android 11; TV Build/RP1A.201005.001; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Safari/537.36 BiliApp/1.1.2"
    private let authCookieKey = "BilibiliAuthCookies"
    private var wbiCache: (imgKey: String, subKey: String, fetchedAt: Date)?
    
    var isLoggedIn: Bool {
        ensureAuthCookies()
        return authCookies["SESSDATA"] != nil
    }
    
    private var authCookies: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: authCookieKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: authCookieKey)
        }
    }
    
    private var cookieHeader: String? {
        ensureAuthCookies()
        guard !authCookies.isEmpty else { return nil }
        return authCookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    private func ensureAuthCookies() {
        if authCookies["SESSDATA"] != nil { return }
        syncCookiesFromStorage()
    }
    
    private func request<T: Codable>(baseUrl: String? = nil, endpoint: String, parameters: [String: String]) async throws -> T {
        var params = parameters
        params["mobi_app"] = mobiApp
        params["platform"] = platform
        params["device"] = device
        params["build"] = build
        params["ts"] = String(Int(Date().timeIntervalSince1970))
        
        let sign = BilibiliSignature.generate(parameters: params)
        let base = baseUrl ?? appBaseUrl
        var urlComponents = URLComponents(string: base + endpoint)!
        
        var queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        queryItems.append(URLQueryItem(name: "appkey", value: BilibiliSignature.appKey))
        queryItems.append(URLQueryItem(name: "sign", value: sign))
        urlComponents.queryItems = queryItems
        
        let url = urlComponents.url!
        print("🚀 API Request: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let cookieHeader = cookieHeader {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 API Response Code: \(httpResponse.statusCode) for \(endpoint)")
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("--- Bilibili API Response ---")
            print(jsonString)
        }

        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(BilibiliApiResponse<T>.self, from: data)
            
            if let code = response.code, code != 0 {
                throw NSError(domain: "BilibiliApi", code: code, userInfo: [NSLocalizedDescriptionKey: response.message ?? "Unknown error"])
            }
            
            guard let responseData = response.anyData else {
                throw NSError(domain: "BilibiliApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
            }
            
            return responseData
        } catch let decodingError as DecodingError {
            print("Decoding Error: \(decodingError)")
            throw decodingError
        } catch {
            throw error
        }
    }
    
    private func requestWeb<T: Codable>(endpoint: String, parameters: [String: String]) async throws -> T {
        var urlComponents = URLComponents(string: apiBaseUrl + endpoint)!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        let url = urlComponents.url!
        print("🌐 Web API Request: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let cookieHeader = cookieHeader {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 Web API Response Code: \(httpResponse.statusCode) for \(endpoint)")
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("--- Bilibili Web API Response ---")
            print(jsonString)
        }

        let decoder = JSONDecoder()
        do {
            let apiResponse = try decoder.decode(BilibiliApiResponse<T>.self, from: data)
            
            if let code = apiResponse.code, code != 0 {
                throw NSError(domain: "BilibiliApi", code: code, userInfo: [NSLocalizedDescriptionKey: apiResponse.message ?? "Unknown error"])
            }
            
            guard let responseData = apiResponse.anyData else {
                throw NSError(domain: "BilibiliApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
            }
            
            return responseData
        } catch let decodingError as DecodingError {
            print("❌ Web API Decoding Error: \(decodingError)")
            throw decodingError
        } catch {
            throw error
        }
    }
    
    private func requestWebWbi<T: Codable>(endpoint: String, parameters: [String: String]) async throws -> T {
        let (imgKey, subKey) = try await getWbiKeys()
        let signedParams = WbiSignature.sign(parameters: parameters, imgKey: imgKey, subKey: subKey)
        return try await requestWeb(endpoint: endpoint, parameters: signedParams)
    }
    
    private func requestPassport<T: Codable>(endpoint: String, parameters: [String: String]) async throws -> T {
        var urlComponents = URLComponents(string: passportBaseUrl + endpoint)!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        let url = urlComponents.url!
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 Passport Response Code: \(httpResponse.statusCode) for \(endpoint)")
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(BilibiliApiResponse<T>.self, from: data)
        if let code = apiResponse.code, code != 0 {
            throw NSError(domain: "BilibiliApi", code: code, userInfo: [NSLocalizedDescriptionKey: apiResponse.message ?? "Unknown error"])
        }
        guard let responseData = apiResponse.anyData else {
            throw NSError(domain: "BilibiliApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
        }
        return responseData
    }
    
    private func getWbiKeys() async throws -> (String, String) {
        let now = Date()
        if let cache = wbiCache, now.timeIntervalSince(cache.fetchedAt) < 3600 {
            return (cache.imgKey, cache.subKey)
        }
        
        let response: NavResponse = try await requestWeb(endpoint: "/x/web-interface/nav", parameters: [:])
        guard let imgKey = WbiSignature.key(from: response.wbiImg?.imgUrl),
              let subKey = WbiSignature.key(from: response.wbiImg?.subUrl) else {
            throw NSError(domain: "BilibiliApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing WBI keys"])
        }
        wbiCache = (imgKey: imgKey, subKey: subKey, fetchedAt: now)
        return (imgKey, subKey)
    }
    
    func logout() {
        authCookies = [:]
        NotificationCenter.default.post(name: BilibiliApiService.authDidChangeNotification, object: nil)
    }
    
    func fetchTrending(idx: Int? = nil) async throws -> [VideoItem] {
        var parameters: [String: String] = [
            "pull": idx == nil ? "true" : "false"
        ]
        if let idx = idx {
            parameters["idx"] = String(idx)
        } else {
            parameters["idx"] = String(Int(Date().timeIntervalSince1970))
        }
        let response: VideoListResponse = try await request(baseUrl: appBaseUrl, endpoint: "/x/v2/feed/index", parameters: parameters)
        return response.allItems
    }
    
    func fetchPersonalizedFeed(idx: Int? = nil) async throws -> [VideoItem] {
        var parameters: [String: String] = [
            "ps": "20",
            "fresh_type": "3",
            "feed_version": "V8"
        ]
        
        if let idx = idx {
            parameters["fresh_idx"] = String(idx)
            parameters["fresh_idx_1h"] = String(idx)
        }
        
        let response: FeedResponse = try await requestWebWbi(endpoint: "/x/web-interface/wbi/index/top/feed/rcmd", parameters: parameters)
        return response.allItems
    }
    
    func fetchVideoDetail(aid: Int? = nil, bvid: String? = nil) async throws -> VideoDetailResponse {
        var parameters: [String: String] = [:]
        if let aid = aid {
            parameters["aid"] = String(aid)
        } else if let bvid = bvid {
            parameters["bvid"] = bvid
        }
        
        // Web interface view is highly compatible
        return try await requestWeb(endpoint: "/x/web-interface/view", parameters: parameters)
    }

    func fetchBangumiDetail(seasonId: Int? = nil, epId: Int? = nil) async throws -> BangumiDetailResponse {
        var parameters: [String: String] = [:]
        if let sid = seasonId {
            parameters["season_id"] = String(sid)
        } else if let eid = epId {
            parameters["ep_id"] = String(eid)
        }
        
        return try await requestWeb(endpoint: "/pgc/view/web/season", parameters: parameters)
    }
    
    func fetchPlayUrl(aid: Int, cid: Int, qn: Int = 32) async throws -> PlayUrlResponse {
        let parameters: [String: String] = [
            "avid": String(aid), 
            "cid": String(cid),
            "qn": String(qn),
            "otype": "json"
        ]
        
        // General player playurl is more stable across different video types
        return try await requestWeb(endpoint: "/x/player/playurl", parameters: parameters)
    }

    func fetchPgcPlayUrl(epId: Int, cid: Int, qn: Int = 32) async throws -> PlayUrlResponse {
        let parameters: [String: String] = [
            "ep_id": String(epId),
            "cid": String(cid),
            "qn": String(qn),
            "otype": "json"
        ]
        
        return try await requestWeb(endpoint: "/pgc/player/web/playurl", parameters: parameters)
    }

    func fetchDanmaku(cid: Int) async throws -> [DanmakuItem] {
        let url = URL(string: "https://comment.bilibili.com/\(cid).xml")!
        var request = URLRequest(url: url)
        request.setValue("text/xml", forHTTPHeaderField: "Accept")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let cookieHeader = cookieHeader {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 Danmaku Response Code: \(httpResponse.statusCode) for cid \(cid)")
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let parser = DanmakuXMLParser()
            return try parser.parse(data: data)
        }.value
    }

    func search(keyword: String) async throws -> [VideoItem] {
        let parameters: [String: String] = [
            "keyword": keyword,
            "type": "video",
            "pn": "1",
            "ps": "20"
        ]
        
        let response: SearchResponse = try await requestWeb(endpoint: "/x/web-interface/search/all/v2", parameters: parameters)
        let videos = response.allVideos
        
        // Log the first few items raw to see all available keys
        print("🔍 [SEARCH] Processing \(videos.count) results...")
        for (index, video) in videos.prefix(3).enumerated() {
            print("   #\(index): '\(video.displayTitle)' | goto: \(video.goto ?? "nil") | aid: \(video.videoAid != nil ? "\(video.videoAid!)" : "nil") | bvid: \(video.videoBvid ?? "nil")")
        }
        
        return videos
    }

    func fetchCategoryVideos(rid: Int) async throws -> [VideoItem] {
        let parameters: [String: String] = [
            "rid": String(rid),
            "pn": "1",
            "ps": "20"
        ]
        
        // Use the web dynamic region endpoint which is more reliable
        let response: VideoListResponse = try await requestWeb(endpoint: "/x/web-interface/dynamic/region", parameters: parameters)
        return response.allItems
    }
    
    func generateQrCode() async throws -> QrCodeData {
        return try await requestPassport(endpoint: "/x/passport-login/web/qrcode/generate", parameters: [:])
    }
    
    func pollQrCode(key: String) async throws -> QrPollData {
        return try await requestPassport(endpoint: "/x/passport-login/web/qrcode/poll", parameters: ["qrcode_key": key])
    }
    
    func completeQrLogin(redirectUrl: String) async throws {
        guard let url = URL(string: redirectUrl) else {
            throw NSError(domain: "BilibiliApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid redirect URL"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            saveCookies(from: httpResponse, url: url)
        }
        syncCookiesFromStorage()
    }
    
    private func saveCookies(from response: HTTPURLResponse, url: URL) {
        let headers = response.allHeaderFields as? [String: String] ?? [:]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        var stored = authCookies
        for cookie in cookies {
            stored[cookie.name] = cookie.value
        }
        authCookies = stored
        NotificationCenter.default.post(name: BilibiliApiService.authDidChangeNotification, object: nil)
    }

    private func syncCookiesFromStorage() {
        let domains = [
            "https://www.bilibili.com",
            "https://api.bilibili.com",
            "https://passport.bilibili.com"
        ]
        var storageCookies: [HTTPCookie] = []
        for domain in domains {
            if let url = URL(string: domain) {
                storageCookies.append(contentsOf: HTTPCookieStorage.shared.cookies(for: url) ?? [])
            }
        }
        guard !storageCookies.isEmpty else { return }
        var stored = authCookies
        for cookie in storageCookies {
            stored[cookie.name] = cookie.value
        }
        authCookies = stored
        NotificationCenter.default.post(name: BilibiliApiService.authDidChangeNotification, object: nil)
    }

    func fetchAccountInfo() async throws -> AccountInfo {
        let response: NavResponse = try await requestWeb(endpoint: "/x/web-interface/nav", parameters: [:])
        guard response.isLogin == true else {
            throw NSError(domain: "BilibiliApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }
        return AccountInfo(
            mid: response.mid ?? 0,
            uname: response.uname ?? "Unknown",
            face: response.face ?? "",
            level: response.levelInfo?.currentLevel ?? 0
        )
    }
}

struct QrCodeData: Codable {
    let url: String
    let qrcodeKey: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case qrcodeKey = "qrcode_key"
    }
}

struct QrPollData: Codable {
    let code: Int
    let message: String?
    let url: String?
}

struct NavResponse: Codable {
    let wbiImg: WbiImg?
    let isLogin: Bool?
    let uname: String?
    let face: String?
    let mid: Int?
    let levelInfo: LevelInfo?
    
    enum CodingKeys: String, CodingKey {
        case wbiImg = "wbi_img"
        case isLogin = "isLogin"
        case uname
        case face
        case mid
        case levelInfo = "level_info"
    }
}

struct WbiImg: Codable {
    let imgUrl: String?
    let subUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case imgUrl = "img_url"
        case subUrl = "sub_url"
    }
}

struct LevelInfo: Codable {
    let currentLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case currentLevel = "current_level"
    }
}

struct AccountInfo {
    let mid: Int
    let uname: String
    let face: String
    let level: Int
}
