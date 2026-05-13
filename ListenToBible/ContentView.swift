//
//  ContentView.swift
//  ListenToBible
//
//  Created by NohJaisung on 5/12/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var player = BiblePlayerViewModel()
    @ScaledMetric(relativeTo: .caption) private var sleepTimerLineMinHeight: CGFloat = 22
    private let gospelColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let playingChapterRowBackground = Color.teal.opacity(0.34)
    private let playingChapterIconColor = Color.teal

    var body: some View {
        VStack(spacing: 20) {
            Text("성경듣기")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            gospelPicker
            selectedGospelSummary
            chapterList
            playbackControls
            playbackMessage
            Spacer(minLength: 0)
            Text("by jsn 2026.05")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
    }

    private var gospelPicker: some View {
        LazyVGrid(columns: gospelColumns, spacing: 12) {
            ForEach(Bible.Gospel.allCases) { gospel in
                Button {
                    player.selectGospelInGrid(gospel)
                } label: {
                    Text(gospel.shortName)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(player.selectedGospel.koreanName)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Menu {
                        ForEach(BiblePlayerViewModel.SleepTimerOption.allCases) { option in
                            Button {
                                player.sleepTimerOption = option
                            } label: {
                                if player.sleepTimerOption == option {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        Label("시간 선택", systemImage: "timer")
                    }
                    .buttonStyle(.bordered)

                    sleepTimerSummary
                        .frame(minHeight: sleepTimerLineMinHeight, alignment: .top)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Text(player.selectedGospel.englishName)
                .foregroundStyle(.secondary)

            Text("총 \(player.selectedGospel.chapterCount)장")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sleepTimerSummary: some View {
        if let endDate = player.sleepTimerEndDate {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text("남은 시간: \(sleepTimerRemainingText(until: endDate, now: timeline.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("남은 시간: ∞")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private var chapterList: some View {
        let chapters = player.selectedGospel.chapters

        return ScrollViewReader { proxy in
            List(chapters) { chapter in
                Button {
                    player.play(chapter)
                } label: {
                    HStack {
                        Text(chapter.title)
                            .fontWeight(chapter == player.currentPlayingChapter ? .semibold : .regular)

                        Spacer()

                        if chapter == player.currentPlayingChapter {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(playingChapterIconColor)
                        } else if chapter == player.selectedChapter {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
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
            .frame(height: 210)
            .environment(\.defaultMinListRowHeight, 48)
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
                guard let chapter = player.currentPlayingChapter, chapter.gospel == player.selectedGospel else { return }
                scrollToCurrentChapter(chapter, with: proxy)
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
                .frame(maxWidth: .infinity)
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
