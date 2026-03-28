import SwiftUI

struct OnboardingView: View {
    let onComplete: (SpriteType) -> Void

    @State private var selectedType: SpriteType = .dog

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Your Pet!")
                .font(.system(size: 24, weight: .bold))

            Text("Pick a companion to live on your desktop")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SpriteType.allCases) { type in
                    PetPreviewCard(type: type, isSelected: selectedType == type)
                        .onTapGesture {
                            selectedType = type
                        }
                }
            }
            .padding(.horizontal, 4)

            Button(action: {
                onComplete(selectedType)
            }) {
                Text("Let's Go!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 520, height: 560)
    }
}

struct PetPreviewCard: View {
    let type: SpriteType
    let isSelected: Bool

    @State private var frameIndex = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: previewImage)
                .interpolation(.none)
                .resizable()
                .frame(width: 56, height: 56)

            Text(type.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var previewImage: NSImage {
        let set = PetSprites.spriteSet(for: type)
        let frames = set.idle
        let frame = frames[frameIndex % frames.count]
        return PetSprites.imageFromPixelArt(frame, colorMap: set.colorMap)
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let set = PetSprites.spriteSet(for: type)
            frameIndex = (frameIndex + 1) % set.idle.count
        }
    }
}
