//
//  VoiceOverNavigation.swift
//  ListenToGospel
//

import SwiftUI

/// VoiceOver focus targets and container labels for rotor / container navigation.
enum VoiceOverNavigation {
    enum Focus: Hashable {
        case appTitle
        case gospel(Bible.Gospel)
        case sleepTimer
        case skipPrevious
        case playStop
        case skipNext
        case chapter(id: String)
    }

    static let appTitleAccessibilityLabel = "찬미 예수님 복음서듣기"

    static let controlsContainerLabel = "복음서 듣기, 항목 그룹"
    static let chaptersContainerLabel = "챕터 목록, 테이블"
    static let controlsRotorName = "항목 그룹"
    static let chaptersRotorName = "챕터 이동"
    static let layersRotorName = "층 이동"

    static let moveToChaptersLayerActionName = "챕터 목록 층으로 이동"
    static let moveToControlsLayerActionName = "항목 그룹 층으로 이동"

    static let controlsContainerHint =
        "두 손가락 위·아래로 챕터 목록 층으로 이동합니다. 로터의 \(layersRotorName)·컨테이너, 동작의 \(moveToChaptersLayerActionName)도 사용할 수 있습니다. 동작의 다음·이전 항목으로 이 층 안을 이동합니다."
    static let chaptersContainerHint =
        "두 손가락 위·아래로 항목 그룹 층으로 이동합니다. 로터의 \(layersRotorName)·컨테이너, 동작의 \(moveToControlsLayerActionName)도 사용할 수 있습니다. 동작의 다음·이전 챕터, 로터의 \(chaptersRotorName), 또는 한 손가락 좌·우로 챕터를 이동합니다."

    /// VoiceOver visit order within the controls layer (title → gospels → timer → transport).
    static func controlsLayerOrder(transportEnabled: Bool) -> [Focus] {
        var order: [Focus] = [.appTitle]
        order.append(contentsOf: Bible.Gospel.allCases.map { .gospel($0) })
        order.append(.sleepTimer)
        if transportEnabled {
            order.append(contentsOf: [.skipPrevious, .playStop, .skipNext])
        } else {
            order.append(.playStop)
        }
        return order
    }

    static func browseControlsLayer(
        current: Focus?,
        forward: Bool,
        transportEnabled: Bool
    ) -> Focus {
        let order = controlsLayerOrder(transportEnabled: transportEnabled)
        guard !order.isEmpty else { return .appTitle }

        let currentIndex = current.flatMap { order.firstIndex(of: $0) } ?? -1
        let startIndex = currentIndex >= 0 ? currentIndex : 0
        let newIndex: Int
        if forward {
            newIndex = (startIndex + 1) % order.count
        } else {
            newIndex = (startIndex - 1 + order.count) % order.count
        }
        return order[newIndex]
    }

    /// VoiceOver label for a gospel grid button; `.isButton` announces "버튼" (e.g. "마태오복음서, 버튼").
    static func gospelButtonLabel(_ gospel: Bible.Gospel) -> String {
        gospel.koreanName
    }

    /// VoiceOver label for the sleep timer control; `.isButton` announces "버튼" (e.g. "타이머, 버튼").
    static let sleepTimerButtonAccessibilityLabel = "타이머"
}

extension View {
    func voiceOverControlsContainer() -> some View {
        accessibilityElement(children: .contain)
            .accessibilityLabel(VoiceOverNavigation.controlsContainerLabel)
            .accessibilityHint(VoiceOverNavigation.controlsContainerHint)
    }

    func voiceOverChaptersContainer() -> some View {
        accessibilityElement(children: .contain)
            .accessibilityLabel(VoiceOverNavigation.chaptersContainerLabel)
            .accessibilityHint(VoiceOverNavigation.chaptersContainerHint)
    }

    func voiceOverControlsLayerNavigation(
        onBrowse: @escaping (Bool) -> Void,
        onMoveToChaptersLayer: @escaping () -> Void
    ) -> some View {
        voiceOverControlsContainer()
            .accessibilityAction(named: VoiceOverNavigation.moveToChaptersLayerActionName, onMoveToChaptersLayer)
            .accessibilityAction(named: "다음 항목") { onBrowse(true) }
            .accessibilityAction(named: "이전 항목") { onBrowse(false) }
    }

