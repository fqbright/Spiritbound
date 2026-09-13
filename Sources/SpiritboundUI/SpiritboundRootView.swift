import SwiftUI
import SpiritboundCore

/// App entry view. Loading failures remain visible rather than crashing at launch.
public struct SpiritboundRootView: View {
    @State private var model: BattleModel?
    @State private var failed = false
    public init() {}
    public var body: some View {
        Group {
            if let model { BattleView(model: model) }
            else if failed {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                    Text("Unable to load game content.\n无法加载游戏内容。")
                        .multilineTextAlignment(.center)
                    Button("Retry / 重试", action: load).buttonStyle(.borderedProminent)
                }.padding()
            } else { ProgressView().task { load() } }
        }
        .preferredColorScheme(.dark)
    }
    private func load() {
        do {
            model = try BattleModel(content: .bundled(), seed: UInt64.random(in: .min ... .max))
            failed = false
        } catch { failed = true }
    }
}
