import SwiftUI

struct CatOverlayView: View {
    @ObservedObject var state: BreakOverlayState
    @ObservedObject var languageManager = LanguageManager.shared

    private var fixedOverlayOpacity: Double {
        isDarkMode ? 0.8 : 0.75
    }

    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private var isLastTenSeconds: Bool {
        state.remainingSeconds <= 10 && state.remainingSeconds > 0
    }

    private static let cachedBackgroundImage: NSImage? = {
        if let path = Bundle.main.path(forResource: "catbreak", ofType: "jpg") {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }()

    var body: some View {
        ZStack {
            if let nsImage = Self.cachedBackgroundImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: isDarkMode ? [
                        Color(red: 0.02, green: 0.02, blue: 0.05),
                        Color(red: 0.04, green: 0.04, blue: 0.08),
                        Color(red: 0.03, green: 0.05, blue: 0.07)
                    ] : [
                        Color(red: 0.05, green: 0.08, blue: 0.18),
                        Color(red: 0.08, green: 0.12, blue: 0.25),
                        Color(red: 0.06, green: 0.15, blue: 0.22)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            Color.black
                .opacity(fixedOverlayOpacity)
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.04),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 100,
                        endRadius: 500
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -60, y: -200)

            VStack(spacing: 20) {
                Spacer()

                if state.breakCount > 1 {
                    Text(String(format: L10n.tr("break.nth_time"), state.breakCount))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }

                Image(systemName: "cat.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.7))

                Text("「\(state.quote)」")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 48)

                Text(isLastTenSeconds ? L10n.tr("break.ending_soon") : L10n.tr("break.title"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(isLastTenSeconds ? .yellow.opacity(0.9) : .white.opacity(0.8))

                Spacer()

                VStack(spacing: 8) {
                    Text(L10n.tr("break.countdown"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(isLastTenSeconds ? .yellow.opacity(0.6) : .white.opacity(0.4))

                    Text(formatTime(state.remainingSeconds))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(isLastTenSeconds ? .yellow : .white.opacity(0.7))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isLastTenSeconds ? Color.yellow.opacity(0.15) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(isLastTenSeconds ? Color.yellow.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }

                Spacer()

                Text(isLastTenSeconds ? L10n.tr("break.ending_hint") : L10n.tr("break.hint"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(isLastTenSeconds ? .yellow.opacity(0.5) : .white.opacity(0.35))
                    .padding(.bottom, 30)
            }
            .padding(44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}