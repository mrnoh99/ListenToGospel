package njs.listentogospel.viewmodel

import android.app.Application
import android.os.CountDownTimer
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import njs.listentogospel.ListenToGospelApp
import njs.listentogospel.data.PlaybackPersistence
import njs.listentogospel.data.SavedSession
import njs.listentogospel.model.BibleChapter
import njs.listentogospel.model.Gospel

data class UiState(
    val selectedGospel: Gospel? = null,
    val currentChapter: BibleChapter? = null,
    val isPlaying: Boolean = false,
    val positionMs: Int = 0,
    val durationMs: Int = 0,
    val sleepTimerRemainingSeconds: Int = 0,
    val savedSession: SavedSession? = null,
    val showResumeOffer: Boolean = false
)

class BiblePlayerViewModel(application: Application) : AndroidViewModel(application) {

    private val audioPlayer = (application as ListenToGospelApp).audioPlayer
    private val persistence = PlaybackPersistence(application)
    private var sleepTimer: CountDownTimer? = null

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        val saved = persistence.load()
        if (saved != null) {
            _uiState.update { it.copy(savedSession = saved, showResumeOffer = true) }
        }

        viewModelScope.launch {
            audioPlayer.state.collectLatest { audioState ->
                _uiState.update {
                    it.copy(
                        currentChapter = audioState.currentChapter,
                        isPlaying = audioState.isPlaying,
                        positionMs = audioState.positionMs,
                        durationMs = audioState.durationMs
                    )
                }
                if (audioState.chapterJustCompleted) {
                    audioPlayer.ackChapterCompleted()
                    playNextChapter()
                }
            }
        }
    }

    fun selectGospel(gospel: Gospel) {
        _uiState.update { it.copy(selectedGospel = gospel) }
    }

    fun clearGospelSelection() {
        _uiState.update { it.copy(selectedGospel = null) }
    }

    fun playChapter(chapter: BibleChapter, startMs: Int = 0) {
        if (_uiState.value.isPlaying) saveCurrentPosition()
        audioPlayer.play(chapter, startMs)
        _uiState.update { it.copy(showResumeOffer = false, savedSession = null) }
    }

    fun stop() {
        saveCurrentPosition()
        audioPlayer.stop()
        cancelSleepTimer()
    }

    fun resumeLastSession() {
        val saved = _uiState.value.savedSession ?: return
        playChapter(
            BibleChapter(saved.gospel, saved.chapterNumber),
            (saved.elapsedSeconds * 1000).toInt()
        )
    }

    fun dismissResumeOffer() {
        _uiState.update { it.copy(showResumeOffer = false, savedSession = null) }
        persistence.clear()
    }

    fun setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        if (minutes <= 0) return
        val totalMs = minutes * 60 * 1000L
        sleepTimer = object : CountDownTimer(totalMs, 1000L) {
            override fun onTick(remaining: Long) {
                _uiState.update { it.copy(sleepTimerRemainingSeconds = (remaining / 1000).toInt()) }
            }
            override fun onFinish() {
                stop()
                _uiState.update { it.copy(sleepTimerRemainingSeconds = 0) }
            }
        }.start()
        _uiState.update { it.copy(sleepTimerRemainingSeconds = minutes * 60) }
    }

    fun cancelSleepTimer() {
        sleepTimer?.cancel()
        sleepTimer = null
        _uiState.update { it.copy(sleepTimerRemainingSeconds = 0) }
    }

    private fun playNextChapter() {
        val current = _uiState.value.currentChapter ?: return
        val next = current.number + 1
        if (next <= current.gospel.chapterCount) {
            playChapter(BibleChapter(current.gospel, next))
        } else {
            persistence.clear()
        }
    }

    private fun saveCurrentPosition() {
        val chapter = _uiState.value.currentChapter ?: return
        val posMs = audioPlayer.getCurrentPositionMs()
        persistence.save(chapter.gospel, chapter.number, posMs / 1000.0)
    }

    override fun onCleared() {
        cancelSleepTimer()
        saveCurrentPosition()
        super.onCleared()
    }
}
