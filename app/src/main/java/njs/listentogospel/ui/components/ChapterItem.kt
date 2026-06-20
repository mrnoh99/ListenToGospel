package njs.listentogospel.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import njs.listentogospel.model.BibleChapter
import njs.listentogospel.model.Gospel

@Composable
fun ChapterList(
    gospel: Gospel,
    currentChapter: BibleChapter?,
    isPlaying: Boolean,
    positionMs: Int,
    durationMs: Int,
    onChapterClick: (BibleChapter) -> Unit,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()

    LaunchedEffect(currentChapter) {
        if (currentChapter?.gospel == gospel) {
            listState.animateScrollToItem((currentChapter.number - 1).coerceAtLeast(0))
        }
    }

    LazyColumn(state = listState, modifier = modifier) {
        items(gospel.chapters) { chapter ->
            val isActive = currentChapter == chapter
            ChapterRow(
                chapter = chapter,
                isActive = isActive,
                isPlaying = isPlaying && isActive,
                progress = if (isActive && durationMs > 0) positionMs.toFloat() / durationMs else 0f,
                onClick = { onChapterClick(chapter) }
            )
            HorizontalDivider(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                thickness = 0.5.dp
            )
        }
    }
}

@Composable
private fun ChapterRow(
    chapter: BibleChapter,
    isActive: Boolean,
    isPlaying: Boolean,
    progress: Float,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                if (isActive) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
                else MaterialTheme.colorScheme.background
            )
            .clickable { onClick() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "${chapter.number}장",
                style = MaterialTheme.typography.bodyLarge,
                color = if (isActive) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.weight(1f)
            )
            if (isPlaying) {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
        if (isActive && progress > 0f) {
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(2.dp),
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant
            )
        }
    }
}
