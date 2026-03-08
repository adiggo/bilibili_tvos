import Testing
import Foundation
@testable import bilibili_tvos

struct ModelTests {

    @Test func testVideoListResponseDecoding() throws {
        let json = """
        {
            "code": 0,
            "message": "0",
            "data": {
                "items": [
                    {
                        "title": "Test Video",
                        "cover": "http://test.com/cover.jpg",
                        "uri": "bilibili://video/123",
                        "param": "123",
                        "goto": "av",
                        "desc": "Test Description",
                        "play": 100,
                        "danmaku": 10,
                        "reply": 5,
                        "favorite": 2,
                        "coin": 1,
                        "share": 0,
                        "like": 50,
                        "duration": 120,
                        "rname": "Anime",
                        "bvid": "BV123",
                        "aid": 123,
                        "name": "Author",
                        "face": "http://test.com/face.jpg"
                    }
                ]
            }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(BilibiliApiResponse<VideoListResponse>.self, from: json)
        
        #expect(response.code == 0)
        #expect(response.data?.items.count == 1)
        #expect(response.data?.items[0].title == "Test Video")
        #expect(response.data?.items[0].bvid == "BV123")
    }

    @Test func testVideoDetailResponseDecoding() throws {
        let json = """
        {
            "code": 0,
            "message": "0",
            "data": {
                "aid": 123,
                "bvid": "BV123",
                "cid": 456,
                "title": "Test Video Detail",
                "desc": "Detailed Description",
                "pic": "http://test.com/pic.jpg",
                "owner": {
                    "name": "Author",
                    "face": "http://test.com/face.jpg"
                },
                "stat": {
                    "view": 100,
                    "danmaku": 10,
                    "reply": 5,
                    "favorite": 2,
                    "coin": 1,
                    "share": 0,
                    "like": 50
                },
                "pages": [
                    {
                        "cid": 456,
                        "part": "Part 1",
                        "duration": 120
                    }
                ]
            }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(BilibiliApiResponse<VideoDetailResponse>.self, from: json)
        
        #expect(response.code == 0)
        #expect(response.data?.title == "Test Video Detail")
        #expect(response.data?.owner.name == "Author")
        #expect(response.data?.pages.count == 1)
    }

    @Test func testPlayUrlResponseDecoding() throws {
        let json = """
        {
            "code": 0,
            "message": "0",
            "data": {
                "quality": 80,
                "format": "mp4",
                "timelength": 120000,
                "durl": [
                    {
                        "order": 1,
                        "length": 120000,
                        "size": 1000000,
                        "url": "http://test.com/video.mp4",
                        "backup_url": ["http://backup.com/video.mp4"]
                    }
                ]
            }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(BilibiliApiResponse<PlayUrlResponse>.self, from: json)
        
        #expect(response.code == 0)
        #expect(response.data?.quality == 80)
        #expect(response.data?.durl?.first?.url == "http://test.com/video.mp4")
    }
}
