# Bilibili tvOS App Progress Summary

## Overview
This file summarizes the recent troubleshooting and development progress for the Bilibili tvOS application to ensure a smooth handoff for future sessions.

## Key Fixes & Architecture Decisions

### 1. Bilibili API & WAF Workarounds
*   **Android TV Feed**: The home feed correctly uses `https://app.bilibili.com/x/v2/feed/index` with the `android_tv_yst` mobile app signature (`appkey=4409e2f1fb3795a8`). This provides the appropriate 10-foot UI JSON response (which includes `cards` and nested `args`).
*   **Bypassing WAF for Details & Playback**: Sending TV signatures to the web API (`api.bilibili.com`) was triggering Bilibili's Web Application Firewall (WAF), returning an HTML error page (which caused a JSON decoding `<` character crash). To fix this, we created a dedicated `requestWeb` pipeline in `BilibiliApiService.swift` for `/x/web-interface/view` and `/x/player/playurl`. This uses standard Mac Safari User-Agents without the TV signatures, allowing us to successfully retrieve the `cid` and MP4 playback URLs.
*   **Robust Data Models**: The `BilibiliApiResponse` and its sub-models (`VideoItem`, `VideoDetailResponse`, etc.) were made entirely optional. This prevents a single missing field (like an empty description or missing owner) from crashing the entire feed parser.

### 2. tvOS Focus Engine & Navigation
*   **Stable IDs**: The `VideoItem` model now uses a highly stable `id` derived from `bvid`, `aid`, or a title hash. This is strictly required for the tvOS Focus Engine to track which item is highlighted during scrolling.
*   **Navigation Architecture**: On tvOS, wrapping a `TabView` inside a `NavigationStack` breaks all button clicks. The architecture was restructured so that `TabView` is the absolute root, and each tab (Home, Search, Categories) has its own standalone `NavigationStack`.
*   **Click Interaction**: The `VideoCard` component is now wrapped directly in a `NavigationLink(destination:)` with a `.buttonStyle(.card)`. This allows the Siri Remote to correctly focus, scale, and click into the `VideoDetailView`.
*   **Pagination**: Implemented infinite scrolling in `HomeView` using the `idx` parameter from the previous API response. Also added an explicit "Load More" button to ensure the focus engine has a clear target at the bottom of the grid.

### 3. Media & Assets
*   **App Transport Security (ATS)**: Apple enforces HTTPS. Bilibili image APIs often return `http://` URLs. We implemented a `.httpsUrl` string extension that automatically upgrades all `cover`, `pic`, and `face` URLs to secure connections to prevent `-1022` network errors.
*   **Video Playback**: Forced the playback format to `fnval=1` (MP4) because the native `AVPlayer` on tvOS does not support Bilibili's default FLV format. Lowered default quality to `qn=32` to avoid requiring a logged-in user session for higher resolutions.
*   **App Icon & Top Shelf**: Replaced the default Xcode assets with a custom anime icon. Used `sips` to automatically crop to the 5:3 ratio for icons (400x240, 800x480) and 8:3 ratio for the Top Shelf (1920x720, 3840x1440), and updated the `Contents.json` accordingly.
