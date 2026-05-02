import SwiftUI

struct LyricsView: View {
  let lyrics: [LyricLine]
  let currentTime: TimeInterval
  let onSeek: (TimeInterval) -> Void
  private var currentIndex: Int {
    guard !lyrics.isEmpty else { return -1 }
    var idx = -1
    for (i, line) in lyrics.enumerated() {
      if currentTime >= line.time { idx = i } else { break }
    }
    return idx
  }
  private var isIntro: Bool {
    guard let first = lyrics.first else { return false }
    return currentTime < first.time
  }
  var body: some View {
    if lyrics.isEmpty {
      VStack(spacing: 12) {
        LoadingIndicator(size: 48)
          .opacity(0.6)
        Text("Loading lyrics...")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 8) {
            Spacer().frame(height: 40)
            if let first = lyrics.first {
              IntroDots(isActive: isIntro, startTime: first.time, currentTime: currentTime)
                .id("intro-dots")
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .onTapGesture { onSeek(0) }
            }
            ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
              LyricLineRow(
                line: line,
                index: index,
                currentIndex: currentIndex,
                onSeek: onSeek
              )
              .id(line.id)
            }
            Spacer().frame(height: 120)
          }
          .padding(.horizontal, 28)
        }
        .mask(
          VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
              .frame(height: 30)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
              .frame(height: 60)
          }
        )
        .onChange(of: currentIndex) { idx in
          if idx < 0 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
              proxy.scrollTo("intro-dots", anchor: .center)
            }
          } else if idx < lyrics.count {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
              proxy.scrollTo(lyrics[idx].id, anchor: .center)
            }
          }
        }
      }
    }
  }
}

private struct InstrumentalDots: View {
  let isActive: Bool
  let isPast: Bool
  let distance: Int
  @State private var pulse = 0
  @State private var pulseTask: Task<Void, Never>?
  var body: some View {
    HStack(spacing: 10) {
      ForEach(0..<3, id: \.self) { i in
        Circle()
          .fill(dotColor)
          .frame(width: dotSize, height: dotSize)
          .scaleEffect(dotScale(for: i))
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: pulse)
    .onAppear { restartPulse() }
    .onDisappear { pulseTask?.cancel() }
    .onChange(of: isActive) { _ in restartPulse() }
  }
  private var dotColor: Color {
    if isActive { return .primary }
    if isPast { return .secondary.opacity(0.55) }
    return .secondary.opacity(0.75)
  }
  private var dotSize: CGFloat {
    isActive ? 12 : 9
  }
  private func dotScale(for i: Int) -> CGFloat {
    guard isActive else { return 1.0 }
    return pulse == i + 1 ? 1.35 : 1.0
  }
  private func restartPulse() {
    pulseTask?.cancel()
    guard isActive else { pulse = 0; return }
    pulseTask = Task { @MainActor in
      while !Task.isCancelled {
        for i in 0..<4 {
          if Task.isCancelled { return }
          pulse = i
          try? await Task.sleep(nanoseconds: 380_000_000)
        }
      }
    }
  }
}

private struct LyricLineRow: View {
  let line: LyricLine
  let index: Int
  let currentIndex: Int
  let onSeek: (TimeInterval) -> Void
  private var isCurrent: Bool { index == currentIndex }
  private var isPast: Bool { index < currentIndex }
  private var distance: Int { abs(index - currentIndex) }
  private var isInstrumental: Bool {
    let normalized = line.text.lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
    return normalized.contains("(instrumental)")
      || normalized.contains("[instrumental]")
      || normalized.contains("♪")
      || normalized == "instrumental"
      || normalized.isEmpty
  }
  var body: some View {
    Button {
      onSeek(line.time)
    } label: {
      Group {
        if isInstrumental {
          InstrumentalDots(isActive: isCurrent, isPast: isPast, distance: distance)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, isCurrent ? 10 : 6)
        } else {
          Text(line.text)
            .font(.system(size: isCurrent ? 26 : 20, weight: isCurrent ? .bold : .semibold))
            .foregroundColor(lineColor)
            .blur(radius: lineBlur)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, isCurrent ? 10 : 6)
        }
      }
      .padding(.horizontal, 4)
    }
    .buttonStyle(.plain)
    .scaleEffect(isCurrent ? 1.0 : 0.92, anchor: .leading)
    .opacity(isInstrumental ? lineOpacity : lineOpacity)
    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: currentIndex)
  }
  private var lineColor: Color {
    if isCurrent { return .primary }
    if isPast { return .secondary.opacity(0.55) }
    return .secondary.opacity(0.75)
  }
  private var lineBlur: CGFloat {
    // Apple Music doesn't blur upcoming lines — they sit at full opacity.
    // We only blur past lines slightly to push focus forward.
    guard isPast else { return 0 }
    return min(CGFloat(distance) * 0.3, 1.2)
  }
  private var lineOpacity: Double {
    if isCurrent { return 1.0 }
    if distance <= 2 { return 1.0 }
    return max(0.5, 1.0 - Double(distance - 2) * 0.1)
  }
}

private struct IntroDots: View {
  let isActive: Bool
  let startTime: TimeInterval
  let currentTime: TimeInterval
  private var countdown: Int {
    let remaining = startTime - currentTime
    if remaining > 3 { return 0 }
    return max(0, 3 - Int(remaining))
  }
  var body: some View {
    HStack(spacing: 10) {
      ForEach(0..<3, id: \.self) { i in
        Circle()
          .fill(dotColor(for: i))
          .frame(width: dotSize(for: i), height: dotSize(for: i))
          .scaleEffect(dotScale(for: i))
      }
    }
    .opacity(isActive ? 1.0 : 0.3)
    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: countdown)
    .animation(.easeInOut(duration: 0.4), value: isActive)
  }
  private func dotColor(for i: Int) -> Color {
    if !isActive { return .secondary.opacity(0.5) }
    if countdown > i { return .primary }
    return .secondary
  }
  private func dotSize(for i: Int) -> CGFloat {
    if isActive && countdown > i { return 10 }
    return 8
  }
  private func dotScale(for i: Int) -> CGFloat {
    if isActive && countdown > i { return 1.2 }
    return 1.0
  }
}
