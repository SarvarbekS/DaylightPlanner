import SwiftUI

private let aiColors: [Color] = [
    .dlAccent, Color(hex: 0x7BA3D6), Color(hex: 0x7CC4A0),
    Color(hex: 0xE8A07C), Color(hex: 0xD9788A), .dlAccent
]

// MARK: - Card shown while parsing
struct ThinkingCard: View {
    private let phrases = [
        "Reading your sentence",
        "Finding the date and time",
        "Weighing how important it is",
        "Placing it on your calendar"
    ]

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let cycle = t / 1.6
            let idx = Int(cycle) % phrases.count
            let p = cycle.truncatingRemainder(dividingBy: 1)
            let fade = min(1, min(p, 1 - p) * 6)

            HStack(spacing: 14) {
                SparkleOrb(t: t)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ShimmerText(text: "DaylightAI is thinking", t: t)
                        ThinkingDots(t: t)
                    }
                    Text(phrases[idx])
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dlMuted)
                        .opacity(fade)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
        }
    }
}

// MARK: - Glowing orb with sparkles
struct SparkleOrb: View {
    let t: Double

    var body: some View {
        let grad = AngularGradient(colors: aiColors, center: .center, angle: .degrees(t * 120))
        ZStack {
            Circle().fill(grad).frame(width: 40, height: 40)
                .blur(radius: 9).opacity(0.65)
            Circle().fill(grad).frame(width: 34, height: 34)
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(1 + 0.14 * sin(t * 4))
                .rotationEffect(.degrees(sin(t * 2) * 8))
        }
        .frame(width: 46, height: 46)
    }
}

// MARK: - Text with a light sweep
struct ShimmerText: View {
    let text: String
    let t: Double
    private let font = Font.system(size: 15, weight: .semibold)

    var body: some View {
        let phase = CGFloat((t * 0.6).truncatingRemainder(dividingBy: 1))
        Text(text)
            .font(font)
            .foregroundStyle(Color.dlText.opacity(0.4))
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(colors: [.clear, .dlAccent, .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.7)
                        .offset(x: -w * 0.7 + phase * w * 1.7)
                }
                .mask(Text(text).font(font))
            }
    }
}

// MARK: - Three bouncing dots
struct ThinkingDots: View {
    let t: Double

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                let v = (sin(t * 5 - Double(i) * 0.9) + 1) / 2
                Circle()
                    .fill(Color.dlAccent)
                    .frame(width: 4, height: 4)
                    .opacity(0.3 + 0.7 * v)
                    .offset(y: -2 * v)
            }
        }
        .padding(.top, 5)
    }
}

// MARK: - Animated gradient border for the input box
struct AIGlowBorder: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let grad = AngularGradient(colors: aiColors, center: .center, angle: .degrees(t * 140))
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(grad, lineWidth: 3)
                    .blur(radius: 7)
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(grad, lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
