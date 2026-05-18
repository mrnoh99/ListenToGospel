//
//  PlaybackGlassMenu.swift
//  ListenToGospel
//

import SwiftUI

/// Apple Music–style Liquid Glass playback bar: play/stop.
struct PlaybackGlassMenu: View {
    let barHeight: CGFloat
    let chapterTitle: String
    let isPlaying: Bool
    let onPlayStop: () -> Void

    @ScaledMetric(relativeTo: .body) private var menuHorizontalPadding: CGFloat = AppControlLayout.barHorizontalPadding

    init(
        barHeight: CGFloat = AppControlLayout.barHeight,
        chapterTitle: String,
        isPlaying: Bool,
        onPlayStop: @escaping () -> Void
    ) {
        self.barHeight = barHeight
        self.chapterTitle = chapterTitle
        self.isPlaying = isPlaying
        self.onPlayStop = onPlayStop
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    menuButtons
                }
                .padding(.horizontal, menuHorizontalPadding)
                .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                menuButtons
                    .padding(.horizontal, menuHorizontalPadding)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(.white.opacity(0.32), lineWidth: 0.75)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                    }
            }
        }
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
    }

    private var menuButtons: some View {
        Button(action: onPlayStop) {
            Label {
                Text(chapterTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } icon: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
            }
            .font(AppControlTypography.labelFont)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .modifier(MainPlayGlassStyle())
        .accessibilityIdentifier("playback-button")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Button styles

private struct MainPlayGlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .tint(Color.accentColor)
        } else {
            content
                .foregroundStyle(Color.accentColor)
        }
    }
}

