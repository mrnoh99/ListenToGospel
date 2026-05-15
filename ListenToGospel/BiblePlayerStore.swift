//
//  BiblePlayerStore.swift
//  ListenToGospel
//

import Foundation

/// Shared player used by SwiftUI and App Intents / Siri / Shortcuts.
@MainActor
final class BiblePlayerStore {
    static let shared = BiblePlayerStore()

    let viewModel: BiblePlayerViewModel

    private init() {
        viewModel = BiblePlayerViewModel()
    }

    @discardableResult
    func playGospelChapter(_ gospel: Bible.Gospel, chapter number: Int) -> String {
        guard (1...gospel.chapterCount).contains(number) else {
            return "\(gospel.koreanName)은 1장부터 \(gospel.chapterCount)장까지 있습니다."
        }
        let chapter = gospel.chapters[number - 1]
        viewModel.play(chapter)
        return "\(chapter.title) 재생을 시작합니다."
    }

    @discardableResult
    func resumePlayback() -> String {
        if viewModel.isPlaying {
            return "이미 재생 중입니다."
        }
        if viewModel.resumePlaybackAfterStop() {
            return "정지했던 위치에서 이어서 재생합니다."
        }
        viewModel.playFromSelection()
        return "\(viewModel.selectedChapter.title) 재생을 시작합니다."
    }

    @discardableResult
    func setSleepTimer(minutes: Int) -> String {
        guard let option = sleepTimerOption(for: minutes) else {
            return "30, 60, 90, 120분 중에서 선택해 주세요."
        }
        viewModel.sleepTimerOption = option
        if viewModel.isPlaying {
            return "수면 타이머 \(minutes)분이 설정되었습니다."
        }
        return "수면 타이머 \(minutes)분으로 설정했습니다. 재생 중에 적용됩니다."
    }

    private func sleepTimerOption(for minutes: Int) -> BiblePlayerViewModel.SleepTimerOption? {
        switch minutes {
        case 30: return .thirtyMinutes
        case 60: return .sixtyMinutes
        case 90: return .ninetyMinutes
        case 120: return .oneHundredTwentyMinutes
        default: return nil
        }
    }
}

extension Bible.Gospel {
    static func matching(shortName: String) -> Bible.Gospel? {
        let normalized = shortName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "복음", with: "")
            .replacingOccurrences(of: "서", with: "")

        for gospel in Bible.Gospel.allCases {
            if gospel.shortName == normalized || gospel.koreanName.contains(normalized) {
                return gospel
            }
        }
        return nil
    }
}
