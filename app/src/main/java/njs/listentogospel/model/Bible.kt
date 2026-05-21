package njs.listentogospel.model

enum class Gospel(
    val koreanName: String,
    val shortName: String,
    val chapterCount: Int,
    val audioFolderName: String,
    val audioFilePrefix: String
) {
    MATTHEW("마태오복음서", "마태오", 28, "01.마태오복음", "마태오복음"),
    MARK("마르코복음서", "마르코", 16, "02.마르코복음", "마르코복음"),
    LUKE("루카복음서", "루카", 24, "03.루카복음", "루카복음"),
    JOHN("요한복음서", "요한", 21, "04.요한복음", "요한복음");

    val chapters: List<BibleChapter> by lazy {
        (1..chapterCount).map { BibleChapter(this, it) }
    }
}

data class BibleChapter(
    val gospel: Gospel,
    val number: Int
) {
    val title: String get() = "${gospel.koreanName} ${number}장"
    val shortTitle: String get() = "${gospel.shortName} ${number}장"

    // e.g. AudioFiles/01.마태오복음/마태오복음 01장.m4a
    val assetPath: String
        get() = "AudioFiles/${gospel.audioFolderName}/${gospel.audioFilePrefix} ${number.toString().padStart(2, '0')}장.m4a"
}
