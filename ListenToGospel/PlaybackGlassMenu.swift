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
        menuButtons
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .modifier(GlassCapsuleSurfaceModifier(
                horizontalPadding: menuHorizontalPadding,
                cornerRadius: AppControlLayout.barCornerRadius
            ))
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
            .font(AppControlTypography.prominentLabelFont)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isPlaying ? "정지" : "재생")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("playback-button")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

