package njs.listentogospel.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import njs.listentogospel.model.Gospel
import njs.listentogospel.ui.components.ChapterList
import njs.listentogospel.ui.components.GospelGrid
import njs.listentogospel.ui.components.PlaybackBar
import njs.listentogospel.ui.components.ResumeOfferBanner
import njs.listentogospel.ui.components.SleepTimerSheet
import njs.listentogospel.viewmodel.BiblePlayerViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(viewModel: BiblePlayerViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showSleepTimerSheet by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = uiState.selectedGospel?.koreanName ?: "복음서듣기",
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    if (uiState.selectedGospel != null) {
                        IconButton(onClick = { viewModel.clearGospelSelection() }) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "뒤로"
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.primary
                )
            )
        },
        bottomBar = {
            val chapter = uiState.currentChapter
            if (chapter != null) {
                PlaybackBar(
                    chapter = chapter,
                    isPlaying = uiState.isPlaying,
                    positionMs = uiState.positionMs,
                    durationMs = uiState.durationMs,
                    sleepTimerRemaining = uiState.sleepTimerRemainingSeconds,
                    onPlayStop = {
                        if (uiState.isPlaying) viewModel.stop()
                        else viewModel.playChapter(chapter)
                    },
                    onSleepTimer = { showSleepTimerSheet = true }
                )
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .padding(paddingValues)
                .fillMaxSize()
        ) {
            if (uiState.selectedGospel == null) {
                GospelGrid(
                    gospels = Gospel.values(),
                    onSelect = { viewModel.selectGospel(it) },
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                ChapterList(
                    gospel = uiState.selectedGospel!!,
                    currentChapter = uiState.currentChapter,
                    isPlaying = uiState.isPlaying,
                    positionMs = uiState.positionMs,
                    durationMs = uiState.durationMs,
                    onChapterClick = { chapter -> viewModel.playChapter(chapter) },
                    modifier = Modifier.fillMaxSize()
                )
            }

            if (uiState.showResumeOffer && uiState.savedSession != null) {
                ResumeOfferBanner(
                    session = uiState.savedSession!!,
                    onResume = { viewModel.resumeLastSession() },
                    onDismiss = { viewModel.dismissResumeOffer() },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp)
                )
            }
        }
    }

    if (showSleepTimerSheet) {
        SleepTimerSheet(
            currentRemaining = uiState.sleepTimerRemainingSeconds,
            onSelect = { minutes ->
                if (minutes == 0) viewModel.cancelSleepTimer()
                else viewModel.setSleepTimer(minutes)
                showSleepTimerSheet = false
            },
            onDismiss = { showSleepTimerSheet = false }
        )
    }
}
