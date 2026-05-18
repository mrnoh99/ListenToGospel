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
            "아래 챕터 목록에서 원하는 챕터를 두 번 탭하면 그 챕터부터 재생됩니다.",
            "맨 아래 재생 버튼에 재생할 장 이름이 표시됩니다. 두 번 탭하여 재생하거나 정지하고, 다시 누르면 이어 들을 수 있습니다.",
            "항목 그룹은 복음서 듣기 제목, 복음 네 칸, 타이머, 이전·재생·다음입니다. 화면에 보이는 복음서 이름은 항목에서 빼 두었습니다.",
            "항목 그룹과 챕터 목록 사이는 두 손가락 위·아래로 층을 이동합니다. 로터의 층 이동·컨테이너, 동작 메뉴의 층 이동도 씁니다.",
            "한 손가락 왼쪽·오른쪽은 챕터 목록에서 챕터를, 항목 그룹에서는 같은 층 안 항목을 이동합니다. 챕터는 챕터 이동 로터로도 고를 수 있습니다.",
            "타이머 버튼으로 30, 60, 90, 120분 수면 타이머를 켤 수 있습니다.",
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
            "항목 그룹과 챕터 목록 사이는 두 손가락 위·아래, 로터의 층 이동, 컨테이너, 또는 동작의 층 이동으로 오갑니다. 챕터 순환은 동작 메뉴 또는 챕터 이동 로터를 사용합니다.",
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
