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
    let playStopHint: String
    let onPlayStop: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    var controlsFocus: AccessibilityFocusState<VoiceOverNavigation.Focus?>.Binding
    let controlsRotor: Namespace.ID

    @ScaledMetric(relativeTo: .body) private var menuHorizontalPadding: CGFloat = AppControlLayout.barHorizontalPadding
    @ScaledMetric(relativeTo: .body) private var transportButtonSize: CGFloat = 36

    init(
        barHeight: CGFloat = AppControlLayout.barHeight,
        chapterTitle: String,
        isPlaying: Bool,
        transportEnabled: Bool,
        playStopHint: String,
        onPlayStop: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        controlsFocus: AccessibilityFocusState<VoiceOverNavigation.Focus?>.Binding,
        controlsRotor: Namespace.ID
    ) {
        self.barHeight = barHeight
        self.chapterTitle = chapterTitle
        self.isPlaying = isPlaying
        self.transportEnabled = transportEnabled
        self.playStopHint = playStopHint
        self.onPlayStop = onPlayStop
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.controlsFocus = controlsFocus
        self.controlsRotor = controlsRotor
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
        .accessibilityElement(children: .contain)
    }

    private var menuButtons: some View {
        HStack(spacing: 12) {
            transportButton(
                icon: "backward.fill",
                label: "이전 챕터",
                identifier: "skip-previous-button",
                focus: .skipPrevious,
                action: onPrevious
            )

            mainPlayStopButton

            transportButton(
                icon: "forward.fill",
                label: "다음 챕터",
                identifier: "skip-next-button",
                focus: .skipNext,
                action: onNext
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainPlayStopButton: some View {
        Button(action: onPlayStop) {
            Label {
                Text(chapterTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } icon: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .accessibilityHidden(true)
            }
            .font(AppControlTypography.labelFont)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .modifier(MainPlayGlassStyle())
        .accessibilityLabel(mainPlayStopAccessibilityLabel)
        .accessibilityHint(playStopHint)
        .accessibilityInputLabels(isPlaying ? VoiceControlLabels.playbackStop : VoiceControlLabels.playbackPlay)
        .accessibilityIdentifier("playback-button")
        .accessibilityFocused(controlsFocus, equals: .playStop)
        .accessibilityRotorEntry(id: VoiceOverNavigation.Focus.playStop, in: controlsRotor)
    }

    private var mainPlayStopAccessibilityLabel: String {
        let action = isPlaying ? "정지" : "재생"
        return "\(action), \(chapterTitle)"
    }

    private func transportButton(
        icon: String,
        label: String,
        identifier: String,
        focus: VoiceOverNavigation.Focus,
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
        .accessibilityLabel(label)
        .accessibilityHint(transportEnabled ? "두 번 탭하여 \(label)으로 이동합니다" : "")
        .accessibilityHidden(!transportEnabled)
        .accessibilityIdentifier(identifier)
        .accessibilityFocused(controlsFocus, equals: focus)
        .accessibilityRotorEntry(id: focus, in: controlsRotor)
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
