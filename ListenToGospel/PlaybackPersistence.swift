//
//  PlaybackPersistence.swift
//  ListenToGospel
//

import Foundation

/// Last listened position saved across app launches.
enum PlaybackPersistence {
    struct SavedSession: Codable, Equatable {
        let gospelRawValue: Int
        let chapterNumber: Int
        let elapsedSeconds: Double

        var chapter: BibleChapter? {
            guard let gospel = Bible.Gospel(rawValue: gospelRawValue),
                  (1...Bible.Gospel.chapterCount(for: gospel)).contains(chapterNumber) else {
                return nil
            }
            return gospel.chapters[chapterNumber - 1]
        }
    }

    private static let userDefaultsKey = "lastPlaybackSession"

    static func save(chapter: BibleChapter, elapsedSeconds: TimeInterval) {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else { return }

        let session = SavedSession(
            gospelRawValue: chapter.gospel.rawValue,
            chapterNumber: chapter.number,
            elapsedSeconds: elapsedSeconds
        )
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    static func load() -> SavedSession? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let session = try? JSONDecoder().decode(SavedSession.self, from: data),
              session.chapter != nil else {
            return nil
        }
        return session
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

struct LaunchResumeOffer: Equatable {
    let chapter: BibleChapter
    let elapsedSeconds: TimeInterval

    var buttonTitle: String {
        "이어서 \(chapter.shortTitle) 재생"
    }

    var accessibilityLabel: String {
        "이어서 \(AccessibilitySupport.spokenChapterTitle(for: chapter)) 재생할까요? \(AccessibilitySupport.spokenDuration(elapsedSeconds)) 위치에서 이어 듣기"
    }
}
