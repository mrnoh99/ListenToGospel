//
//  BiblePlayerViewModel.swift
//  ListenToBible
//
//  Created by NohJaisung on 5/12/26.
//

import AVFoundation
import Combine
import CoreMedia
import Foundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif

@MainActor
final class BiblePlayerViewModel: ObservableObject {
    enum SleepTimerOption: String, CaseIterable, Identifiable {
        case thirtyMinutes
        case sixtyMinutes
        case ninetyMinutes
        case oneHundredTwentyMinutes
        case continuous

        var id: String { rawValue }

        var title: String {
            switch self {
            case .thirtyMinutes: return "30분"
            case .sixtyMinutes: return "60분"
            case .ninetyMinutes: return "90분"
            case .oneHundredTwentyMinutes: return "120분"
            case .continuous: return "계속"
            }
        }

        var duration: TimeInterval? {
            switch self {
            case .thirtyMinutes: return 30 * 60
            case .sixtyMinutes: return 60 * 60
            case .ninetyMinutes: return 90 * 60
            case .oneHundredTwentyMinutes: return 120 * 60
            case .continuous: return nil
            }
        }
    }

    @Published var selectedGospel: Bible.Gospel = .matthew {
        didSet {
            guard oldValue != selectedGospel else { return }
            resumeBookmark = nil
            if let playing = currentPlayingChapter, playing.gospel == selectedGospel {
                selectedChapter = playing
            } else {
                selectedChapter = selectedGospel.chapters[0]
            }
        }
    }

    @Published var selectedChapter = Bible.Gospel.matthew.chapters[0]
    @Published var sleepTimerOption: SleepTimerOption = .continuous {
        didSet {
            guard oldValue != sleepTimerOption else { return }
            scheduleSleepTimerIfNeeded()
        }
    }

    @Published private(set) var sleepTimerStartDate: Date?
    @Published private(set) var sleepTimerEndDate: Date?
    @Published private(set) var currentPlayingChapter: BibleChapter?
    @Published private(set) var scrollRequestID = UUID()
    @Published private(set) var missingResourceNames: [String] = []
    @Published private(set) var playbackMessage: String?
    @Published private(set) var isPlaying = false

    private let player = AVQueuePlayer()
    private let supportedAudioExtensions = ["m4a", "mp3"]
    private var itemChapters: [ObjectIdentifier: BibleChapter] = [:]
    private var playbackObservers: [NSObjectProtocol] = []
    private var playbackTimeObserver: Any?
    private var lastObservedCurrentItemID: ObjectIdentifier?
    private var sleepTimerTask: Task<Void, Never>?
    private var isRemoteCommandCenterConfigured = false

    private struct PlaybackResumeBookmark {
        let chapter: BibleChapter
        let time: CMTime
    }

    private var resumeBookmark: PlaybackResumeBookmark?

    func selectChapter(_ chapter: BibleChapter) {
        selectedChapter = chapter
    }

    func selectGospelInGrid(_ gospel: Bible.Gospel) {
        if selectedGospel == gospel {
            if let playing = currentPlayingChapter, playing.gospel == gospel {
                selectedChapter = playing
                requestScrollToCurrentChapter()
            }
            return
        }
        selectedGospel = gospel
    }

    func play(_ chapter: BibleChapter) {
        resumeBookmark = nil
        selectedChapter = chapter
        playFromSelection()
    }

    func playFromSelection() {
        configureAudioSession()
        configureNowPlayingSupportIfNeeded()

        playbackMessage = nil
        currentPlayingChapter = nil

        guard rebuildChapterQueue() else {
            isPlaying = false
            playbackMessage = "앱 번들에서 오디오 파일을 찾지 못했습니다."
            return
        }

        startPlayback(seekTo: nil)
    }

    func resumePlaybackAfterStop() -> Bool {
        guard let bookmark = resumeBookmark,
              bookmark.chapter.gospel == selectedGospel else {
            resumeBookmark = nil
            return false
        }

        let seekTime = bookmark.time
        let chapter = bookmark.chapter

        selectedChapter = chapter

        configureAudioSession()
        configureNowPlayingSupportIfNeeded()

        playbackMessage = nil
        currentPlayingChapter = nil

        guard rebuildChapterQueue() else {
            isPlaying = false
            playbackMessage = "앱 번들에서 오디오 파일을 찾지 못했습니다."
            return false
        }

        resumeBookmark = nil
        startPlayback(seekTo: seekTime)
        return true
    }

    func pause() {
        player.pause()
        sleepTimerTask?.cancel()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard !player.items().isEmpty else {
            if resumePlaybackAfterStop() { return }
            playFromSelection()
            return
        }

        player.play()
        isPlaying = true
        updateCurrentPlayingChapter()
        requestScrollToCurrentChapter()
        scheduleSleepTimerIfNeeded()
        updateNowPlayingInfo()
    }

    func stop() {
        if let item = player.currentItem,
           let chapter = itemChapters[ObjectIdentifier(item)] {
            resumeBookmark = PlaybackResumeBookmark(chapter: chapter, time: player.currentTime())
        }

        player.pause()
        resetQueueState()
        sleepTimerTask?.cancel()
        missingResourceNames = []
        playbackMessage = nil
        currentPlayingChapter = nil
        isPlaying = false
        clearNowPlayingInfo()
    }

