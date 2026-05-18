//
//  ContentView.swift
//  ListenToGospel
//
//  Created by NohJaisung on 5/12/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var player = BiblePlayerStore.shared.viewModel
    @State private var isSleepTimerPickerPresented = false
    @State private var controlsHeaderBottomOffset: CGFloat = 0
    @Namespace private var controlsRotor
    @Namespace private var chaptersRotor
    @AccessibilityFocusState private var voiceOverFocus: VoiceOverNavigation.Focus?
    @ScaledMetric(relativeTo: .body) private var chapterListRowMinHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var chapterListRowVerticalInset: CGFloat = 12
    @ScaledMetric(relativeTo: .title3) private var controlBarHeight: CGFloat = AppControlLayout.barHeight
    @ScaledMetric(relativeTo: .body) private var gospelGridSpacing: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var floatingBarHorizontalInset: CGFloat = AppControlLayout.floatingBarHorizontalInset
    @ScaledMetric(relativeTo: .body) private var floatingBarVerticalInset: CGFloat = AppControlLayout.floatingBarVerticalInset
    @ScaledMetric(relativeTo: .body) private var topContentInset: CGFloat = 16
    @ScaledMetric(relativeTo: .caption2) private var footerBarHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var chapterListGlassPeek: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var floatingHeaderFadeHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var floatingPlaybackFadeHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var estimatedAppTitleHeight: CGFloat = 41
    @ScaledMetric(relativeTo: .body) private var headerSectionSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var headerBottomPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var controlsOverlayBottomReserve: CGFloat = 72

    private var gospelColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gospelGridSpacing),
            GridItem(.flexible(), spacing: gospelGridSpacing)
        ]
    }

    private static let chapterListEdgeSpacerRowCount = 3

    private static let sleepTimerTimedOptions: [BiblePlayerViewModel.SleepTimerOption] = [
        .thirtyMinutes,
        .sixtyMinutes,
        .ninetyMinutes,
        .oneHundredTwentyMinutes
    ]

    private let playingChapterRowBackground = Color.accentColor.opacity(0.34)
    private let playingChapterIconColor = Color.accentColor

    var body: some View {
        mainLayout
            .modifier(MainChromeModifier(
                scenePhase: scenePhase,
                isSleepTimerPickerPresented: $isSleepTimerPickerPresented,
                sleepTimerTimedOptions: Self.sleepTimerTimedOptions,
                sleepTimerActionTitle: sleepTimerActionTitle(for:),
                selectSleepTimer: selectSleepTimer(_:),
                onAppear: {
                    player.refreshLaunchResumeOffer()
                    AccessibilityVoiceGuide.shared.presentIfNeeded()
                },
                reassertPlayback: { player.reassertAudioPlaybackIfNeeded() }
            ))
            .voiceOverControlsRotor(focus: $voiceOverFocus, namespace: controlsRotor)
            .voiceOverChaptersRotor(
                focus: $voiceOverFocus,
                namespace: chaptersRotor,
                chapters: player.selectedGospel.chapters,
                onFocusChapter: { chapter in
                    player.focusChapterInList(chapter)
                }
            )
            .voiceOverLayersRotor(
                onMoveToControlsLayer: focusControlsLayerForVoiceOver,
                onMoveToChaptersLayer: focusChaptersLayerForVoiceOver
            )
            .onChange(of: isSleepTimerPickerPresented) { wasPresented, isPresented in
                if !wasPresented, isPresented {
                    announceSleepTimerRemainingTimeOnce()
                } else if wasPresented, !isPresented {
                    restoreSleepTimerAccessibilityFocus()
                }
            }
            .onPreferenceChange(ControlsHeaderBottomOffsetKey.self) { controlsHeaderBottomOffset = $0 }
            .onChange(of: player.selectedGospel) { _, gospel in
                focusStoppedResumeChapter(for: gospel)
            }
    }

    /// Top scroll inset: keeps chapter rows below the title and 2×2 grid (no overlap with 「복음서듣기」).
    private var chapterListTopContentMargin: CGFloat {
        if controlsHeaderBottomOffset > 0 {
            return controlsHeaderBottomOffset
        }
        return estimatedControlsHeaderBottomOffset
    }

    private var estimatedControlsHeaderBottomOffset: CGFloat {
        topContentInset
            + estimatedAppTitleHeight
            + headerSectionSpacing
            + (controlBarHeight * 2 + gospelGridSpacing)
            + headerBottomPadding
    }

    private var mainLayout: some View {
        VStack(spacing: 0) {
            chapterListWithFloatingControls
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            playbackMessage
                .padding(.top, 4)

            footerBar
                .frame(height: footerBarHeight)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var footerBar: some View {
        Text("by njs 2026")
            .font(.system(size: 8))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHidden(true)
    }

    private var appTitleView: some View {
        Text("복음서듣기")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(VoiceOverNavigation.appTitleAccessibilityLabel)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($voiceOverFocus, equals: .appTitle)
            .accessibilityRotorEntry(id: VoiceOverNavigation.Focus.appTitle, in: controlsRotor)
            .voiceOverControlsHorizontalBrowse(onBrowse: browseControlsForVoiceOver(forward:))
    }

    /// Title + gospel grid; measured height is the chapter list top inset.
    private var controlsHeaderChrome: some View {
        VStack(spacing: headerSectionSpacing) {
            appTitleView
            gospelPicker
        }
        .padding(.top, topContentInset)
        .padding(.bottom, headerBottomPadding)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ControlsHeaderBottomOffsetKey.self,
                    value: geometry.size.height
                )
            }
        }
    }

    private var chapterListWithFloatingControls: some View {
        ZStack(alignment: .top) {
            chaptersAccessibilityRegion
            controlsAccessibilityRegion
        }
    }

    private var chaptersAccessibilityRegion: some View {
        chapterList
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilitySortPriority(0)
    }

    private var controlsAccessibilityRegion: some View {
        voiceOverControlsOverlay
            .accessibilitySortPriority(1)
    }

    /// Single VoiceOver item group: title, 2×2 grid, sleep timer, previous · play/stop · next (gospel name excluded).
    private var voiceOverControlsOverlay: some View {
        VStack(spacing: 0) {
            controlsHeaderChrome

            floatingGospelHeaderOverlay

            Spacer(minLength: 0)
                .allowsHitTesting(false)

            floatingPlaybackOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .voiceOverControlsLayerNavigation(
            onBrowse: browseControlsForVoiceOver(forward:),
            onMoveToChaptersLayer: focusChaptersLayerForVoiceOver
        )
    }

    private var floatingGospelHeaderOverlay: some View {
        VStack(spacing: 0) {
            gospelHeaderGlassBar
                .padding(.horizontal, floatingBarHorizontalInset)
                .padding(.top, floatingBarVerticalInset)

            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground).opacity(0.42),
                    Color(uiColor: .systemBackground).opacity(0.18),
                    Color(uiColor: .systemBackground).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: floatingHeaderFadeHeight)
            .allowsHitTesting(false)
        }
    }

    private var floatingPlaybackOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground).opacity(0),
                    Color(uiColor: .systemBackground).opacity(0.18),
                    Color(uiColor: .systemBackground).opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: floatingPlaybackFadeHeight)
            .allowsHitTesting(false)

            playbackControls
                .padding(.horizontal, floatingBarHorizontalInset)
                .padding(.bottom, floatingBarVerticalInset)
        }
    }

    private var gospelPicker: some View {
        LazyVGrid(columns: gospelColumns, spacing: gospelGridSpacing) {
            ForEach(Bible.Gospel.allCases) { gospel in
                Button {
                    player.selectGospelInGrid(gospel)
                } label: {
                    Text(gospel.shortName)
                        .font(AppControlTypography.labelFont)
                        .frame(maxWidth: .infinity, minHeight: controlBarHeight)
                        .foregroundStyle(player.selectedGospel == gospel ? .white : .primary)
                        .background(
                            player.selectedGospel == gospel ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: AppControlLayout.barCornerRadius)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(VoiceOverNavigation.gospelButtonLabel(gospel))
                .accessibilityInputLabels(VoiceControlLabels.gospel(gospel))
                .accessibilityHint("두 번 탭하여 이 복음의 챕터 목록을 표시합니다")
                .accessibilityValue(player.selectedGospel == gospel ? "선택됨" : "")
                .accessibilityAddTraits(player.selectedGospel == gospel ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("gospel-\(gospel.accessibilitySuffix)")
                .accessibilityFocused($voiceOverFocus, equals: .gospel(gospel))
                .accessibilityRotorEntry(id: VoiceOverNavigation.Focus.gospel(gospel), in: controlsRotor)
                .voiceOverControlsHorizontalBrowse(onBrowse: browseControlsForVoiceOver(forward:))
            }
        }
    }

    private func selectSleepTimer(_ option: BiblePlayerViewModel.SleepTimerOption) {
        player.sleepTimerOption = option
        player.recordBrowseInteractionWhilePlaying()
        isSleepTimerPickerPresented = false
    }

    private func restoreSleepTimerAccessibilityFocus() {
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: 450_000_000)
            voiceOverFocus = .sleepTimer
        }
    }

    private func announceSleepTimerRemainingTimeOnce() {
        let announcement = sleepTimerRemainingTimeAnnouncement
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            AccessibilitySupport.announce(announcement)
        }
    }

    private var sleepTimerRemainingTimeAnnouncement: String {
        if player.sleepTimerOption == .continuous {
            return "남은시간, 무한대, 계속 재생"
        }
        if let endDate = player.sleepTimerEndDate {
            return "남은시간, \(sleepTimerVoiceOverValue(until: endDate, now: Date()))"
        }
        return "남은시간, \(player.sleepTimerOption.accessibilityLabel)"
    }

    private func sleepTimerActionTitle(for option: BiblePlayerViewModel.SleepTimerOption) -> String {
        if player.sleepTimerOption == option {
            return "\(option.title) ✓"
        }
        return option.title
    }

    private var gospelHeaderGlassBar: some View {
        makeGospelHeaderGlassBar(
            sleepTimerAccessibilityValue: sleepTimerVoiceOverValue,
            updatesFrequently: false
        )
    }

    private func makeGospelHeaderGlassBar(
        sleepTimerAccessibilityValue: String,
        updatesFrequently: Bool
    ) -> some View {
        GospelHeaderGlassBar(
            barHeight: controlBarHeight,
            gospelName: player.selectedGospel.koreanName,
            chapterCount: player.selectedGospel.chapterCount,
            onSleepTimerTap: {
                AccessibilitySupport.haptic(.selection)
                player.recordBrowseInteractionWhilePlaying()
                isSleepTimerPickerPresented = true
            },
            sleepTimerAccessibilityValue: sleepTimerAccessibilityValue,
            sleepTimerAccessibilityUpdatesFrequently: updatesFrequently,
            sleepTimerFocus: $voiceOverFocus,
            controlsRotor: controlsRotor
        ) {
            sleepTimerButtonLabel
        }
        .voiceOverControlsHorizontalBrowse(onBrowse: browseControlsForVoiceOver(forward:))
    }

    @ViewBuilder
    private var sleepTimerButtonLabel: some View {
        if player.sleepTimerOption == .continuous {
            Text("남은시간: ∞")
                .accessibilityHidden(true)
        } else if let endDate = player.sleepTimerEndDate {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text("남은시간: \(sleepTimerCountdownText(until: endDate, now: timeline.date))")
                    .accessibilityHidden(true)
            }
        } else {
            Text("남은시간: \(player.sleepTimerOption.title)")
                .accessibilityHidden(true)
        }
    }

    private var sleepTimerVoiceOverValue: String {
        if player.sleepTimerOption == .continuous {
            return "무한대, 계속 재생"
        }
        if let endDate = player.sleepTimerEndDate {
            return sleepTimerVoiceOverValue(until: endDate, now: Date())
        }
        return player.sleepTimerOption.accessibilityLabel
    }

    private func sleepTimerVoiceOverValue(until endDate: Date, now: Date) -> String {
        let remaining = max(0, endDate.timeIntervalSince(now))
        return AccessibilitySupport.spokenDuration(remaining)
    }

    private func sleepTimerCountdownText(until endDate: Date, now: Date) -> String {
        let seconds = max(0, endDate.timeIntervalSince(now))
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private var chapterListRowInsets: EdgeInsets {
        EdgeInsets(
            top: chapterListRowVerticalInset,
            leading: 16,
            bottom: chapterListRowVerticalInset,
            trailing: 16
        )
    }

    @ViewBuilder
    private func chapterListSpacerRow(id: String) -> some View {
        Color.clear
            .frame(minHeight: chapterListRowMinHeight)
            .listRowInsets(chapterListRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
            .accessibilityRemoveTraits(.isButton)
            .allowsHitTesting(false)
            .id(id)
    }

    private func chapterListRow(
        _ chapter: BibleChapter,
        onBrowseForward: @escaping () -> Void,
        onBrowseBackward: @escaping () -> Void
    ) -> some View {
        ChapterListRowView(
            chapter: chapter,
            player: player,
            rowInsets: chapterListRowInsets,
            playingBackground: playingChapterRowBackground,
            iconColor: playingChapterIconColor,
            voiceOverFocus: $voiceOverFocus,
            chaptersRotor: chaptersRotor,
            accessibilityValue: chapterRowAccessibilityValue(chapter),
            playAccessibilityHint: chapterRowPlayAccessibilityHint(chapter),
            onBrowseForward: onBrowseForward,
            onBrowseBackward: onBrowseBackward,
            onPlay: { player.toggleChapterPlayback(chapter) }
        )
    }

    private var chapterList: some View {
        ScrollViewReader { proxy in
            ChapterListScrollView(
                gospel: player.selectedGospel,
                player: player,
                proxy: proxy,
                topContentMargin: chapterListTopContentMargin,
                bottomContentMargin: controlsOverlayBottomReserve + chapterListGlassPeek,
                rowMinHeight: chapterListRowMinHeight,
                edgeSpacerRowCount: Self.chapterListEdgeSpacerRowCount,
                spacerRow: chapterListSpacerRow(id:),
                chapterRow: { chapter in
                chapterListRow(chapter, onBrowseForward: { browseChapterForVoiceOver(forward: true) }, onBrowseBackward: { browseChapterForVoiceOver(forward: false) })
            },
                onBrowseForward: { browseChapterForVoiceOver(forward: true) },
                onBrowseBackward: { browseChapterForVoiceOver(forward: false) },
                onMoveToControlsLayer: focusControlsLayerForVoiceOver,
                scrollAfterGospelSelection: scrollAfterGospelSelection(for:with:),
                scrollToCurrentChapter: scrollToCurrentChapter(_:with:),
                scrollToChapter: { scrollToChapter($0, with: proxy, anchor: .center) }
            )
        }
    }

    private var playbackControls: some View {
        PlaybackGlassMenu(
            barHeight: controlBarHeight,
            chapterTitle: player.playbackTargetChapterTitle,
            isPlaying: player.isPlaying,
            transportEnabled: player.isPlaying,
            playStopHint: playbackControlAccessibilityHint,
            onPlayStop: {
                if player.isPlaying {
                    player.stop()
                } else if player.resumePlaybackAfterStop() {
                } else if player.resumeFromLaunchOffer() {
                } else {
                    player.playFromSelection()
                }
            },
            onPrevious: { player.skipToPreviousChapter() },
            onNext: { player.skipToNextChapter() },
            controlsFocus: $voiceOverFocus,
            controlsRotor: controlsRotor
        )
        .voiceOverControlsHorizontalBrowse(onBrowse: browseControlsForVoiceOver(forward:))
    }

    private var playbackControlAccessibilityHint: String {
        if player.isPlaying {
            return "두 번 탭하여 재생을 정지합니다"
        }
        if player.resumeBookmarkAvailable {
            return "두 번 탭하여 정지했던 위치에서 이어 재생합니다"
        }
        if player.launchResumeOffer != nil {
            return "두 번 탭하여 저장된 위치에서 이어 재생합니다"
        }
        return "두 번 탭하여 선택한 챕터부터 재생합니다"
    }

    private func chapterRowAccessibilityValue(_ chapter: BibleChapter) -> String {
        if player.isPlaying, chapter == player.currentPlayingChapter {
            return "재생 중"
        }
        if player.canResumeChapter(chapter) {
            return "정지됨"
        }
        if chapter == player.selectedChapter {
            return "선택됨"
        }
        return ""
    }

    private func chapterRowPlayAccessibilityHint(_ chapter: BibleChapter) -> String {
        if player.isPlaying, chapter == player.currentPlayingChapter {
            return "두 번 탭하여 재생을 정지합니다"
        }
        if player.canResumeChapter(chapter) {
            return "두 번 탭하여 이어 재생합니다"
        }
        return "두 번 탭하여 이 챕터를 재생합니다"
    }

    @ViewBuilder
    private var playbackMessage: some View {
        if let message = player.playbackMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("알림, \(message)")
        }
    }

    private func scrollAfterGospelSelection(for gospel: Bible.Gospel, with proxy: ScrollViewProxy) {
        if player.isPlaying,
           let playing = player.currentPlayingChapter,
           playing.gospel == gospel {
            scrollToChapter(playing, with: proxy, anchor: .center)
            return
        }
        if player.canResumeChapter(player.selectedChapter),
           player.selectedChapter.gospel == gospel {
            scrollToChapter(player.selectedChapter, with: proxy, anchor: .center)
            return
        }
        guard let firstChapter = gospel.chapters.first else { return }
        scrollToChapter(firstChapter, with: proxy, anchor: .center)
    }

    private func focusStoppedResumeChapter(for gospel: Bible.Gospel) {
        guard !player.isPlaying,
              player.canResumeChapter(player.selectedChapter),
              player.selectedChapter.gospel == gospel else {
            return
        }
        let chapterID = player.selectedChapter.id
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: 150_000_000)
            voiceOverFocus = .chapter(id: chapterID)
        }
    }

    private func scrollToChapter(
        _ chapter: BibleChapter,
        with proxy: ScrollViewProxy,
        anchor: UnitPoint
    ) {
        withAnimation {
            proxy.scrollTo(chapter.id, anchor: anchor)
        }
    }

    private func scrollToCurrentChapter(_ chapter: BibleChapter?, with proxy: ScrollViewProxy) {
        guard let chapter else { return }
        scrollToChapter(chapter, with: proxy, anchor: .center)
    }

    private func browseControlsForVoiceOver(forward: Bool) {
        voiceOverFocus = VoiceOverNavigation.browseControlsLayer(
            current: voiceOverFocus,
            forward: forward,
            transportEnabled: player.isPlaying
        )
    }

    private func browseChapterForVoiceOver(forward: Bool) {
        player.browseToAdjacentChapterInList(forward: forward)
        voiceOverFocus = .chapter(id: player.selectedChapter.id)
    }

    private func focusControlsLayerForVoiceOver() {
        voiceOverFocus = VoiceOverNavigation.browseControlsLayer(
            current: voiceOverFocus,
            forward: false,
            transportEnabled: player.isPlaying
        )
    }

    private func focusChaptersLayerForVoiceOver() {
        player.focusChapterInList(player.selectedChapter)
        voiceOverFocus = .chapter(id: player.selectedChapter.id)
    }
}

