package njs.listentogospel.data

import android.content.Context
import njs.listentogospel.model.Gospel

data class SavedSession(
    val gospel: Gospel,
    val chapterNumber: Int,
    val elapsedSeconds: Double
)

class PlaybackPersistence(context: Context) {
    private val prefs = context.getSharedPreferences("playback_session", Context.MODE_PRIVATE)

    fun save(gospel: Gospel, chapterNumber: Int, elapsedSeconds: Double) {
        prefs.edit()
            .putInt("gospel_ordinal", gospel.ordinal)
            .putInt("chapter_number", chapterNumber)
            .putFloat("elapsed_seconds", elapsedSeconds.toFloat())
            .apply()
    }

    fun load(): SavedSession? {
        val ordinal = prefs.getInt("gospel_ordinal", -1)
        if (ordinal < 0 || ordinal >= Gospel.values().size) return null
        return SavedSession(
            gospel = Gospel.values()[ordinal],
            chapterNumber = prefs.getInt("chapter_number", 1),
            elapsedSeconds = prefs.getFloat("elapsed_seconds", 0f).toDouble()
        )
    }

    fun clear() = prefs.edit().clear().apply()
}
