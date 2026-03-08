# Bilibili tvOS

A native tvOS client for browsing and watching Bilibili content with QR login, personalized feed, and playback features tailored for Apple TV.

## Features
- Home feed with **Trending** and **Personalized** modes
- Search and category browsing
- Video detail view + playback
- In‑player **Quality** selector (720p/1080p)
- **Danmaku** (bullet comments) overlay with on/off toggle
- QR code login with account info display

## Requirements
- Xcode 15+
- tvOS 16+

## Run
1. Open the project in Xcode.
2. Build and run on an Apple TV simulator or device.

## Login (QR)
1. Go to **Account** tab.
2. Select **Generate QR Code** and scan with the Bilibili mobile app.
3. After confirmation, account info appears and **Personalized** feed becomes active.

## Playback Controls
- Open the player’s menu (“…” / Options) to change **Quality** or toggle **Danmaku**.

## Notes
- Some videos may downgrade quality depending on availability and login state.
- Danmaku availability depends on the video’s `cid` and comment endpoint.

## Project Layout
- `bilibili_tvos/Views` — UI
- `bilibili_tvos/Services` — API + auth
- `bilibili_tvos/Models` — data models
- `bilibili_tvos/Utils` — helpers (image cache, etc.)

## License
Private project.