// MARK: - Chapter list (split out to ease Swift type-checking)

private struct ChapterListRowView: View {
    let chapter: BibleChapter
    @ObservedObject var player: BiblePlayerViewModel
    let rowInsets: EdgeInsets
    let playingBackground: Color
    let iconColor: Color
    @AccessibilityFocusState.Binding var voiceOverFocus: VoiceOverNavigation.Focus?
    let chaptersRotor: Namespace.ID
    let accessibilityValue: String
    let playAccessibilityHint: String
    let onBrowseForward: () -> Void
    let onBrowseBackward: () -> Void
    let onPlay: () -> Void

    private var isCurrentlyPlaying: Bool {
        player.isPlaying && chapter == player.currentPlayingChapter
    }

    private var canResume: Bool {
        player.canResumeChapter(chapter)
    }

    /// Playing or stopped with a resume position — keeps the active row look.
    private var isActiveChapter: Bool {
        isCurrentlyPlaying || canResume
    }

    private var chapterProgress: (elapsed: TimeInterval, total: TimeInterval)? {
        guard isActiveChapter, player.playbackDurationSeconds > 0 else { return nil }
        return (player.playbackElapsedSeconds, player.playbackDurationSeconds)
    }

    private var showsPlaybackTime: Bool {
        chapterProgress != nil
    }

