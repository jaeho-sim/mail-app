//
//  PlatformPresentation.swift
//  MailApp
//
//  Shared helper for finding a presentation anchor (view controller / window)
//  for sign-in flows, used by both Google and Apple sign-in.
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum PlatformPresentation {
    #if os(iOS)
    static func presentingViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }?.rootViewController
    }
    #elseif os(macOS)
    static func presentingWindow() -> NSWindow? {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
    }
    #endif
}
