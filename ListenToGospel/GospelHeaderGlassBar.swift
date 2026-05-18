//
//  GospelHeaderGlassBar.swift
//  ListenToGospel
//

import SwiftUI

/// Floating Liquid Glass bar: gospel title and sleep timer control.
struct GospelHeaderGlassBar<SleepTimerLabel: View>: View {
    let barHeight: CGFloat
    let gospelName: String
    let onSleepTimerTap: () -> Void
    @ViewBuilder var sleepTimerLabel: () -> SleepTimerLabel

    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = AppControlLayout.barHorizontalPadding

    init(
        barHeight: CGFloat = AppControlLayout.barHeight,
        gospelName: String,
        onSleepTimerTap: @escaping () -> Void,
        @ViewBuilder sleepTimerLabel: @escaping () -> SleepTimerLabel
    ) {
        self.barHeight = barHeight
        self.gospelName = gospelName
        self.onSleepTimerTap = onSleepTimerTap
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

            Button(action: onSleepTimerTap) {
                Label {
                    sleepTimerLabel()
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } icon: {
                    Image(systemName: "timer")
                }
                .font(AppControlTypography.labelFont)
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("타이머")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("sleep-timer-button")
        }
        .frame(height: barHeight)
        .modifier(GlassCapsuleSurfaceModifier(
            horizontalPadding: horizontalPadding,
            cornerRadius: AppControlLayout.barCornerRadius
        ))
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
                .background {
                    Capsule(style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .capsule)
                }
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
