//
//  BibleChapterEntity.swift
//  ListenToGospel
//

import AppIntents
import Foundation

struct BibleChapterEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "복음 장")
    static var defaultQuery = BibleChapterEntityQuery()

    var id: String
    var gospel: Bible.Gospel
    var number: Int

    init(gospel: Bible.Gospel, number: Int) {
        self.gospel = gospel
        self.number = number
        self.id = "\(gospel.rawValue)-\(number)"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(gospel.shortName) \(number)장")
    }
}

struct BibleChapterEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [BibleChapterEntity.ID]) async throws -> [BibleChapterEntity] {
        identifiers.compactMap { identifier in
            let parts = identifier.split(separator: "-", maxSplits: 1)
            guard parts.count == 2,
                  let gospelValue = Int(parts[0]),
                  let gospel = Bible.Gospel(rawValue: gospelValue),
                  let number = Int(parts[1]),
                  (1...gospel.chapterCount).contains(number) else {
                return nil
            }
            return BibleChapterEntity(gospel: gospel, number: number)
        }
    }

    func suggestedEntities() async throws -> [BibleChapterEntity] {
        Bible.Gospel.allCases.flatMap { gospel in
            (1...gospel.chapterCount).map { BibleChapterEntity(gospel: gospel, number: $0) }
        }
    }

    func entities(matching string: String) async throws -> [BibleChapterEntity] {
        let text = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "재생", with: "")
            .replacingOccurrences(of: "들려줘", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let chapterNumber = extractChapterNumber(from: text) else { return [] }

        return Bible.Gospel.allCases.compactMap { gospel in
            guard text.contains(gospel.shortName)
                || text.contains(gospel.koreanName)
                || text.contains(gospel.audioFilePrefix) else {
                return nil
            }
            guard chapterNumber <= gospel.chapterCount else { return nil }
            return BibleChapterEntity(gospel: gospel, number: chapterNumber)
        }
    }

    private func extractChapterNumber(from text: String) -> Int? {
        var normalized = text
        if normalized.hasSuffix("장") {
            normalized.removeLast()
            normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let match = normalized.range(of: #"\d+"#, options: .regularExpression) else {
            return nil
        }
        return Int(normalized[match])
    }
}
