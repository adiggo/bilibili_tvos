//
//  bilibili_tvosApp.swift
//  bilibili_tvos
//
//  Created by Xiaoping Li on 3/7/26.
//

import SwiftUI

@main
struct bilibili_tvosApp: App {
    init() {
        if AppDebug.isEnabled {
            print("🟢 App Init: \(Date().timeIntervalSince1970)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
