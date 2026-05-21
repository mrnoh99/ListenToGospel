package njs.listentogospel.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme = darkColorScheme(
    primary = GoldPrimary,
    onPrimary = NavyDark,
    primaryContainer = NavyLight,
    onPrimaryContainer = GoldLight,
    secondary = GoldLight,
    onSecondary = NavyDark,
    background = NavyDark,
    onBackground = CreamWhite,
    surface = SurfaceDark,
    onSurface = OnSurfaceDark,
    surfaceVariant = NavyMid,
    onSurfaceVariant = CreamWhite
)

@Composable
fun ListenToGospelTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
