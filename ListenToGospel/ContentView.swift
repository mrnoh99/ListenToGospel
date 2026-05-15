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
    @ScaledMetric(relativeTo: .subheadline) private var sleepTimerLineMinHeight: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var chapterListRowEstimate: CGFloat = 54
    @ScaledMetric(relativeTo: .title3) private var gospelGridCellMinHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .title2) private var sleepTimerGridCellMinHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var gospelGridSpacing: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var topContentInset: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var bottomContentInset: CGFloat = 56
    @ScaledMetric(relativeTo: .caption2) private var footerBarHeight: CGFloat = 28

    private var gospelColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gospelGridSpacing),
            GridItem(.flexible(), spacing: gospelGridSpacing)
        ]
    }

    private static let sleepTimerTimedOptions: [BiblePlayerViewModel.SleepTimerOption] = [
        .thirtyMinutes,
        .sixtyMinutes,
        .ninetyMinutes,
        .oneHundredTwentyMinutes
    ]

    private let playingChapterRowBackground = Color.teal.opacity(0.34)
    private let playingChapterIconColor = Color.teal

    var body: some View {
        GeometryReader { geometry in
            let scrollMinHeight = max(0, geometry.size.height - footerBarHeight)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: topContentInset)

                        mainContent

                        Spacer(minLength: bottomContentInset)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: scrollMinHeight)
                }
                .scrollIndicators(.hidden)

                footerBar
                    .frame(height: footerBarHeight)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active || newPhase == .inactive || newPhase == .background {
                player.reassertAudioPlaybackIfNeeded()
            }
        }
        .sheet(isPresented: $isSleepTimerPickerPresented) {
            sleepTimerPickerSheet
        }
        .onAppear {
            player.refreshLaunchResumeOffer()
            AccessibilityVoiceGuide.shared.presentIfNeeded()
        }
    }

    private var footerBar: some View {
        Text("by njs 2026")
            .font(.system(size: 8))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHidden(true)
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            Text("복음서듣기")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            gospelPicker
            selectedGospelSummary

            chapterList
                .accessibilityElement(children: .contain)
                .accessibilityLabel("장 목록")

            launchResumeOfferBanner
            playbackControls
            playbackMessage
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var launchResumeOfferBanner: some View {
        if let offer = player.launchResumeOffer {
            Button {
                player.resumeFromLaunchOffer()
            } label: {
                Label(offer.buttonTitle, systemImage: "play.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .accessibilityLabel(offer.accessibilityLabel)
            .accessibilityHint("두 번 탭하여 이어서 재생합니다")
            .accessibilityInputLabels([offer.buttonTitle, "이어서 재생", "이어서 재생 탭"])
            .accessibilityIdentifier("launch-resume-offer")
        }
    }

    private var gospelPicker: some View {
        LazyVGrid(columns: gospelColumns, spacing: gospelGridSpacing) {
            ForEach(Bible.Gospel.allCases) { gospel in
                Button {
                    player.selectGospelInGrid(gospel)
                } label: {
                    Text(gospel.shortName)
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, minHeight: gospelGridCellMinHeight)
                        .foregroundStyle(player.selectedGospel == gospel ? .white : .primary)
                        .background(
                            player.selectedGospel == gospel ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(gospel.shortName)
                .accessibilityInputLabels(VoiceControlLabels.gospel(gospel))
                .accessibilityHint("두 번 탭하여 이 복음의 장 목록을 표시합니다")
                .accessibilityValue(player.selectedGospel == gospel ? "선택됨" : "")
                .accessibilityAddTraits(player.selectedGospel == gospel ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("gospel-\(gospel.accessibilitySuffix)")
            }
        }
    }

    private var selectedGospelSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.selectedGospel.koreanName)
                        .font(.title2.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text("총 \(player.selectedGospel.chapterCount)장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(player.selectedGospel.koreanName), 총 \(player.selectedGospel.chapterCount)장")
                .frame(maxWidth: .infinity, alignment: .leading)

                sleepTimerSelectionTriggerButton
            }

            sleepTimerSummary
                .frame(maxWidth: .infinity, minHeight: sleepTimerLineMinHeight, alignment: .center)
                .padding(.top, -6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sleepTimerSelectionTriggerButton: some View {
        Button {
            player.recordBrowseInteractionWhilePlaying()
            isSleepTimerPickerPresented = true
        } label: {
            Label("시간 선택", systemImage: "timer")
                .font(.title2.bold())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("수면 타이머")
        .accessibilityInputLabels(VoiceControlLabels.sleepTimer)
        .accessibilityHint("두 번 탭하여 자동 정지 시간을 선택합니다")
        .accessibilityValue(player.sleepTimerOption.accessibilityLabel)
        .accessibilityIdentifier("sleep-timer-button")
    }

    private var sleepTimerPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: gospelColumns, spacing: gospelGridSpacing) {
                        ForEach(Self.sleepTimerTimedOptions) { option in
                            sleepTimerOptionButton(option) {
                                isSleepTimerPickerPresented = false
                            }
                        }
                    }

                    sleepTimerOptionButton(.continuous) {
                        isSleepTimerPickerPresented = false
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("시간 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        isSleepTimerPickerPresented = false
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sleepTimerOptionButton(_ option: BiblePlayerViewModel.SleepTimerOption, dismissSheet: @escaping () -> Void) -> some View {
        Button {
            player.sleepTimerOption = option
            player.recordBrowseInteractionWhilePlaying()
            dismissSheet()
        } label: {
            Text(option.title)
                .font(.title.bold())
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: sleepTimerGridCellMinHeight)
                .foregroundStyle(player.sleepTimerOption == option ? .white : .primary)
                .background(
                    player.sleepTimerOption == option ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.accessibilityLabel)
        .accessibilityHint("두 번 탭하여 수면 타이머로 설정합니다")
        .accessibilityAddTraits(player.sleepTimerOption == option ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var sleepTimerSummary: some View {
        if let endDate = player.sleepTimerEndDate {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text("남은 시간: \(sleepTimerRemainingText(until: endDate, now: timeline.date))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel(sleepTimerRemainingAccessibilityLabel(until: endDate, now: timeline.date))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        } else {
            Text("남은 시간: ∞")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("수면 타이머 없음, 계속 재생")
        }
    }

    private func sleepTimerRemainingAccessibilityLabel(until endDate: Date, now: Date) -> String {
        let remaining = max(0, endDate.timeIntervalSince(now))
        return "수면 타이머 남은 시간 \(AccessibilitySupport.spokenDuration(remaining))"
    }

    private func sleepTimerRemainingText(until endDate: Date, now: Date) -> String {
        let seconds = endDate.timeIntervalSince(now)
        guard seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
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

    private func playbackElapsedAndTotalText() -> String {
        let elapsed = player.playbackElapsedSeconds
        let total = player.playbackDurationSeconds
        guard total > 0 else {
            return formatPlaybackTime(elapsed)
        }
        return "\(formatPlaybackTime(elapsed)) / \(formatPlaybackTime(total))"
    }

    @ViewBuilder
    private var chapterRowPlaybackProgress: some View {
        Group {
            if player.playbackDurationSeconds > 0 {
                ProgressView(
                    value: min(player.playbackElapsedSeconds, player.playbackDurationSeconds),
                    total: player.playbackDurationSeconds
                )
                .progressViewStyle(.linear)
                .tint(playingChapterIconColor)
            } else {
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.linear(duration: 0.2), value: player.playbackElapsedSeconds)
        .accessibilityHidden(true)
    }

    private var chapterList: some View {
        let chapters = player.selectedGospel.chapters

        return ScrollViewReader { proxy in
            List(chapters) { chapter in
                Button {
                    player.play(chapter)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(chapter.title)
                                .fontWeight(chapter == player.currentPlayingChapter ? .semibold : .regular)
                                .lineLimit(1)

                            if player.isPlaying,
                               chapter == player.currentPlayingChapter,
                               player.playbackDurationSeconds > 0 {
                                Text(playbackElapsedAndTotalText())
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .accessibilityHidden(true)
                            }

                            Spacer(minLength: 4)

                            if chapter == player.currentPlayingChapter {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(playingChapterIconColor)
                                    .accessibilityHidden(true)
                            } else if chapter == player.selectedChapter {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                            }
                        }

                        if player.isPlaying, chapter == player.currentPlayingChapter {
                            chapterRowPlaybackProgress
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .id(chapter.id)
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowBackground(chapter == player.currentPlayingChapter ? playingChapterRowBackground : Color.clear)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chapter.title)
                .accessibilityInputLabels(VoiceControlLabels.chapter(chapter))
                .accessibilityHint("두 번 탭하여 이 장을 재생합니다")
                .accessibilityValue(chapterRowAccessibilityValue(chapter))
                .accessibilityAddTraits(chapter == player.currentPlayingChapter && player.isPlaying ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(chapter.id)
            }
            .id(player.selectedGospel)
            .listStyle(.plain)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .frame(height: 210 + 2 * chapterListRowEstimate, alignment: .top)
            .environment(\.defaultMinListRowHeight, 52)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
                scrollToTopOfChapterList(for: player.selectedGospel, with: proxy)
            }
            .onChange(of: player.selectedGospel) { _, gospel in
                Task { @MainActor in
                    await Task.yield()
                    scrollToTopOfChapterList(for: gospel, with: proxy)
                }
            }
            .onChange(of: player.currentPlayingChapter) { _, chapter in
                guard let chapter, chapter.gospel == player.selectedGospel else { return }
                scrollToCurrentChapter(chapter, with: proxy)
            }
            .onChange(of: player.scrollRequestID) { _, _ in
                let chapter = player.currentPlayingChapter
                    ?? (player.selectedChapter.gospel == player.selectedGospel ? player.selectedChapter : nil)
                guard let chapter, chapter.gospel == player.selectedGospel else { return }
                scrollToChapter(chapter, with: proxy)
            }
        }
    }

    private var playbackControls: some View {
        Button {
            if player.isPlaying {
                player.stop()
            } else if !player.resumePlaybackAfterStop() {
                player.playFromSelection()
            }
        } label: {
            Label(player.isPlaying ? "정지" : "재생", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, minHeight: gospelGridCellMinHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(player.isPlaying ? .red : .accentColor)
        .accessibilityLabel(player.isPlaying ? "정지" : "재생")
        .accessibilityInputLabels(player.isPlaying ? VoiceControlLabels.playbackStop : VoiceControlLabels.playbackPlay)
        .accessibilityHint(playbackControlAccessibilityHint)
        .accessibilityIdentifier("playback-button")
    }

    private var playbackControlAccessibilityHint: String {
        if player.isPlaying {
            return "두 번 탭하여 재생을 정지합니다"
        }
        if player.resumeBookmarkAvailable {
            return "두 번 탭하여 정지했던 위치에서 이어 재생합니다"
        }
        return "두 번 탭하여 선택한 장부터 재생합니다"
    }

    private func chapterRowAccessibilityValue(_ chapter: BibleChapter) -> String {
        if player.isPlaying, chapter == player.currentPlayingChapter {
            if player.playbackDurationSeconds > 0 {
                let elapsed = AccessibilitySupport.spokenDuration(player.playbackElapsedSeconds)
                let total = AccessibilitySupport.spokenDuration(player.playbackDurationSeconds)
                return "재생 중, \(elapsed) 경과, 전체 \(total)"
            }
            return "재생 중"
        }
        if chapter == player.selectedChapter {
            return "선택됨"
        }
        return ""
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

    private func scrollToTopOfChapterList(for gospel: Bible.Gospel, with proxy: ScrollViewProxy) {
        guard let firstChapter = gospel.chapters.first else { return }
        scrollToChapter(firstChapter, with: proxy, anchor: .top)
    }

    private func scrollToChapter(
        _ chapter: BibleChapter,
        with proxy: ScrollViewProxy,
        anchor: UnitPoint = .top
    ) {
        withAnimation {
            proxy.scrollTo(chapter.id, anchor: anchor)
        }
    }

    private func scrollToCurrentChapter(_ chapter: BibleChapter?, with proxy: ScrollViewProxy) {
        guard let chapter else { return }
        scrollToChapter(chapter, with: proxy)
    }
}

#Preview {
    ContentView()
}
