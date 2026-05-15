//
//  ContentView.swift
//  ListenToGospel
//
//  Created by NohJaisung on 5/12/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var player = BiblePlayerViewModel()
    @State private var isSleepTimerPickerPresented = false
    @ScaledMetric(relativeTo: .title2) private var sleepTimerLineMinHeight: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var chapterListRowEstimate: CGFloat = 54
    @ScaledMetric(relativeTo: .title3) private var gospelGridCellMinHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .title2) private var sleepTimerGridCellMinHeight: CGFloat = 68
    private let gospelColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private static let sleepTimerTimedOptions: [BiblePlayerViewModel.SleepTimerOption] = [
        .thirtyMinutes,
        .sixtyMinutes,
        .ninetyMinutes,
        .oneHundredTwentyMinutes
    ]

    private let playingChapterRowBackground = Color.teal.opacity(0.34)
    private let playingChapterIconColor = Color.teal

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 20) {
                Text("복음서듣기")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                gospelPicker
                selectedGospelSummary
                chapterListSection
                playbackControls
                playbackMessage
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Text("by njs 2026")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active || newPhase == .inactive || newPhase == .background {
                player.reassertAudioPlaybackIfNeeded()
            }
        }
        .sheet(isPresented: $isSleepTimerPickerPresented) {
            sleepTimerPickerSheet
        }
    }

    private var gospelPicker: some View {
        LazyVGrid(columns: gospelColumns, spacing: 12) {
            ForEach(Bible.Gospel.allCases) { gospel in
                Button {
                    player.selectGospelInGrid(gospel)
                } label: {
                    Text(gospel.shortName)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: gospelGridCellMinHeight)
                        .foregroundStyle(player.selectedGospel == gospel ? .white : .primary)
                        .background(
                            player.selectedGospel == gospel ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var selectedGospelSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(player.selectedGospel.koreanName)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text("총 \(player.selectedGospel.chapterCount)장")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            sleepTimerSelectionTriggerButton
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
    }

    private var sleepTimerPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: gospelColumns, spacing: 12) {
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
    }

    @ViewBuilder
    private var sleepTimerSummary: some View {
        if let endDate = player.sleepTimerEndDate {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text("남은 시간: \(sleepTimerRemainingText(until: endDate, now: timeline.date))")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            Text("남은 시간: ∞")
                .font(.title2.bold())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
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

    private var chapterListSection: some View {
        VStack(spacing: 8) {
            sleepTimerSummary
                .frame(maxWidth: .infinity, minHeight: sleepTimerLineMinHeight, alignment: .center)
            chapterList
        }
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
                            }

                            Spacer(minLength: 4)

                            if chapter == player.currentPlayingChapter {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(playingChapterIconColor)
                            } else if chapter == player.selectedChapter {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
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
            }
            .id(player.selectedGospel)
            .frame(height: 210 + 2 * chapterListRowEstimate)
            .environment(\.defaultMinListRowHeight, 52)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onChange(of: player.selectedGospel) { _, gospel in
                Task { @MainActor in
                    await Task.yield()
                    scrollToChapter(listAnchorChapter(for: gospel), with: proxy)
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
    }

    @ViewBuilder
    private var playbackMessage: some View {
        if let message = player.playbackMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func listAnchorChapter(for gospel: Bible.Gospel) -> BibleChapter {
        if let playing = player.currentPlayingChapter, playing.gospel == gospel {
            return playing
        }
        if player.selectedChapter.gospel == gospel {
            return player.selectedChapter
        }
        return gospel.chapters[0]
    }

    private func scrollToChapter(_ chapter: BibleChapter, with proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(chapter.id, anchor: .center)
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