    private var playbackElapsedAndTotalLabel: String {
        guard let progress = chapterProgress else { return "0:00" }
        return "\(formatPlaybackTime(progress.elapsed)) / \(formatPlaybackTime(progress.total))"
    }

    private func formatPlaybackTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private var rowBackground: Color {
        isActiveChapter ? playingBackground : .clear
    }

    private var accessibilityTraits: AccessibilityTraits {
        isActiveChapter ? [.isButton, .isSelected] : .isButton
    }

    var body: some View {
        rowButton
            .modifier(
                ChapterListRowAccessibilityModifier(
                    chapter: chapter,
                    accessibilityValue: accessibilityValue,
                    playAccessibilityHint: playAccessibilityHint,
                    traits: accessibilityTraits,
                    voiceOverFocus: $voiceOverFocus,
                    chaptersRotor: chaptersRotor,
                    onBrowseForward: onBrowseForward,
                    onBrowseBackward: onBrowseBackward
                )
            )
    }

    private var rowButton: some View {
        Button(action: onPlay, label: { rowLabel })
            .id(chapter.id)
            .buttonStyle(.plain)
            .listRowInsets(rowInsets)
            .listRowBackground(rowBackground)
    }

    private var rowLabel: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            if let progress = chapterProgress {
                ChapterListRowProgressView(
                    elapsed: progress.elapsed,
                    total: progress.total,
                    iconColor: iconColor
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(chapter.title)
                .fontWeight(isActiveChapter ? .semibold : .regular)
                .lineLimit(1)

            if showsPlaybackTime {
                Text(playbackElapsedAndTotalLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 4)
            chapterStatusIcon
        }
    }

    @ViewBuilder
    private var chapterStatusIcon: some View {
        if isCurrentlyPlaying {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
        } else if canResume {
            Image(systemName: "stop.fill")
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
        } else if chapter == player.selectedChapter {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
    }
}

private struct ChapterListRowAccessibilityModifier: ViewModifier {
    let chapter: BibleChapter
    let accessibilityValue: String
    let playAccessibilityHint: String
    let traits: AccessibilityTraits
    @AccessibilityFocusState.Binding var voiceOverFocus: VoiceOverNavigation.Focus?
    let chaptersRotor: Namespace.ID
    let onBrowseForward: () -> Void
    let onBrowseBackward: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(ChapterListRowLabelsModifier(
                chapter: chapter,
                accessibilityValue: accessibilityValue,
                playAccessibilityHint: playAccessibilityHint,
                traits: traits
            ))
            .modifier(ChapterListRowFocusModifier(
                chapterID: chapter.id,
                voiceOverFocus: $voiceOverFocus,
                chaptersRotor: chaptersRotor,
                onBrowseForward: onBrowseForward,
                onBrowseBackward: onBrowseBackward
            ))
    }
}

private struct ChapterListRowLabelsModifier: ViewModifier {
    let chapter: BibleChapter
    let accessibilityValue: String
    let playAccessibilityHint: String
    let traits: AccessibilityTraits

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chapter.title)
            .accessibilityInputLabels(VoiceControlLabels.chapter(chapter))
            .accessibilityHint(playAccessibilityHint)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(traits)
    }
}

