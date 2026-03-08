# PRD: Bilibili TV (Native Apple TV Client)

## 1. Product Overview
**Bilibili TV** is a native Apple TV (tvOS) application that provides a high-performance, responsive interface for browsing and watching Bilibili content. By leveraging Bilibili's TV-optimized APIs and Apple's native media player, it delivers a superior experience compared to a web-based approach.

## 2. Target Platform
- **OS**: tvOS 16.0+
- **Device**: Apple TV 4K / Apple TV HD

## 3. Core Features
### 3.1. Native Content Browsing
- **Home/Trending**: A grid view of popular and recommended videos. [Implemented]
- **Personalized Feed**: Logged-in users can access personalized recommendations. [Implemented]
- **Search**: Fast, native search interface using the Apple TV keyboard. [Implemented]
- **Categories**: Browse videos by zone (Anime, Games, Technology, etc.). [Implemented]

### 3.2. Native Video Playback
- **AVPlayer Integration**: High-performance playback with support for 1080p and 4K streams (where available). [Implemented]
- **Native Controls**: Support for the standard Apple TV playback UI, including scrubbing, play/pause, and Siri Remote gestures. [Implemented]
- **Resolution Selector**: In-player quality picker (240p–1080p) using Bilibili `qn` values. [Implemented]
- **Bullet Comments (Danmaku)**: Toggleable live comment overlay during playback. [Implemented]

### 3.3. User Experience (UX)
- **Focus-Based Navigation**: Full integration with the tvOS focus engine for seamless remote control.
- **Fast Loading**: Native API calls and image caching for a smooth browsing experience.
- **Clear Back Navigation**: Explicit on-screen Back button in detail views for reliable return to previous screens. [Implemented]

## 4. Technical Stack
- **Language**: Swift
- **Framework**: SwiftUI
- **Player**: `AVPlayer` / `AVPlayerViewController`
- **Networking**: `URLSession` with custom Bilibili signature generation.
- **API Strategy**: Utilizing "Cloud Video Little TV" (云视听小电视) credentials for TV-optimized streams.

## 5. User Interface (UI)
- **Sidebar**: Standard tvOS navigation menu (Home, Search, Settings).
- **Account Tab**: QR-based login screen and session status. [Implemented]
- **Video Grid**: Responsive grid layout with large thumbnails and video titles.
- **Detail View**: Rich metadata, including description, view counts, and related videos.
- **Detail Navigation**: Visible Back button in the top leading toolbar for tvOS remotes. [Implemented]
- **Player Overlay**: Top-right quality button to switch resolution during playback. [Implemented]
- **Player Overlay**: Danmaku on/off toggle in the playback menu. [Implemented]

## 6. Constraints & Challenges
- **API Signing**: Implementing the MD5-based signature algorithm required by Bilibili's App APIs.
- **Video Formats**: Handling DASH or FLV streams within `AVPlayer` (may require mapping or specific headers).
- **Authentication**: Implementing QR code login for TV-based account access.

## 7. Roadmap
- **Phase 1**: Core Networking (Signature & API calls) and Home Grid. [Completed]
- **Phase 2**: Search and Category browsing. [Completed]
- **Phase 3**: Video Playback with `AVPlayer`. [Completed]
- **Phase 4**: User Login (QR Code) and Personalization. [Planned]
