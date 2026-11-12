import SwiftUI

enum MascotMood { case happy, proud, stern, smug, furious, thinking }

struct CurveLine: Shape {
    var curve: CGFloat
    var skew: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY + skew * rect.height),
                       control: CGPoint(x: rect.midX, y: rect.midY + curve * rect.height * 2))
        return p
    }
}

struct DaylightMascot: View {
    let mood: MascotMood
    var size: CGFloat = 92

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private let dark = Color(hex: 0x3B2A1E)

    private var palette: (inner: Color, outer: Color, ray: Color) {
        switch mood {
        case .furious:  return (Color(hex: 0xFFB36B), Color(hex: 0xE5533D), Color(hex: 0xF0703C))
        case .stern:    return (Color(hex: 0xFFD27A), Color(hex: 0xE8963A), Color(hex: 0xF0A93F))
        case .smug:     return (Color(hex: 0xFFE08A), Color(hex: 0xEFA93F), Color(hex: 0xF4BD4E))
        case .proud:    return (Color(hex: 0xFFE9A0), Color(hex: 0xF5B83D), Color(hex: 0xFFC94D))
        case .thinking: return (Color(hex: 0xFFE9A0), Color(hex: 0xF2B84B), Color(hex: 0xFFD166))
        case .happy:    return (Color(hex: 0xFFE9A0), Color(hex: 0xF7B731), Color(hex: 0xFFCB45))
        }
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: !isVisible || scenePhase != .active || reduceMotion
        )) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            let shake = mood == .furious ? sin(t * 45) * size * 0.012 : 0
            ZStack {
                rays(t)
                face(t)
            }
            .frame(width: size, height: size)
            .offset(x: shake, y: sin(t * 2.2) * size * 0.035)
            .rotationEffect(.degrees(mood == .smug ? sin(t * 1.4) * 4 : 0))
        }
        .frame(width: size, height: size)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func rays(_ t: Double) -> some View {
        let n = 12
        let pulse = mood == .furious ? 1 + 0.12 * sin(t * 12) : 1 + 0.05 * sin(t * 2)
        let speed: Double = mood == .furious ? 40 : 14
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                Capsule()
                    .fill(palette.ray)
                    .frame(width: size * 0.07, height: size * 0.17 * pulse)
                    .offset(y: -size * 0.40)
                    .rotationEffect(.degrees(Double(i) / Double(n) * 360 + t * speed))
            }
        }
    }

    private func face(_ t: Double) -> some View {
        let s = size
        let blink: CGFloat = t.truncatingRemainder(dividingBy: 4.0) > 3.88 ? 0.12 : 1
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [palette.inner, palette.outer],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: s * 0.38))
                .frame(width: s * 0.62, height: s * 0.62)
                .shadow(color: palette.outer.opacity(0.45), radius: s * 0.08, y: s * 0.02)

            if mood == .happy || mood == .proud {
                Circle().fill(Color(hex: 0xFF8FA3).opacity(0.4))
                    .frame(width: s * 0.09, height: s * 0.09).offset(x: -s * 0.17, y: s * 0.06)
                Circle().fill(Color(hex: 0xFF8FA3).opacity(0.4))
                    .frame(width: s * 0.09, height: s * 0.09).offset(x: s * 0.17, y: s * 0.06)
            }

            HStack(spacing: s * 0.10) {
                eye(blink)
                eye(blink)
            }
            .offset(y: -s * 0.035)

            brows
            mouth
        }
    }

    @ViewBuilder private func eye(_ blink: CGFloat) -> some View {
        let s = size
        switch mood {
        case .proud:
            CurveLine(curve: -0.55)
                .stroke(dark, style: StrokeStyle(lineWidth: s * 0.024, lineCap: .round))
                .frame(width: s * 0.075, height: s * 0.05)
        case .smug:
            Capsule().fill(dark).frame(width: s * 0.08, height: s * 0.035)
        case .thinking:
            Ellipse().fill(dark).frame(width: s * 0.07, height: s * 0.10 * blink)
                .offset(x: s * 0.012, y: -s * 0.012)
        default:
            Ellipse().fill(dark).frame(width: s * 0.07, height: s * 0.10 * blink)
        }
    }

    @ViewBuilder private var brows: some View {
        switch mood {
        case .stern:   browPair(left: 12, right: -12, raiseRight: 0)
        case .furious: browPair(left: 24, right: -24, raiseRight: 0)
        case .smug:    browPair(left: 8, right: -16, raiseRight: -size * 0.02)
        default:       EmptyView()
        }
    }

    private func browPair(left: Double, right: Double, raiseRight: CGFloat) -> some View {
        let s = size
        return HStack(spacing: s * 0.075) {
            RoundedRectangle(cornerRadius: s * 0.012).fill(dark)
                .frame(width: s * 0.10, height: s * 0.022)
                .rotationEffect(.degrees(left))
            RoundedRectangle(cornerRadius: s * 0.012).fill(dark)
                .frame(width: s * 0.10, height: s * 0.022)
                .rotationEffect(.degrees(right))
                .offset(y: raiseRight)
        }
        .offset(y: -s * 0.115)
    }

    @ViewBuilder private var mouth: some View {
        let s = size
        let style = StrokeStyle(lineWidth: s * 0.026, lineCap: .round)
        switch mood {
        case .thinking:
            Ellipse().stroke(dark, lineWidth: s * 0.02)
                .frame(width: s * 0.05, height: s * 0.06).offset(y: s * 0.12)
        case .stern:
            CurveLine(curve: 0).stroke(dark, style: style)
                .frame(width: s * 0.13, height: s * 0.04).offset(y: s * 0.12)
        case .smug:
            CurveLine(curve: 0.28, skew: -0.45).stroke(dark, style: style)
                .frame(width: s * 0.15, height: s * 0.06).offset(y: s * 0.12)
        case .furious:
            CurveLine(curve: -0.5).stroke(dark, style: style)
                .frame(width: s * 0.16, height: s * 0.06).offset(y: s * 0.13)
        case .proud:
            CurveLine(curve: 0.75).stroke(dark, style: style)
                .frame(width: s * 0.20, height: s * 0.08).offset(y: s * 0.105)
        case .happy:
            CurveLine(curve: 0.6).stroke(dark, style: style)
                .frame(width: s * 0.18, height: s * 0.07).offset(y: s * 0.11)
        }
    }
}