private struct ChapterListRowFocusModifier: ViewModifier {
    let chapterID: String
    @AccessibilityFocusState.Binding var voiceOverFocus: VoiceOverNavigation.Focus?
    let chaptersRotor: Namespace.ID
    let onBrowseForward: () -> Void
    let onBrowseBackward: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(chapterID)
            .accessibilityFocused($voiceOverFocus, equals: .chapter(id: chapterID))
            .accessibilityRotorEntry(id: VoiceOverNavigation.Focus.chapter(id: chapterID), in: chaptersRotor)
            .accessibilityScrollAction { edge in
                switch edge {
                case .trailing: onBrowseForward()
                case .leading: onBrowseBackward()
                default: break
                }
            }
    }
}

private struct ChapterListRowProgressView: View {
    let elapsed: TimeInterval
    let total: TimeInterval
    let iconColor: Color

    var body: some View {
        Group {
            if total > 0 {
                ProgressView(
                    value: min(elapsed, total),
                    total: total
                )
                .progressViewStyle(.linear)
                .tint(iconColor)
            } else {
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.linear(duration: 0.2), value: elapsed)
        .accessibilityHidden(true)
    }
}

private struct ChapterListScrollView<SpacerRow: View, ChapterRow: View>: View {
    let gospel: Bible.Gospel
    @ObservedObject var player: BiblePlayerViewModel
    let proxy: ScrollViewProxy
    let topContentMargin: CGFloat
    let bottomContentMargin: CGFloat
    let rowMinHeight: CGFloat
    let edgeSpacerRowCount: Int
    let spacerRow: (String) -> SpacerRow
    let chapterRow: (BibleChapter) -> ChapterRow
    let onBrowseForward: () -> Void
    let onBrowseBackward: () -> Void
    let onMoveToControlsLayer: () -> Void
    let scrollAfterGospelSelection: (Bible.Gospel, ScrollViewProxy) -> Void
    let scrollToCurrentChapter: (BibleChapter, ScrollViewProxy) -> Void
    let scrollToChapter: (BibleChapter) -> Void