    private func configureAudioSession() {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            playbackMessage = "오디오 세션 설정에 실패했습니다: \(error.localizedDescription)"
        }
        #endif
    }

    private func audioURL(for chapter: BibleChapter) -> URL? {
        let subdirectories: [String?] = [
            chapter.resourceSubdirectory,
            "AudioFiles",
            nil
        ]

        for subdirectory in subdirectories {
            for fileExtension in supportedAudioExtensions {
                if let url = Bundle.main.url(
                    forResource: chapter.resourceName,
                    withExtension: fileExtension,
                    subdirectory: subdirectory
                ) {
                    return url
                }
            }
        }

        return nil
    }

    private func resetQueueState() {
        player.removeAllItems()
        removePlaybackObservers()
        itemChapters = [:]
        lastObservedCurrentItemID = nil
    }

    private func rebuildChapterQueue() -> Bool {
        let order = selectedGospel.playbackOrder(startingAt: selectedChapter)

        resetQueueState()
        missingResourceNames = []

        for chapter in order {
            guard let url = audioURL(for: chapter) else {
                missingResourceNames.append(chapter.resourceDisplayPath)
                continue
            }

            let item = AVPlayerItem(url: url)
            itemChapters[ObjectIdentifier(item)] = chapter
            addPlaybackObserver(for: item)
            player.insert(item, after: nil)
        }

        return !player.items().isEmpty
    }

    private func startPlayback(seekTo seekTime: CMTime?) {
        let seconds = seekTime.map { CMTimeGetSeconds($0) } ?? 0
        let shouldSeek = seconds.isFinite && seconds > 0.25

        if shouldSeek, let seekTime {
            player.seek(
                to: seekTime,
                toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
                toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player.play()
                    self?.playbackDidStart()
                }
            }
        } else {
            player.play()
            playbackDidStart()
        }
    }

    private func playbackDidStart() {
        playbackMessage = nil
        isPlaying = true
        updateCurrentPlayingChapter()
        requestScrollToCurrentChapter()
        scheduleSleepTimerIfNeeded()
    }

    private func addPlaybackObserver(for item: AVPlayerItem) {
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.observePlayerProgress()
            }
        }

        playbackObservers.append(observer)
    }

    private func addPlaybackTimeObserverIfNeeded() {
        guard playbackTimeObserver == nil else { return }

        playbackTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 2),
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlayingInfo()
            }
        }
    }

    private func removePlaybackObservers() {
        playbackObservers.forEach(NotificationCenter.default.removeObserver)
        playbackObservers = []
    }

    private func observePlayerProgress() {
        let currentItemID = player.currentItem.map(ObjectIdentifier.init)

        if currentItemID != lastObservedCurrentItemID {
            lastObservedCurrentItemID = currentItemID
            updateCurrentPlayingChapter()
            requestScrollToCurrentChapter()
        }

        updateNowPlayingInfo()
    }

    private func updateCurrentPlayingChapter() {
        guard let currentItem = player.currentItem else {
            currentPlayingChapter = nil
            isPlaying = false
            return
        }

        currentPlayingChapter = itemChapters[ObjectIdentifier(currentItem)]
        updateNowPlayingInfo()
    }

    private func requestScrollToCurrentChapter() {
        scrollRequestID = UUID()
    }

    private func scheduleSleepTimerIfNeeded() {
        sleepTimerTask?.cancel()

        guard let duration = sleepTimerOption.duration else {
            sleepTimerStartDate = nil
            sleepTimerEndDate = nil
            return
        }

        let startDate = Date()
        sleepTimerStartDate = startDate
        sleepTimerEndDate = startDate.addingTimeInterval(duration)

        guard isPlaying else {
            return
        }

        sleepTimerTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            } catch {
                return
            }

            self?.stop()
        }
    }

    private func configureNowPlayingSupportIfNeeded() {
        configureRemoteCommandCenter()
        addPlaybackTimeObserverIfNeeded()
    }

    private func configureRemoteCommandCenter() {
        #if canImport(MediaPlayer)
        guard !isRemoteCommandCenterConfigured else { return }

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor [weak self] in
                self?.resume()
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
            return .success
        }

        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying ? self.pause() : self.resume()
            }
            return .success
        }

        isRemoteCommandCenterConfigured = true
        #endif
    }

    private func updateNowPlayingInfo() {
        #if canImport(MediaPlayer)
        guard let chapter = currentPlayingChapter else {
            clearNowPlayingInfo()
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: chapter.title,
            MPMediaItemPropertyArtist: "성경듣기",
            MPMediaItemPropertyAlbumTitle: chapter.gospel.koreanName,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        let elapsedTime = player.currentTime().seconds
        if elapsedTime.isFinite {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        }

        if let duration = player.currentItem?.duration.seconds, duration.isFinite {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }

    private func clearNowPlayingInfo() {
        #if canImport(MediaPlayer)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #endif
    }
}
