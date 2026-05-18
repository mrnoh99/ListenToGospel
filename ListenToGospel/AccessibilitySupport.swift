//
//  AccessibilitySupport.swift
//  ListenToGospel
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared label typography for gospel grid, header title, sleep timer, and playback.
enum AppControlTypography {
    static let labelFont: Font = .body.weight(.semibold)
}

/// Shared dimensions for 2×2 gospel cells and floating glass control bars.
enum AppControlLayout {
    static let barHeight: CGFloat = 48
    static let barCornerRadius: CGFloat = 14
    static let floatingBarHorizontalInset: CGFloat = 4
    static let floatingBarVerticalInset: CGFloat = 6
    static let barHorizontalPadding: CGFloat = 16
}

enum AccessibilitySupport {
    enum Haptic {
        case play
        case stop
        case chapterChange
        case selection
    }

    static func spokenDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0초" }

        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return "\(hours)시간 \(minutes)분 \(secs)초"
        }
        if minutes > 0 {
            return "\(minutes)분 \(secs)초"
        }
        return "\(secs)초"
    }

    static func haptic(_ kind: Haptic) {
        #if os(iOS)
        switch kind {
        case .play:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .stop:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .chapterChange:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #endif
    }
}