    func voiceOverChaptersLayerNavigation(
        onBrowse: @escaping (Bool) -> Void,
        onMoveToControlsLayer: @escaping () -> Void
    ) -> some View {
        voiceOverChaptersContainer()
            .accessibilityAction(named: VoiceOverNavigation.moveToControlsLayerActionName, onMoveToControlsLayer)
            .accessibilityAction(named: "다음 챕터") { onBrowse(true) }
            .accessibilityAction(named: "이전 챕터") { onBrowse(false) }
    }

    /// One-finger horizontal browse within the controls layer (on individual items, not the container).
    func voiceOverControlsHorizontalBrowse(onBrowse: @escaping (Bool) -> Void) -> some View {
        accessibilityScrollAction { edge in
            switch edge {
            case .trailing: onBrowse(true)
            case .leading: onBrowse(false)
            default: break
            }
        }
    }

    func voiceOverLayersRotor(
        onMoveToControlsLayer: @escaping () -> Void,
        onMoveToChaptersLayer: @escaping () -> Void
    ) -> some View {
        accessibilityRotor(Text(VoiceOverNavigation.layersRotorName)) {
            AccessibilityRotorEntry(
                VoiceOverNavigation.controlsContainerLabel,
                id: "voiceover-layer-controls",
                prepare: onMoveToControlsLayer
            )
            AccessibilityRotorEntry(
                VoiceOverNavigation.chaptersContainerLabel,
                id: "voiceover-layer-chapters",
                prepare: onMoveToChaptersLayer
            )
        }
    }

    func voiceOverControlsRotor(
        focus: AccessibilityFocusState<VoiceOverNavigation.Focus?>.Binding,
        namespace: Namespace.ID
    ) -> some View {
        accessibilityRotor(Text(VoiceOverNavigation.controlsRotorName)) {
            AccessibilityRotorEntry(
                Text("복음서듣기"),
                id: VoiceOverNavigation.Focus.appTitle,
                in: namespace,
                prepare: { focus.wrappedValue = .appTitle }
            )
            ForEach(Bible.Gospel.allCases) { gospel in
                AccessibilityRotorEntry(
                    Text(VoiceOverNavigation.gospelButtonLabel(gospel)),
                    id: VoiceOverNavigation.Focus.gospel(gospel),
                    in: namespace,
                    prepare: { focus.wrappedValue = .gospel(gospel) }
                )
            }
            AccessibilityRotorEntry(
                Text(VoiceOverNavigation.sleepTimerButtonAccessibilityLabel),
                id: VoiceOverNavigation.Focus.sleepTimer,
                in: namespace,
                prepare: { focus.wrappedValue = .sleepTimer }
            )
            AccessibilityRotorEntry(
                Text("이전 챕터"),
                id: VoiceOverNavigation.Focus.skipPrevious,
                in: namespace,
                prepare: { focus.wrappedValue = .skipPrevious }
            )
            AccessibilityRotorEntry(
                Text("재생"),
                id: VoiceOverNavigation.Focus.playStop,
                in: namespace,
                prepare: { focus.wrappedValue = .playStop }
            )
            AccessibilityRotorEntry(
                Text("다음 챕터"),
                id: VoiceOverNavigation.Focus.skipNext,
                in: namespace,
                prepare: { focus.wrappedValue = .skipNext }
            )
        }
    }

    func voiceOverChaptersRotor(
        focus: AccessibilityFocusState<VoiceOverNavigation.Focus?>.Binding,
        namespace: Namespace.ID,
        chapters: [BibleChapter],
        onFocusChapter: @escaping (BibleChapter) -> Void
    ) -> some View {
        accessibilityRotor(Text(VoiceOverNavigation.chaptersRotorName)) {
            ForEach(chapters) { chapter in
                AccessibilityRotorEntry(
                    Text(chapter.title),
                    id: VoiceOverNavigation.Focus.chapter(id: chapter.id),
                    in: namespace,
                    prepare: {
                        onFocusChapter(chapter)
                        focus.wrappedValue = .chapter(id: chapter.id)
                    }
                )
            }
        }
    }
}
