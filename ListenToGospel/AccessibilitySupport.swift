//
//  AccessibilitySupport.swift
//  ListenToGospel
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AccessibilitySupport {
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

    static func announce(_ message: String) {
        guard !message.isEmpty else { return }
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}

extension BiblePlayerViewModel.SleepTimerOption {
    var accessibilityLabel: String {
        switch self {
        case .continuous:
            return "계속 재생, 수면 타이머 없음"
        default:
            return "\(title) 후 자동 정지"
        }
    }
}
