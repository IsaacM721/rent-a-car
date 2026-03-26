//
//  LaunchScreenView.swift
//  rent-a-car
//

import SwiftUI

struct LaunchScreenView: View {
    let fullText = "MOTORES.DO"
    
    @State private var revealedCount = 0
    @State private var bounceOffsets: [CGFloat] = Array(repeating: 0, count: 10)
    @State private var cursorVisible = true
    @State private var isTypewriterDone = false
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity: CGFloat = 1.0

    private let letterColors: [Color] = [
        .white, .white, .white, .white, .white, .white,
        Color(red: 1.0, green: 0.85, blue: 0.0), // "."
        Color(red: 1.0, green: 0.85, blue: 0.0), // "D"
        Color(red: 1.0, green: 0.85, blue: 0.0), // "O"
        .white
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Letter row
                HStack(spacing: 2) {
                    ForEach(0..<fullText.count, id: \.self) { i in
                        let char = String(fullText[fullText.index(fullText.startIndex, offsetBy: i)])
                        Text(char)
                            .font(.custom("Helvetica-Bold", size: 42))
                            .foregroundColor(letterColors[i])
                            .offset(y: i < revealedCount ? bounceOffsets[i] : 30)
                            .opacity(i < revealedCount ? 1 : 0)
                            .scaleEffect(i < revealedCount ? 1 : 0.4)
                            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: revealedCount)
                            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: bounceOffsets[i])
                    }

                    // Blinking cursor
                    if !isTypewriterDone {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3, height: 44)
                            .opacity(cursorVisible ? 1 : 0)
                            .animation(.easeInOut(duration: 0.45).repeatForever(), value: cursorVisible)
                    }
                }

                // Subtle tagline
                if isTypewriterDone {
                    Text("rent. drive. go.")
                        .font(.custom("Helvetica", size: 13))
                        .foregroundColor(.white.opacity(0.45))
                        .kerning(4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.top, 12)
                }
            }
            .scaleEffect(exitScale)
            .opacity(exitOpacity)
        }
        .onAppear {
            startCursorBlink()
            typeNextLetter()
        }
    }

    // MARK: - Animation helpers

    private func startCursorBlink() {
        cursorVisible = false
    }

    private func typeNextLetter() {
        guard revealedCount < fullText.count else {
            finishTypewriter()
            return
        }

        let delay = Double(revealedCount) * 0.09
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            revealedCount += 1
            bounceLetter(at: revealedCount - 1)
            typeNextLetter()
        }
    }

    private func bounceLetter(at index: Int) {
        // Kick letter up then settle to 0
        bounceOffsets[index] = -18
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            bounceOffsets[index] = 0
        }
    }

    private func finishTypewriter() {
        withAnimation(.easeIn(duration: 0.3)) {
            isTypewriterDone = true
        }
        cursorVisible = false

        // Wave bounce after reveal
        for i in 0..<fullText.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) {
                bounceOffsets[i] = -14
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    bounceOffsets[i] = 0
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
