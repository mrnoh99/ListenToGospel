//
//  Bible.swift
//  ListenToGospel
//
//  Created by NohJaisung on 5/12/26.
//

import Foundation

struct Bible {
    enum Gospel: Int, CaseIterable, Identifiable, Hashable {
        case matthew
        case mark
        case luke
        case john

        var id: Int { rawValue }

        var koreanName: String {
            switch self {
            case .matthew: return "마태오복음서"
            case .mark: return "마르코복음서"
            case .luke: return "루카복음서"
            case .john: return "요한복음서"
            }
        }

        var shortName: String {
            switch self {
            case .matthew: return "마태오"
            case .mark: return "마르코"
            case .luke: return "루카"
            case .john: return "요한"
            }
        }

        /// UI tests · App Store screenshot automation
        var accessibilitySuffix: String {
            switch self {
            case .matthew: return "matthew"
            case .mark: return "mark"
            case .luke: return "luke"
            case .john: return "john"
            }
        }

        var englishName: String {
            switch self {
            case .matthew: return "Gospel of Matthew"
            case .mark: return "Gospel of Mark"
            case .luke: return "Gospel of Luke"
            case .john: return "Gospel of John"
            }
        }

        var chapterCount: Int {
            switch self {
            case .matthew: return 28
            case .mark: return 16
            case .luke: return 24
            case .john: return 21
            }
        }

        var audioFolderName: String {
            switch self {
            case .matthew: return "01.마태오복음"
            case .mark: return "02.마르코복음"
            case .luke: return "03.루카복음"
            case .john: return "04.요한복음"
            }
        }

        var audioFilePrefix: String {
            switch self {
            case .matthew: return "마태오복음"
            case .mark: return "마르코복음"
            case .luke: return "루카복음"
            case .john: return "요한복음"
            }
        }

        var chapters: [BibleChapter] {
            (1...chapterCount).map {
                BibleChapter(gospel: self, number: $0)
            }
        }

        func playbackOrder(startingAt chapter: BibleChapter) -> [BibleChapter] {
            playbackOrder(startingAtIndex: chapter.number - 1)
        }

        func playbackOrder(startingAtIndex index: Int) -> [BibleChapter] {
            let chapters = chapters
            let startIndex = normalizedIndex(index, count: chapters.count)

            return Array(chapters[startIndex...]) + Array(chapters[..<startIndex])
        }

        private func normalizedIndex(_ index: Int, count: Int) -> Int {
            guard count > 0 else { return 0 }
            return ((index % count) + count) % count
        }
    }
}

struct BibleChapter: Identifiable, Hashable {
    let gospel: Bible.Gospel
    let number: Int

    var id: String { resourceName }
    var title: String { "\(gospel.koreanName) \(number)장" }
    var resourceName: String { "\(gospel.audioFilePrefix) \(String(format: "%02d", number))장" }
    var resourceSubdirectory: String { "AudioFiles/\(gospel.audioFolderName)" }
    var resourceDisplayPath: String { "\(resourceSubdirectory)/\(resourceName).m4a" }
}
