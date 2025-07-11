//
//  clipScopeApp.swift
//  clipScope
//
//  Created by Sam Roman on 7/10/25.
//

import SwiftUI

@main
struct clipScopeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NestView()
        }
    }
}