// MARK: - Speech bubble
struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct TypewriterText: View {
    let text: String

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedText = ""

    private struct PlaybackKey: Equatable {
        let text: String
        let animate: Bool
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text)
                .hidden()
                .accessibilityHidden(true)
            Text(displayedText)
                .accessibilityHidden(true)
        }
        .font(.system(size: 13, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .task(id: PlaybackKey(
            text: text,
            animate: !reduceMotion && scenePhase == .active
        )) {
            guard !reduceMotion, scenePhase == .active else {
                displayedText = text
                return
            }

            // Do not restart a completed message on foregrounding.
            guard displayedText != text else { return }
            displayedText = ""

            for character in text {
                do {
                    try await Task.sleep(for: .milliseconds(20))
                    try Task.checkCancellation()
                } catch {
                    return
                }
                displayedText.append(character)
            }
        }
    }
}

struct CoachBubble: View {
    let text: String
    let thinking: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 0) {
            BubbleTail().fill(Color.white).frame(width: 10, height: 16)
            Group {
                if thinking && reduceMotion {
                    Text("Daylight is thinking…")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if thinking {
                    TimelineView(.animation(
                        minimumInterval: 1.0 / 20.0,
                        paused: !isVisible || scenePhase != .active
                    )) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        HStack(spacing: 6) {
                            ShimmerText(text: "Daylight is sizing you up", t: t)
                            ThinkingDots(t: t)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    TypewriterText(text: text)
                }
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}