    var body: some View {
        listContent
            .modifier(ChapterListStyleModifier(
                gospel: gospel,
                topContentMargin: topContentMargin,
                bottomContentMargin: bottomContentMargin,
                rowMinHeight: rowMinHeight,
                onBrowseForward: onBrowseForward,
                onBrowseBackward: onBrowseBackward,
                onMoveToControlsLayer: onMoveToControlsLayer
            ))
            .modifier(ChapterListScrollSyncModifier(
                player: player,
                proxy: proxy,
                scrollAfterGospelSelection: scrollAfterGospelSelection,
                scrollToCurrentChapter: scrollToCurrentChapter,
                scrollToChapter: scrollToChapter
            ))
    }

    private var listContent: some View {
        List {
            ForEach(0..<edgeSpacerRowCount, id: \.self) { index in
                spacerRow("chapter-list-top-spacer-\(index)")
            }

            ForEach(gospel.chapters) { chapter in
                chapterRow(chapter)
            }

            ForEach(0..<edgeSpacerRowCount, id: \.self) { index in
                spacerRow("chapter-list-bottom-spacer-\(index)")
            }
        }
    }
}

private struct ChapterListStyleModifier: ViewModifier {
    let gospel: Bible.Gospel
    let topContentMargin: CGFloat
    let bottomContentMargin: CGFloat
    let rowMinHeight: CGFloat
    let onBrowseForward: () -> Void
    let onBrowseBackward: () -> Void
    let onMoveToControlsLayer: () -> Void

