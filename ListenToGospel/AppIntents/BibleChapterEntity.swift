//
//  BibleChapterEntity.swift
//  ListenToGospel
//

import AppIntents
import Foundation

struct BibleChapterEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "복음 챕터")
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
                  (1...Bible.Gospel.chapterCount(for: gospel)).contains(number) else {
                return nil
            }
            return BibleChapterEntity(gospel: gospel, number: number)
        }
    }

    func suggestedEntities() async throws -> [BibleChapterEntity] {
        Bible.Gospel.allCases.flatMap { gospel in
            (1...Bible.Gospel.chapterCount(for: gospel)).map { BibleChapterEntity(gospel: gospel, number: $0) }
        }
    }

    func entities(matching string: String) async throws -> [BibleChapterEntity] {
        let text = Self.stripVerbsAndParticles(from: string)

        guard let chapterNumber = extractChapterNumber(from: text) else { return [] }

        return Bible.Gospel.allCases.compactMap { gospel in
            guard text.contains(gospel.shortName)
                || text.contains(gospel.koreanName)
                || text.contains(gospel.audioFilePrefix) else {
                return nil
            }
            guard chapterNumber <= Bible.Gospel.chapterCount(for: gospel) else { return nil }
            return BibleChapterEntity(gospel: gospel, number: chapterNumber)
        }
    }

    /// Strip common Korean filler verbs/particles so Siri transcripts like
    /// "요한복음서 3장 틀어줘" reduce to "요한복음서 3장".
    private static let strippablePhrases: [String] = [
        "틀어주세요", "틀어줘", "틀어",
        "들려주세요", "들려줘", "들려",
        "재생해주세요", "재생해줘", "재생",
        "들어보자", "들어보고싶어", "듣고싶어", "들어볼래",
        "플레이"
    ]

    private static func stripVerbsAndParticles(from string: String) -> String {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        for phrase in strippablePhrases {
            text = text.replacingOccurrences(of: phrase, with: " ")
        }
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }

    private func extractChapterNumber(from text: String) -> Int? {
        var normalized = text
        if normalized.hasSuffix("챕터") {
            normalized = String(normalized.dropLast(2))
            normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if normalized.hasSuffix("장") {
            normalized.removeLast()
            normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let match = normalized.range(of: #"\d+"#, options: .regularExpression) else {
            return nil
        }
        return Int(normalized[match])
    }
}
