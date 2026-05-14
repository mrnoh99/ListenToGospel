//
//  BiblePlayerViewModel.swift
//  ListenToGospel
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
    /// Elapsed time of the current `AVPlayerItem` (for in-list progress UI).
    @Published private(set) var playbackElapsedSeconds: TimeInterval = 0
    /// Duration of the current `AVPlayerItem` when known (`> 0`); otherwise `0`.
    @Published private(set) var playbackDurationSeconds: TimeInterval = 0

    private let player = AVQueuePlayer()
    private let supportedAudioExtensions = ["m4a", "mp3"]
    private var itemChapters: [ObjectIdentifier: BibleChapter] = [:]
    private var playbackObservers: [NSObjectProtocol] = []
    private var playbackTimeObserver: Any?
    private var lastObservedCurrentItemID: ObjectIdentifier?
    private var sleepTimerTask: Task<Void, Never>?
    private var isRemoteCommandCenterConfigured = false
    private var isAudioInterruptionObserverRegistered = false

    private struct PlaybackResumeBookmark {
        let chapter: BibleChapter
        let time: CMTime
    }

    private var resumeBookmark: PlaybackResumeBookmark?
    private var navigationSnapBackTask: Task<Void, Never>?

    func selectChapter(_ chapter: BibleChapter) {
        selectedChapter = chapter
    }

    func selectGospelInGrid(_ gospel: Bible.Gospel) {
        if selectedGospel == gospel {
            if let playing = currentPlayingChapter, playing.gospel == gospel {
                selectedChapter = playing
                requestScrollToCurrentChapter()
            }
            considerSchedulingNavigationSnapBackAfterBrowsing()
            return
        }
        selectedGospel = gospel
        considerSchedulingNavigationSnapBackAfterBrowsing()
    }

    func play(_ chapter: BibleChapter) {
        cancelNavigationSnapBack()
        resumeBookmark = nil
        selectedChapter = chapter
        playFromSelection()
    }

    func playFromSelection() {
        cancelNavigationSnapBack()
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
        cancelNavigationSnapBack()
        guard let bookmark = resumeBookmark else { return false }

        let resumeChapter = bookmark.chapter
        let resumeTime = bookmark.time

        if resumeChapter.gospel != selectedGospel {
            selectedGospel = resumeChapter.gospel
        }
        selectedChapter = resumeChapter

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
        startPlayback(seekTo: resumeTime)
        return true
    }

    func pause() {
        cancelNavigationSnapBack()
        player.pause()
        sleepTimerTask?.cancel()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        cancelNavigationSnapBack()
        configureAudioSession()

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
        cancelNavigationSnapBack()
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
        playbackElapsedSeconds = 0
        playbackDurationSeconds = 0
        clearNowPlayingInfo()
    }

    /// Called when the app moves between foreground, inactive, or background while playback should continue (e.g. screen lock).
    func reassertAudioPlaybackIfNeeded() {
        guard isPlaying else { return }
        configureAudioSession()
        if player.rate == 0, player.currentItem != nil {
            player.play()
        }
        updateNowPlayingInfo()
    }

    /// While playing, call when the user moves the 2×2 gospel grid (or similar) so 20s of no such interaction snaps UI to the current track.
    func recordBrowseInteractionWhilePlaying() {
        considerSchedulingNavigationSnapBackAfterBrowsing()
    }

    private func cancelNavigationSnapBack() {
        navigationSnapBackTask?.cancel()
        navigationSnapBackTask = nil
    }

    private func considerSchedulingNavigationSnapBackAfterBrowsing() {
        cancelNavigationSnapBack()

        guard isPlaying, let playing = currentPlayingChapter else { return }
        guard !navigationUIAlignedWithCurrentTrack(playing) else { return }

        navigationSnapBackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 20_000_000_000)
            } catch {
                return
            }
            self.snapUIToCurrentTrackIfStillNeeded()
        }
    }

    private func navigationUIAlignedWithCurrentTrack(_ playing: BibleChapter) -> Bool {
        selectedGospel == playing.gospel && selectedChapter.id == playing.id
    }

    private func snapUIToCurrentTrackIfStillNeeded() {
        navigationSnapBackTask = nil
        guard isPlaying, let playing = currentPlayingChapter else { return }
        guard !navigationUIAlignedWithCurrentTrack(playing) else { return }

        if selectedGospel != playing.gospel {
            selectedGospel = playing.gospel
        }
        if selectedChapter.id != playing.id {
            selectedChapter = playing
        }
        requestScrollToCurrentChapter()
    }

    private func configureAudioSession() {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        registerAudioInterruptionObserverOnce()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
        } catch {
            playbackMessage = "오디오 세션 설정에 실패했습니다: \(error.localizedDescription)"
        }
        #endif
    }

    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func registerAudioInterruptionObserverOnce() {
        guard !isAudioInterruptionObserverRegistered else { return }
        isAudioInterruptionObserverRegistered = true

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleAudioSessionInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }
    }

    private func handleAudioSessionInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
            return
        }

        switch type {
        case .began:
            break
        case .ended:
            let optionsValue = optionsRaw ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            guard options.contains(.shouldResume), isPlaying else { return }
            configureAudioSession()
            player.play()
            updateNowPlayingInfo()
        @unknown default:
            break
        }
    }
    #endif

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
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.player.play()
                    self.playbackDidStart()
                }
            }
        } else {
            player.play()
            playbackDidStart()
        }
    }

    private func playbackDidStart() {
        cancelNavigationSnapBack()
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
                self?.handlePotentialQueueItemTransition()
            }
        }

        playbackObservers.append(observer)
    }

    private func addPlaybackTimeObserverIfNeeded() {
        guard playbackTimeObserver == nil else { return }

        playbackTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 4),
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.observePlayerProgress()
            }
        }
    }

    private func removePlaybackObservers() {
        playbackObservers.forEach(NotificationCenter.default.removeObserver)
        playbackObservers = []
    }

    /// `AVQueuePlayer` can still report the finished `currentItem` in the same turn as `AVPlayerItemDidPlayToEndTime`; re-check after a yield so the playing row advances with the queue.
    private func handlePotentialQueueItemTransition() {
        observePlayerProgress()
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.observePlayerProgress()
        }
    }

    private func observePlayerProgress() {
        let currentItemID = player.currentItem.map(ObjectIdentifier.init)

        if currentItemID != lastObservedCurrentItemID {
            lastObservedCurrentItemID = currentItemID
            updateCurrentPlayingChapter()
            requestScrollToCurrentChapter()
        }

        updateNowPlayingInfo()
        refreshPlaybackProgressForUI()
    }

    private func updateCurrentPlayingChapter() {
        guard let currentItem = player.currentItem else {
            currentPlayingChapter = nil
            isPlaying = false
            playbackElapsedSeconds = 0
            playbackDurationSeconds = 0
            return
        }

        currentPlayingChapter = itemChapters[ObjectIdentifier(currentItem)]
        updateNowPlayingInfo()
        refreshPlaybackProgressForUI()
    }

    private func refreshPlaybackProgressForUI() {
        guard isPlaying, player.currentItem != nil else {
            playbackElapsedSeconds = 0
            playbackDurationSeconds = 0
            return
        }

        let elapsed = player.currentTime().seconds
        playbackElapsedSeconds = elapsed.isFinite ? max(0, elapsed) : 0

        if let item = player.currentItem {
            let dur = item.duration.seconds
            if dur.isFinite, dur > 0 {
                playbackDurationSeconds = dur
            } else {
                playbackDurationSeconds = 0
            }
        }
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
            MPMediaItemPropertyArtist: "복음서듣기",
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