    func body(content: Content) -> some View {
        content
            .id(gospel)
            .listStyle(.plain)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .contentMargins(.top, topContentMargin, for: .scrollContent)
            .contentMargins(.bottom, bottomContentMargin, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.defaultMinListRowHeight, rowMinHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .voiceOverChaptersLayerNavigation(
                onBrowse: { forward in
                    if forward { onBrowseForward() } else { onBrowseBackward() }
                },
                onMoveToControlsLayer: onMoveToControlsLayer
            )
    }
}

private struct ChapterListScrollSyncModifier: ViewModifier {
    @ObservedObject var player: BiblePlayerViewModel
    let proxy: ScrollViewProxy
    let scrollAfterGospelSelection: (Bible.Gospel, ScrollViewProxy) -> Void
    let scrollToCurrentChapter: (BibleChapter, ScrollViewProxy) -> Void
    let scrollToChapter: (BibleChapter) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                scrollAfterGospelSelection(player.selectedGospel, proxy)
            }
            .onChange(of: player.selectedGospel) { _, gospel in
                Task { @MainActor in
                    await Task.yield()
                    scrollAfterGospelSelection(gospel, proxy)
                }
            }
            .onChange(of: player.currentPlayingChapter) { _, chapter in
                guard let chapter, chapter.gospel == player.selectedGospel else { return }
                scrollToCurrentChapter(chapter, proxy)
            }
            .onChange(of: player.scrollRequestID) { _, _ in
                let chapter = player.currentPlayingChapter
                    ?? (player.selectedChapter.gospel == player.selectedGospel ? player.selectedChapter : nil)
                guard let chapter, chapter.gospel == player.selectedGospel else { return }
                scrollToChapter(chapter)
            }
    }
}

// MARK: - Main chrome (split out to ease Swift type-checking)

private struct MainChromeModifier: ViewModifier {
    let scenePhase: ScenePhase
    @Binding var isSleepTimerPickerPresented: Bool
    let sleepTimerTimedOptions: [BiblePlayerViewModel.SleepTimerOption]
    let sleepTimerActionTitle: (BiblePlayerViewModel.SleepTimerOption) -> String
    let selectSleepTimer: (BiblePlayerViewModel.SleepTimerOption) -> Void
    let onAppear: () -> Void
    let reassertPlayback: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active || newPhase == .inactive || newPhase == .background {
                    reassertPlayback()
                }
            }
            .confirmationDialog(
                "수면 타이머",
                isPresented: $isSleepTimerPickerPresented,
                titleVisibility: .visible
            ) {
                ForEach(sleepTimerTimedOptions) { option in
                    Button(sleepTimerActionTitle(option)) {
                        selectSleepTimer(option)
                    }
                }
                Button(sleepTimerActionTitle(.continuous)) {
                    selectSleepTimer(.continuous)
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("타이머 시간을 정합니다")
            }
            .onAppear(perform: onAppear)
    }
}

private struct ControlsHeaderBottomOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ContentView()
}
