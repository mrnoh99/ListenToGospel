//
//  ListenToGospelShortcuts.swift
//  ListenToGospel
//

import AppIntents

// MARK: - Intents

struct PlayBibleChapterIntent: AppIntent {
    static var title: LocalizedStringResource = "복음 챕터 재생"
    static var description = IntentDescription("선택한 복음과 챕터를 재생합니다.")
    static var openAppWhenRun = true

    @Parameter(title: "복음 챕터")
    var chapter: BibleChapterEntity

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$chapter) 재생")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await BiblePlayerStore.shared.playGospelChapter(chapter.gospel, chapter: chapter.number)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct ResumePlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "이어서 재생"
    static var description = IntentDescription("정지했던 위치에서 이어 듣거나 선택한 챕터를 재생합니다.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await BiblePlayerStore.shared.resumePlayback()
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

enum SleepTimerMinutes: Int, AppEnum {
    case thirty = 30
    case sixty = 60
    case ninety = 90
    case oneTwenty = 120

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "분")

    static var caseDisplayRepresentations: [SleepTimerMinutes: DisplayRepresentation] = [
        .thirty: DisplayRepresentation(title: "30분"),
        .sixty: DisplayRepresentation(title: "60분"),
        .ninety: DisplayRepresentation(title: "90분"),
        .oneTwenty: DisplayRepresentation(title: "120분")
    ]
}

struct SetSleepTimer30Intent: AppIntent {
    static var title: LocalizedStringResource = "수면 타이머 30분"
    static var description = IntentDescription("30분 후 재생을 자동으로 멈춥니다.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await BiblePlayerStore.shared.setSleepTimer(minutes: 30)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct SetSleepTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "수면 타이머 설정"
    static var description = IntentDescription("재생 중 자동으로 멈출 시간을 설정합니다.")
    static var openAppWhenRun = true

    @Parameter(title: "시간")
    var minutes: SleepTimerMinutes

    static var parameterSummary: some ParameterSummary {
        Summary("수면 타이머 \(\.$minutes)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await BiblePlayerStore.shared.setSleepTimer(minutes: minutes.rawValue)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct StopPlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "재생 정지"
    static var description = IntentDescription("현재 재생을 정지합니다.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await MainActor.run { () -> String in
            let store = BiblePlayerStore.shared
            guard store.viewModel.isPlaying else {
                return "재생 중이 아닙니다."
            }
            store.viewModel.stop()
            return "재생을 정지했습니다."
        }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Shortcuts provider

struct ListenToGospelShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayBibleChapterIntent(),
            phrases: [
                "\(\.$chapter) in \(.applicationName)",
                "\(\.$chapter) 재생 in \(.applicationName)",
                "\(\.$chapter) 틀어줘 in \(.applicationName)",
                "\(\.$chapter) 들려줘 in \(.applicationName)",
                "\(.applicationName) \(\.$chapter) 틀어줘",
                "\(.applicationName) \(\.$chapter) 들려줘",
                "\(.applicationName)에서 \(\.$chapter) 틀어줘",
                "\(.applicationName)에서 \(\.$chapter) 들려줘",
                "\(.applicationName)에서 \(\.$chapter) 재생"
            ],
            shortTitle: "복음 챕터 재생",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: SetSleepTimer30Intent(),
            phrases: [
                "수면 타이머 30분 in \(.applicationName)",
                "\(.applicationName) 수면 타이머 30분"
            ],
            shortTitle: "수면 30분",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: ResumePlaybackIntent(),
            phrases: [
                "\(.applicationName)에서 이어서 재생",
                "이어서 재생 in \(.applicationName)",
                "\(.applicationName) 계속 재생",
                "\(.applicationName) 이어 들려줘",
                "\(.applicationName) 이어서 틀어줘",
                "\(.applicationName)에서 계속 들려줘",
                "\(.applicationName)에서 다시 들려줘"
            ],
            shortTitle: "이어서 재생",
            systemImageName: "play.circle"
        )

        AppShortcut(
            intent: SetSleepTimerIntent(),
            phrases: [
                "\(.applicationName) 수면 타이머 \(\.$minutes)",
                "수면 타이머 \(\.$minutes) in \(.applicationName)",
                "\(.applicationName)에서 \(\.$minutes) 후 정지"
            ],
            shortTitle: "수면 타이머",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: StopPlaybackIntent(),
            phrases: [
                "\(.applicationName) 정지",
                "재생 정지 in \(.applicationName)",
                "\(.applicationName) 멈춰",
                "\(.applicationName) 그만",
                "\(.applicationName)에서 정지",
                "\(.applicationName)에서 멈춰"
            ],
            shortTitle: "재생 정지",
            systemImageName: "stop.fill"
        )
    }
}
