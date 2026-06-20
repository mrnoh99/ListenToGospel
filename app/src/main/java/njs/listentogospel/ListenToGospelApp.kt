package njs.listentogospel

import android.app.Application
import njs.listentogospel.audio.AudioPlayer

class ListenToGospelApp : Application() {
    val audioPlayer: AudioPlayer by lazy { AudioPlayer(this) }
}
