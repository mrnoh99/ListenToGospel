//
//  PlaybackGlassMenu.swift
//  ListenToGospel
//

import SwiftUI

/// Apple Music–style Liquid Glass playback bar: previous · play/stop · next.
struct PlaybackGlassMenu: View {
    let barHeight: CGFloat
    let chapterTitle: String
    let isPlaying: Bool
    let transportEnabled: Bool
    let onPlayStop: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @ScaledMetric(relativeTo: .body) private var menuHorizontalPadding: CGFloat = AppControlLayout.barHorizontalPadding
    @ScaledMetric(relativeTo: .body) private var transportButtonSize: CGFloat = 36

    init(
        barHeight: CGFloat = AppControlLayout.barHeight,
        chapterTitle: String,
        isPlaying: Bool,
        transportEnabled: Bool,
        onPlayStop: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.barHeight = barHeight
        self.chapterTitle = chapterTitle
        self.isPlaying = isPlaying
        self.transportEnabled = transportEnabled
        self.onPlayStop = onPlayStop
        self.onPrevious = onPrevious
        self.onNext = onNext
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
        HStack(spacing: 12) {
            transportButton(
                icon: "backward.fill",
                identifier: "skip-previous-button",
                action: onPrevious
            )

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

            transportButton(
                icon: "forward.fill",
                identifier: "skip-next-button",
                action: onNext
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func transportButton(
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(AppControlTypography.labelFont)
                .frame(width: transportButtonSize, height: transportButtonSize)
                .contentShape(Rectangle())
        }
        .modifier(SideTransportGlassStyle())
        .disabled(!transportEnabled)
        .opacity(transportEnabled ? 1 : 0.35)
        .accessibilityIdentifier(identifier)
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

private struct SideTransportGlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content.buttonStyle(LegacySideTransportGlassButtonStyle())
        }
    }
}

private struct LegacySideTransportGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background {
                Circle()
                    .fill(.thinMaterial)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.28), lineWidth: 0.75)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}
