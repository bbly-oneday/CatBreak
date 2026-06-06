import SwiftUI

struct CatOverlayView: View {
    let remainingSeconds: Int

    @State private var catOffset: CGFloat = 1000
    @State private var catOpacity: Double = 0
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background
            Color.orange.opacity(0.95)
                .ignoresSafeArea()

            // Cat content
            VStack(spacing: 24) {
                Spacer()

                // Cat emoji or image
                Image(systemName: "cat.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                Text("Time for a break!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("Your furry supervisor says:")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))

                Text("\"Put the keyboard down\nand stretch a little!\"")
                    .font(.title2)
                    .italic()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer()

                // Countdown
                VStack(spacing: 8) {
                    Text("Break ends in")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(16)
                }

                Spacer()

                Text("🐾 Stretch your arms · Look away from the screen · Take a breath")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
            .padding(40)
        }
        .offset(x: catOffset)
        .opacity(catOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                catOffset = 0
                catOpacity = 1
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
