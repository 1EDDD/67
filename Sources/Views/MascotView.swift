import SwiftUI

/// Lightweight vector fallback for the supplied 67 mascot mark.
struct MascotView: View {
    private let cyan = Color(red: 0.08, green: 0.67, blue: 0.94)
    private let deepBlue = Color(red: 0.02, green: 0.34, blue: 0.69)
    private let pale = Color(red: 0.88, green: 0.94, blue: 0.97)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 300, proxy.size.height / 150)
            ZStack {
                HStack(alignment: .center, spacing: 2) {
                    mascotSix
                    mascotSeven
                }
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.44)

                HStack(spacing: 82) {
                    hand
                    hand
                }
                .scaleEffect(scale * 0.8)
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("67 mascot")
    }

    private var mascotSix: some View {
        ZStack {
            Text("6")
                .font(.system(size: 124, weight: .black, design: .rounded))
                .foregroundStyle(cyan)
                .overlay {
                    Text("6")
                        .font(.system(size: 124, weight: .black, design: .rounded))
                        .foregroundStyle(.clear)
                        .overlay {
                            Text("6")
                                .font(.system(size: 124, weight: .black, design: .rounded))
                                .foregroundStyle(.clear)
                        }
                }
            eyes
                .offset(x: 4, y: -25)
            RoundedRectangle(cornerRadius: 4)
                .fill(pale)
                .frame(width: 28, height: 7)
                .offset(x: -4, y: 22)
        }
        .frame(width: 118, height: 130)
        .shadow(color: cyan.opacity(0.25), radius: 7, y: 3)
    }

    private var mascotSeven: some View {
        ZStack {
            Text("7")
                .font(.system(size: 124, weight: .black, design: .rounded))
                .foregroundStyle(cyan)
            eyes
                .offset(x: -7, y: -27)
            RoundedRectangle(cornerRadius: 4)
                .fill(pale)
                .frame(width: 26, height: 7)
                .offset(x: -8, y: 19)
        }
        .frame(width: 112, height: 130)
        .shadow(color: cyan.opacity(0.25), radius: 7, y: 3)
    }

    private var eyes: some View {
        HStack(spacing: 18) {
            eye
            eye
        }
    }

    private var eye: some View {
        Circle()
            .fill(.white)
            .frame(width: 19, height: 19)
            .overlay {
                Circle()
                    .fill(Color(red: 0.03, green: 0.08, blue: 0.15))
                    .frame(width: 11, height: 11)
            }
            .overlay(Circle().stroke(pale, lineWidth: 2))
    }

    private var hand: some View {
        HStack(spacing: 0) {
            Capsule().fill(pale).frame(width: 35, height: 12)
            Capsule().fill(pale).frame(width: 22, height: 8).rotationEffect(.degrees(-23)).offset(x: -13, y: -7)
            Capsule().fill(pale).frame(width: 22, height: 8).rotationEffect(.degrees(20)).offset(x: -25, y: 6)
        }
    }
}
