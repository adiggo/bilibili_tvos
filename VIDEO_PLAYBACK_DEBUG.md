# Video Playback Debugging & Architecture

This document summarizes the investigation and resolution of video playback issues for the Bilibili tvOS application.

## 📋 Debugging Timeline

### 1. Navigation & State Issue
**Symptom:** Clicking the "Play Video" button did nothing.
**Cause:** 
- `showPlayer` state was managed in a way that conflicted with the button's focus on tvOS.
- Multiple `fullScreenCover` modifiers were present in the view hierarchy.
**Solution:** 
- Consolidated `fullScreenCover` into the root container of `VideoDetailView`.
- Added explicit state logging to track `showPlayer` changes.

### 2. Identifier Resolution (AID/CID)
**Symptom:** Button was disabled or player showed "Missing Identifiers".
**Cause:** 
- Bilibili's trending feed returns inconsistent identifiers (sometimes `bvid`, sometimes `aid`).
- The player requires a specific `cid` (Chat ID) which is not always present in the feed.
**Solution:**
- Implemented a "Pre-flight" check in `loadDetail()`.
- Added a fallback mechanism to `playerArgs` if the detail API fails.
- Resolved `cid` by fetching the first page of the video detail.

### 3. API Endpoint Mismatch
**Symptom:** 404 or 400 "Request Error" from Bilibili APIs.
**Cause:**
- Attempted to use TV-specific endpoints (`/x/tv/playurl`) with Web/App credentials.
- Bilibili TV APIs are highly sensitive to `mobi_app`, `build`, and `platform` signatures.
**Solution:**
- Reverted to the highly compatible Web API: `https://api.bilibili.com/x/player/playurl`.
- Switched to `requestWeb` for playback resolution to ensure cookie/origin compatibility.

### 4. The "Black Screen" & Layout Stalemate
**Symptom:** Player appeared, but stayed on "Loading Stream" or a black screen.
**Cause:**
- **Layout:** Xcode logs showed `_AVFocusContainerView.width == 0`. SwiftUI was rendering the player with zero size because it was an unconstrained overlay.
- **Headers:** Bilibili's CDN requires a strict `Referer` and `User-Agent`.
- **Audio Session:** tvOS requires an active `AVAudioSession` category of `.playback` to initiate video.
**Solution:**
- Wrapped `AVPlayerViewController` in `UIViewControllerRepresentable` (`NativeVideoPlayer`).
- Added `frame(maxWidth: .infinity, maxHeight: .infinity)` to the player view.
- Configured `AVAudioSession` before resolving the URL.
- Set `Referer: https://www.bilibili.com/` and a modern Mac Chrome `User-Agent`.

---

## 🛠️ Final Playback Architecture

### Endpoint Configuration
| Feature | Endpoint | Method |
| :--- | :--- | :--- |
| **Video Detail** | `/x/web-interface/view` | `requestWeb` |
| **Play URL** | `/x/player/playurl` | `requestWeb` |

### Critical Headers (for AVURLAsset)
```swift
let headers: [String: String] = [
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ...",
    "Referer": "https://www.bilibili.com/",
    "Accept": "*/*"
]
```

### Successful Log Signature
```text
📥 [DETAIL] Resolved IDs: aid=116187941832767, cid=36528128445
🔘 [CLICK] PLAY BUTTON CLICKED!
🚀 [TASK] Starting preparePlayer for aid: 116187941832767, cid: 36528128445
🔗 [PLAYER] URL Resolved: https://upos-sz-mirrorcosov.bilivideo.com/...
📊 [PLAYER] Item Status: 1 (ReadyToPlay)
🎬 [PLAYER] Content is playing.
```

## ⚠️ Known Constraints
- **403 Errors:** If the CDN URL expires (usually 1-2 hours), the `AVPlayer` will fail.
- **4K/1080P:** Without an `access_key` (Login), the Web API defaults to `qn=32` (480P).
