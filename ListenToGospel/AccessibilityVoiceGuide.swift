//
//  AccessibilityVoiceGuide.swift
//  ListenToGospel
//

import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Spoken onboarding for VoiceOver users (~30 seconds).
@MainActor
final class AccessibilityVoiceGuide: NSObject {
    static let shared = AccessibilityVoiceGuide()

    private let userDefaultsKey = "hasCompletedAccessibilityVoiceGuide"
    private let synthesizer = AVSpeechSynthesizer()
    private var pendingLines: [String] = []
    private var currentLineIndex = 0

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func presentIfNeeded() {
        #if os(iOS)
        guard UIAccessibility.isVoiceOverRunning else { return }
        #else
        return
        #endif
        guard !UserDefaults.standard.bool(forKey: userDefaultsKey) else { return }

        pendingLines = [
            "복음서듣기에 오신 것을 환영합니다. 화면 읽기로 사용하는 방법을 안내합니다.",
            "먼저 위쪽 네 개 버튼에서 마태오, 마르코, 루카, 요한 복음 중 하나를 고릅니다.",
            "아래 장 목록에서 원하는 장을 두 번 탭하면 그 장부터 재생됩니다.",
            "맨 아래 재생 버튼으로 정지할 수 있고, 다시 누르면 멈춘 위치에서 이어 들을 수 있습니다.",
            "오른쪽 시간 선택 버튼으로 30, 60, 90, 120분 수면 타이머를 켤 수 있습니다.",
            "시리와 단축어로도 사용할 수 있습니다. 예를 들어, 마태오 3장 재생, 이어서 재생, 수면 타이머 30분.",
            "이 안내는 다시 듣지 않습니다. 말씀 편히 들으세요."
        ]

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            currentLineIndex = 0
            speakCurrentLine()
        }
    }

    func replayTutorial() {
        pendingLines = [
            "복음서듣기 사용 안내입니다.",
            "복음 버튼 선택, 장 목록에서 두 번 탭하여 재생, 재생 버튼으로 정지와 이어 듣기, 시간 선택으로 수면 타이머.",
            "시리로 마태오 3장 재생, 이어서 재생, 수면 타이머 30분도 말할 수 있습니다."
        ]
        currentLineIndex = 0
        speakCurrentLine()
    }

    private func speakCurrentLine() {
        guard currentLineIndex < pendingLines.count else {
            pendingLines = []
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            return
        }

        let utterance = AVSpeechUtterance(string: pendingLines[currentLineIndex])
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.preUtteranceDelay = currentLineIndex == 0 ? 0.2 : 0.45
        utterance.postUtteranceDelay = 0.35
        synthesizer.speak(utterance)
    }
}

extension AccessibilityVoiceGuide: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !pendingLines.isEmpty else { return }
            currentLineIndex += 1
            speakCurrentLine()
        }
    }
}
