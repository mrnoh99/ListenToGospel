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
            // Keep `resumeBookmark` when browsing other gospels while stopped so Play resumes the stopped track.
            if let playing = currentPlayingChapter, playing.gospel == selectedGospel {
                selectedChapter = playing
            } else if let stoppedChapter = stoppedResumeChapter(for: selectedGospel) {
                selectedChapter = stoppedChapter
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
            AccessibilitySupport.haptic(.selection)
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
    @Published private(set) var launchResumeOffer: LaunchResumeOffer?

    private let player = AVQueuePlayer()
    private let supportedAudioExtensions = ["m4a", "mp3"]
    private var itemChapters: [ObjectIdentifier: BibleChapter] = [:]
    private var playbackObservers: [NSObjectProtocol] = []
    private var playbackTimeObserver: Any?
    private var lastObservedCurrentItemID: ObjectIdentifier?
    private var sleepTimerTask: Task<Void, Never>?
    private var isRemoteCommandCenterConfigured = false
    private var isAudioInterruptionObserverRegistered = false
    /// Set when Siri or the system briefly interrupts playback; cleared after resume or stop.
    private var shouldResumeAfterAudioInterruption = false

    private struct PlaybackResumeBookmark {
        let chapter: BibleChapter
        let time: CMTime
    }

    private var resumeBookmark: PlaybackResumeBookmark?
    private var navigationSnapBackTask: Task<Void, Never>?
    private var launchResumeOfferDismissed = false
    private var lastPersistedChapterID: String?
    private var lastPersistedElapsed: TimeInterval = -1

    init() {
        refreshLaunchResumeOffer()
    }

    /// Whether stopping left a chapter position that Play can resume.
    var resumeBookmarkAvailable: Bool {
        resumeBookmark != nil
    }

    /// Chapter shown on the play/stop control: now playing, resume target, launch offer, or next from selection.
    var playbackTargetChapter: BibleChapter {
        if let currentPlayingChapter {
            return currentPlayingChapter
        }
        if let resumeBookmark {
            return resumeBookmark.chapter
        }
        if let launchResumeOffer {
            return launchResumeOffer.chapter
        }
        return selectedChapter
    }

    var playbackTargetChapterTitle: String {
        playbackTargetChapter.title
    }

    func selectChapter(_ chapter: BibleChapter) {
        selectedChapter = chapter
    }

    func refreshLaunchResumeOffer() {
        guard !launchResumeOfferDismissed, !isPlaying, resumeBookmark == nil else {
            launchResumeOffer = nil
            return
        }
        guard let saved = PlaybackPersistence.load(),
              let chapter = saved.chapter,
              saved.elapsedSeconds >= 3 else {
            launchResumeOffer = nil
            return
        }
        launchResumeOffer = LaunchResumeOffer(chapter: chapter, elapsedSeconds: saved.elapsedSeconds)
        if selectedGospel != chapter.gospel {
            selectedGospel = chapter.gospel
        }
        selectedChapter = chapter
    }

    func dismissLaunchResumeOffer() {
        launchResumeOfferDismissed = true
        launchResumeOffer = nil
    }

    @discardableResult
    func resumeFromLaunchOffer() -> Bool {
        guard let offer = launchResumeOffer else { return false }

        launchResumeOfferDismissed = true
        launchResumeOffer = nil

        resumeBookmark = PlaybackResumeBookmark(
            chapter: offer.chapter,
            time: CMTime(seconds: offer.elapsedSeconds, preferredTimescale: 600)
        )

        guard resumePlaybackAfterStop() else { return false }
        AccessibilitySupport.haptic(.play)
        return true
    }

    func selectGospelInGrid(_ gospel: Bible.Gospel) {
        if selectedGospel == gospel {
            if let playing = currentPlayingChapter, playing.gospel == gospel {
                selectedChapter = playing
                requestScrollToCurrentChapter()
            } else if let stoppedChapter = stoppedResumeChapter(for: gospel) {
                selectedChapter = stoppedChapter
                requestScrollToCurrentChapter()
            }
            considerSchedulingNavigationSnapBackAfterBrowsing()
            return
        }
        selectedGospel = gospel
        AccessibilitySupport.haptic(.selection)
        if stoppedResumeChapter(for: gospel) != nil {
            requestScrollToCurrentChapter()
        }
        considerSchedulingNavigationSnapBackAfterBrowsing()
    }

    /// Chapter left stopped with a resume position for the given gospel, if any.
    func stoppedResumeChapter(for gospel: Bible.Gospel) -> BibleChapter? {
        guard !isPlaying,
              let bookmark = resumeBookmark,
              bookmark.chapter.gospel == gospel else {
            return nil
        }
        return bookmark.chapter
    }

    func play(_ chapter: BibleChapter) {
        cancelNavigationSnapBack()
        resumeBookmark = nil
        launchResumeOffer = nil
        selectedChapter = chapter
        playFromSelection()
    }

    /// Tap the playing chapter row to stop; tap again to resume from the stopped position.
    func toggleChapterPlayback(_ chapter: BibleChapter) {
        if isPlaying, currentPlayingChapter == chapter {
            stop()
            return
        }

        if !isPlaying, resumeBookmark?.chapter == chapter {
            selectedChapter = chapter
            if resumePlaybackAfterStop() {
                return
            }
        }

        play(chapter)
    }

    func canResumeChapter(_ chapter: BibleChapter) -> Bool {
        !isPlaying && resumeBookmark?.chapter == chapter
    }

    func playFromSelection() {
        cancelNavigationSnapBack()
        
        playbackMessage = nil
        currentPlayingChapter = nil

        guard rebuildChapterQueue() else {
            isPlaying = false
            playbackMessage = missingAudioPlaybackMessage(for: selectedGospel)
            return
        }

        // 실제 재생 시작 직전에만 오디오 세션 설정
        configureAudioSession()
        configureNowPlayingSupportIfNeeded()
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

        playbackMessage = nil
        currentPlayingChapter = nil

        guard rebuildChapterQueue() else {
            isPlaying = false
            playbackMessage = missingAudioPlaybackMessage(for: resumeChapter.gospel)
            return false
        }

        // 실제 재생 시작 직전에만 오디오 세션 설정
        configureAudioSession()
        configureNowPlayingSupportIfNeeded()
        
        resumeBookmark = nil
        startPlayback(seekTo: resumeTime)
        return true
    }

    func pause() {
        cancelNavigationSnapBack()
        shouldResumeAfterAudioInterruption = false
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
        shouldResumeAfterAudioInterruption = false
        var pausedElapsed: TimeInterval = 0
        var pausedDuration: TimeInterval = 0
        if let item = player.currentItem,
           let chapter = itemChapters[ObjectIdentifier(item)] {
            let time = player.currentTime()
            resumeBookmark = PlaybackResumeBookmark(chapter: chapter, time: time)
            if time.seconds.isFinite {
                pausedElapsed = max(0, time.seconds)
            }
            let duration = item.duration.seconds
            if duration.isFinite, duration > 0 {
                pausedDuration = duration
            }
        }

        player.pause()
        resetQueueState()
        sleepTimerTask?.cancel()
        missingResourceNames = []
        playbackMessage = nil
        currentPlayingChapter = nil
        isPlaying = false
        if resumeBookmark != nil {
            playbackElapsedSeconds = pausedElapsed
            playbackDurationSeconds = pausedDuration
        } else {
            playbackElapsedSeconds = 0
            playbackDurationSeconds = 0
        }
        clearNowPlayingInfo()

        if let bookmark = resumeBookmark {
            persistPlayback(from: bookmark.chapter, elapsedSeconds: CMTimeGetSeconds(bookmark.time))
        }

        AccessibilitySupport.haptic(.stop)
        refreshLaunchResumeOffer()
    }

    /// Called when the app moves between foreground, inactive, or background while playback should continue (e.g. screen lock).
    func reassertAudioPlaybackIfNeeded() {
        guard isPlaying else { return }
        
        // 시리 등의 외부 인터럽션 후 오디오 세션 복원
        Task {
            // 잠시 대기 (다른 오디오 앱이 완전히 종료될 시간)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            
            await MainActor.run {
                configureAudioSession()
                
                // 오디오 세션이 성공적으로 설정되었고 플레이어가 정지되어 있다면 재생 재개
                if player.rate == 0, player.currentItem != nil,
                   !(playbackMessage?.contains("오디오 설정 중 문제가 발생했습니다") == true) {
                    player.play()
                }
                updateNowPlayingInfo()
            }
        }
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
        
        // 앱 시작 시에는 더 안전하게 처리
        Task {
            // 앱 시작 시 오디오 세션이 준비될 때까지 대기
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초 대기
            
            do {
                let session = AVAudioSession.sharedInstance()
                
                // 현재 오디오 세션 상태 확인 - 불필요한 변경 방지
                let currentCategory = session.category
                let currentMode = session.mode
                
                // 이미 올바른 설정이라면 세션 조작을 피함
                if currentCategory == .playback && currentMode == .spokenAudio {
                    await MainActor.run {
                        if playbackMessage?.contains("오디오 설정 중 문제가 발생했습니다") == true {
                            playbackMessage = nil
                        }
                    }
                    return
                }
                
                // 앱 시작 시에는 매우 안전한 설정만 적용
                try session.setCategory(.playback, mode: .default, options: [])
                
                // 세션 활성화 시도 (실패해도 앱 시작을 방해하지 않음)
                do {
                    try session.setActive(true)
                    
                    // 성공한 경우에만 더 구체적인 설정 적용
                    try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP, .mixWithOthers])
                    
                } catch {
                    // 활성화에 실패해도 기본 카테고리는 설정되었으므로 진행
                    print("오디오 세션 활성화 지연됨: \(error)")
                }
                
                // 성공하면 기존 에러 메시지 제거
                await MainActor.run {
                    if playbackMessage?.contains("오디오 설정 중 문제가 발생했습니다") == true ||
                       playbackMessage?.contains("오디오 세션 설정에 실패했습니다") == true {
                        playbackMessage = nil
                    }
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    // 앱 시작 시에는 오류 메시지를 표시하지 않음 (사용자가 재생을 시도할 때까지)
                    print("앱 시작 시 오디오 세션 설정 지연됨: \(error)")
                    
                    // 실제 재생 시도 시에만 오류 메시지 표시
                    if isPlaying {
                        let errorMessage: String
                        
                        if let avError = error as? AVError {
                            switch avError.code {
                            case .applicationIsNotAuthorized:
                                errorMessage = "오디오 권한이 없습니다. 설정에서 권한을 확인해주세요."
                            default:
                                errorMessage = "오디오 설정 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요."
                            }
                        } else {
                            // 일반적인 오디오 세션 오류 처리
                            let description = error.localizedDescription.lowercased()
                            if description.contains("interrupted") || description.contains("interrupt") {
                                errorMessage = "다른 앱의 오디오 사용으로 중단되었습니다. 잠시 후 다시 시도해주세요."
                            } else if description.contains("resource") || description.contains("busy") {
                                errorMessage = "오디오 리소스를 사용할 수 없습니다. 다른 앱 종료 후 시도해주세요."
                            } else if description.contains("category") || description.contains("mode") {
                                errorMessage = "오디오 설정을 변경할 수 없습니다. 잠시 후 다시 시도해주세요."
                            } else {
                                errorMessage = "오디오 설정 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요."
                            }
                        }
                        
                        playbackMessage = errorMessage
                    }
                }
            }
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
            guard isPlaying else { return }
            // Siri / system UI: pause AVPlayer only (keep `isPlaying` so we can resume).
            shouldResumeAfterAudioInterruption = true
            player.pause()

        case .ended:
            let shouldResume = shouldResumeAfterAudioInterruption
            shouldResumeAfterAudioInterruption = false
            clearAudioInterruptionPlaybackMessage()

            guard shouldResume, isPlaying else { return }

            // Siri often omits `.shouldResume`; still restore when we paused for interruption.
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            let systemSaysResume = options.contains(.shouldResume)
            resumePlaybackAfterExternalInterruption(systemSaysResume: systemSaysResume)

        @unknown default:
            break
        }
    }

    private func clearAudioInterruptionPlaybackMessage() {
        if playbackMessage?.contains("다른 앱의 오디오 사용으로") == true {
            playbackMessage = nil
        }
    }

    private func resumePlaybackAfterExternalInterruption(systemSaysResume: Bool) {
        Task {
            // Brief delay so Siri / system audio releases the session.
            let delay: UInt64 = systemSaysResume ? 300_000_000 : 500_000_000
            try? await Task.sleep(nanoseconds: delay)

            await MainActor.run {
                guard self.isPlaying, self.player.currentItem != nil else { return }
                guard !(self.playbackMessage?.contains("오디오 설정 중 문제가 발생했습니다") == true) else {
                    return
                }

                self.configureAudioSession()
                #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
                try? AVAudioSession.sharedInstance().setActive(true)
                #endif

                if self.player.rate == 0 {
                    self.player.play()
                }
                self.updateNowPlayingInfo()
                self.clearAudioInterruptionPlaybackMessage()
            }
        }
    }
    #endif

    private func resourceNameVariants(_ name: String) -> [String] {
        let nfc = name.precomposedStringWithCanonicalMapping
        let nfd = name.decomposedStringWithCanonicalMapping
        var variants: [String] = []
        for candidate in [name, nfc, nfd] where !variants.contains(candidate) {
            variants.append(candidate)
        }
        return variants
    }

    private func audioURL(for chapter: BibleChapter) -> URL? {
        let resourceNames = resourceNameVariants(chapter.resourceName)

        for subdirectory in audioSubdirectoryPaths(for: chapter) {
            for resourceName in resourceNames {
                for fileExtension in supportedAudioExtensions {
                    if let url = Bundle.main.url(
                        forResource: resourceName,
                        withExtension: fileExtension,
                        subdirectory: subdirectory
                    ) {
                        return url
                    }
                }
            }
        }

        for resourceName in resourceNames {
            for fileExtension in supportedAudioExtensions {
                if let url = Bundle.main.url(
                    forResource: resourceName,
                    withExtension: fileExtension
                ) {
                    return url
                }
            }
        }

        if let url = audioURLFromDirectoryListing(for: chapter) {
            return url
        }

        return audioURLByWalkingBundle(for: chapter)
    }

    private func audioSubdirectoryPaths(for chapter: BibleChapter) -> [String] {
        let folderVariants = resourceNameVariants(chapter.gospel.audioFolderName)
        var paths: [String] = [
            chapter.resourceSubdirectory,
            "ListenToGospel/\(chapter.resourceSubdirectory)"
        ]

        for folder in folderVariants {
            paths.append("AudioFiles/\(folder)")
            paths.append("ListenToGospel/AudioFiles/\(folder)")
        }

        var unique: [String] = []
        for path in paths where !unique.contains(path) {
            unique.append(path)
        }
        return unique
    }

    private func audioURLFromDirectoryListing(for chapter: BibleChapter) -> URL? {
        guard let resourceBase = Bundle.main.resourceURL else { return nil }
        let target = chapter.resourceName.precomposedStringWithCanonicalMapping

        for directoryURL in audioDirectoryURLs(for: chapter, resourceBase: resourceBase) {
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ) else {
                continue
            }

            for fileURL in fileURLs {
                guard supportedAudioExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                let stem = fileURL.deletingPathExtension().lastPathComponent
                if stem.precomposedStringWithCanonicalMapping == target {
                    return fileURL
                }
            }
        }
        return nil
    }

    private func audioDirectoryURLs(for chapter: BibleChapter, resourceBase: URL) -> [URL] {
        var directories: [URL] = []

        for subdirectory in audioSubdirectoryPaths(for: chapter) {
            directories.append(resourceBase.appendingPathComponent(subdirectory, isDirectory: true))
        }

        let folderTarget = chapter.gospel.audioFolderName.precomposedStringWithCanonicalMapping
        for audioRootName in ["AudioFiles", "ListenToGospel/AudioFiles"] {
            let audioRoot = resourceBase.appendingPathComponent(audioRootName, isDirectory: true)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: audioRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for entry in entries {
                guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                if entry.lastPathComponent.precomposedStringWithCanonicalMapping == folderTarget {
                    directories.append(entry)
                }
            }
        }

        var unique: [URL] = []
        for url in directories where !unique.contains(url) {
            unique.append(url)
        }
        return unique
    }

    private func audioURLByWalkingBundle(for chapter: BibleChapter) -> URL? {
        guard let resourceBase = Bundle.main.resourceURL else { return nil }
        let target = chapter.resourceName.precomposedStringWithCanonicalMapping
        let folderTarget = chapter.gospel.audioFolderName.precomposedStringWithCanonicalMapping

        guard let enumerator = FileManager.default.enumerator(
            at: resourceBase,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard supportedAudioExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            let stem = fileURL.deletingPathExtension().lastPathComponent
            guard stem.precomposedStringWithCanonicalMapping == target else { continue }

            let path = fileURL.path.precomposedStringWithCanonicalMapping
            if path.contains(folderTarget) {
                return fileURL
            }
        }
        return nil
    }

    private func alignSelectedChapterWithGospel() {
        guard selectedChapter.gospel != selectedGospel else { return }
        let index = min(max(selectedChapter.number - 1, 0), selectedGospel.chapterCount - 1)
        selectedChapter = selectedGospel.chapters[index]
    }

    private func missingAudioPlaybackMessage(for gospel: Bible.Gospel) -> String {
        if missingResourceNames.isEmpty {
            return "앱 번들에서 \(gospel.koreanName) 오디오 파일을 찾지 못했습니다. Xcode에서 Clean Build 후 다시 설치해 주세요."
        }

        let missingCount = missingResourceNames.count
        if missingCount == 1, let path = missingResourceNames.first {
            return "앱 번들에서 오디오 파일을 찾지 못했습니다. (\(path))"
        }
        return "앱 번들에서 \(gospel.koreanName) 오디오 \(missingCount)개를 찾지 못했습니다."
    }

    private func resetQueueState() {
        player.removeAllItems()
        removePlaybackObservers()
        itemChapters = [:]
        lastObservedCurrentItemID = nil
    }

    private func rebuildChapterQueue() -> Bool {
        alignSelectedChapterWithGospel()
        let requestedChapter = selectedChapter
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

        guard let firstItem = player.items().first,
              let firstChapter = itemChapters[ObjectIdentifier(firstItem)] else {
            return false
        }

        if selectedChapter.id != firstChapter.id {
            selectedChapter = firstChapter
            if requestedChapter.id != firstChapter.id {
                playbackMessage = "\(requestedChapter.title) 오디오를 찾지 못해 \(firstChapter.title)부터 재생합니다."
            }
        }

        return true
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

        AccessibilitySupport.haptic(.play)
        launchResumeOffer = nil
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
            let advancedToNewChapter = lastObservedCurrentItemID != nil
            lastObservedCurrentItemID = currentItemID
            updateCurrentPlayingChapter()
            requestScrollToCurrentChapter()
            if advancedToNewChapter, isPlaying, currentItemID != nil {
                AccessibilitySupport.haptic(.chapterChange)
            }
        }

        updateNowPlayingInfo()
        refreshPlaybackProgressForUI()
        persistPlaybackProgressIfNeeded()
    }

    private func updateCurrentPlayingChapter() {
        guard let currentItem = player.currentItem else {
            currentPlayingChapter = nil
            isPlaying = false
            if resumeBookmark == nil {
                playbackElapsedSeconds = 0
                playbackDurationSeconds = 0
            }
            return
        }

        currentPlayingChapter = itemChapters[ObjectIdentifier(currentItem)]
        syncSelectedChapterWithPlayback()
        updateNowPlayingInfo()
        refreshPlaybackProgressForUI()
    }

    private func syncSelectedChapterWithPlayback() {
        guard let playing = currentPlayingChapter else { return }
        guard playing.gospel == selectedGospel else { return }
        guard selectedChapter.id != playing.id else { return }
        selectedChapter = playing
    }

    private func refreshPlaybackProgressForUI() {
        guard isPlaying, player.currentItem != nil else {
            if resumeBookmark != nil {
                return
            }
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

        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false

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

    private func persistPlaybackProgressIfNeeded() {
        guard isPlaying, let chapter = currentPlayingChapter else { return }

        let elapsed = player.currentTime().seconds
        guard elapsed.isFinite, elapsed >= 3 else { return }

        let chapterID = chapter.id
        if chapterID == lastPersistedChapterID,
           abs(elapsed - lastPersistedElapsed) < 5 {
            return
        }

        lastPersistedChapterID = chapterID
        lastPersistedElapsed = elapsed
        persistPlayback(from: chapter, elapsedSeconds: elapsed)
    }

    private func persistPlayback(from chapter: BibleChapter, elapsedSeconds: TimeInterval) {
        PlaybackPersistence.save(chapter: chapter, elapsedSeconds: elapsedSeconds)
    }
}
