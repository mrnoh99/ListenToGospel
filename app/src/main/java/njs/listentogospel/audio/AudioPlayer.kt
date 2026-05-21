package njs.listentogospel.audio

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import njs.listentogospel.model.BibleChapter
import njs.listentogospel.service.PlaybackService

data class AudioState(
    val currentChapter: BibleChapter? = null,
    val isPlaying: Boolean = false,
    val positionMs: Int = 0,
    val durationMs: Int = 0,
    val chapterJustCompleted: Boolean = false
)

class AudioPlayer(private val context: Context) {

    private var mediaPlayer: MediaPlayer? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var positionJob: Job? = null
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null

    private val _state = MutableStateFlow(AudioState())
    val state: StateFlow<AudioState> = _state.asStateFlow()

    fun play(chapter: BibleChapter, startMs: Int = 0) {
        releasePlayer()
        requestAudioFocus()

        try {
            val afd = context.assets.openFd(chapter.assetPath)
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                prepare()
                if (startMs > 0) seekTo(startMs)
                setOnCompletionListener { handleCompletion() }
                start()
            }
            _state.update {
                it.copy(
                    currentChapter = chapter,
                    isPlaying = true,
                    durationMs = mediaPlayer!!.duration,
                    positionMs = startMs,
                    chapterJustCompleted = false
                )
            }
            startPositionPolling()
            startForegroundService(chapter)
        } catch (e: Exception) {
            _state.update { it.copy(isPlaying = false) }
        }
    }

    fun stop() {
        val posMs = mediaPlayer?.currentPosition ?: 0
        releasePlayer()
        _state.update { it.copy(isPlaying = false, positionMs = posMs) }
        stopForegroundService()
        abandonAudioFocus()
    }

    fun getCurrentPositionMs(): Int = mediaPlayer?.currentPosition ?: _state.value.positionMs

    fun ackChapterCompleted() {
        _state.update { it.copy(chapterJustCompleted = false) }
    }

    private fun handleCompletion() {
        releasePlayer()
        _state.update { it.copy(isPlaying = false, chapterJustCompleted = true) }
        stopForegroundService()
    }

    private fun startPositionPolling() {
        positionJob?.cancel()
        positionJob = scope.launch {
            while (_state.value.isPlaying) {
                mediaPlayer?.currentPosition?.let { pos ->
                    _state.update { it.copy(positionMs = pos) }
                }
                delay(500)
            }
        }
    }

    private fun releasePlayer() {
        positionJob?.cancel()
        mediaPlayer?.release()
        mediaPlayer = null
    }

    private fun startForegroundService(chapter: BibleChapter) {
        val intent = Intent(context, PlaybackService::class.java).apply {
            putExtra(PlaybackService.EXTRA_CHAPTER_TITLE, chapter.title)
        }
        context.startForegroundService(intent)
    }

    private fun stopForegroundService() {
        context.stopService(Intent(context, PlaybackService::class.java))
    }

    private fun requestAudioFocus() {
        val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            setOnAudioFocusChangeListener { focusChange ->
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_LOSS -> stop()
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> mediaPlayer?.pause()
                    AudioManager.AUDIOFOCUS_GAIN -> if (_state.value.isPlaying) mediaPlayer?.start()
                }
            }
        }.build()
        audioManager.requestAudioFocus(req)
        audioFocusRequest = req
    }

    private fun abandonAudioFocus() {
        audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        audioFocusRequest = null
    }
}
