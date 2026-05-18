//
//  GospelHeaderGlassBar.swift
//  ListenToGospel
//

import SwiftUI

/// Floating Liquid Glass bar: gospel title (visual only), sleep timer control.
struct GospelHeaderGlassBar<SleepTimerLabel: View>: View {
    let barHeight: CGFloat
    let gospelName: String
    let chapterCount: Int
    let onSleepTimerTap: () -> Void
    let sleepTimerAccessibilityValue: String
    let sleepTimerAccessibilityUpdatesFrequently: Bool
    var sleepTimerFocus: AccessibilityFocusState<VoiceOverNavigation.Focus?>.Binding
    var controlsRotor: Namespace.ID
    @ViewBuilder var sleepTimerLabel: () -> SleepTimerLabel

    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = AppControlLayout.barHorizontalPadding

    init(
        barHeight: CGFloat = AppControlLayout.barHeight,
        gospelName: String,
        chapterCount: Int,
        onSleepTimerTap: @escaping () -> Void,
        sleepTimerAccessibilityValue: String,
        sleepTimerAccessibilityUpdatesFrequently: Bool = false,
        sleepTimerFocus: AccessibilityFocusState<VoiceOverNavigation.Focus?>.Binding,
        controlsRotor: Namespace.ID,
        @ViewBuilder sleepTimerLabel: @escaping () -> SleepTimerLabel
    ) {
        self.barHeight = barHeight
        self.gospelName = gospelName
        self.chapterCount = chapterCount
        self.onSleepTimerTap = onSleepTimerTap
        self.sleepTimerAccessibilityValue = sleepTimerAccessibilityValue
        self.sleepTimerAccessibilityUpdatesFrequently = sleepTimerAccessibilityUpdatesFrequently
        self.sleepTimerFocus = sleepTimerFocus
        self.controlsRotor = controlsRotor
        self.sleepTimerLabel = sleepTimerLabel
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(gospelName)
                .font(AppControlTypography.labelFont)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)

            sleepTimerButton
        }
        .frame(height: barHeight)
        .modifier(GlassCapsuleSurfaceModifier(
            horizontalPadding: horizontalPadding,
            cornerRadius: AppControlLayout.barCornerRadius
        ))
    }

    private var sleepTimerButton: some View {
        Button(action: onSleepTimerTap) {
            Label {
                sleepTimerLabel()
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } icon: {
                Image(systemName: "timer")
                    .accessibilityHidden(true)
            }
            .font(AppControlTypography.labelFont)
            .labelStyle(.titleAndIcon)
        }
        .modifier(SleepTimerGlassButtonStyle())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VoiceOverNavigation.sleepTimerButtonAccessibilityLabel)
        .accessibilityValue(sleepTimerAccessibilityValue)
        .accessibilityAddTraits(sleepTimerAccessibilityUpdatesFrequently ? .updatesFrequently : [])
        .accessibilityInputLabels(VoiceControlLabels.sleepTimer)
        .accessibilityHint("두 번 탭하여 수면 타이머 시간을 선택합니다")
        .accessibilityIdentifier("sleep-timer-button")
        .accessibilityFocused(sleepTimerFocus, equals: .sleepTimer)
        .accessibilityRotorEntry(id: VoiceOverNavigation.Focus.sleepTimer, in: controlsRotor)
    }
}

// MARK: - Glass capsule surface

struct GlassCapsuleSurfaceModifier: ViewModifier {
    let horizontalPadding: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(.horizontal, horizontalPadding)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .padding(.horizontal, horizontalPadding)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(.white.opacity(0.32), lineWidth: 0.75)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 14, y: 5)
                }
        }
    }
}

private struct SleepTimerGlassButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            content
                .buttonStyle(.bordered)
                .controlSize(.regular)
        }
    }
}
