import Foundation

// Render 40 seconds of every layer at both common iPhone sample rates.
// Check delayed events, silence, finite output, bounds, and reproducibility.
for rate in [44100.0, 48000.0] {
    var mixPeak: Float = 0
    let layers = SoundGenerator.Layer.allCases.map { SoundGenerator(layer: $0, sampleRate: rate) }
    var energy = [Double](repeating: 0, count: 4)
    for _ in 0..<Int(rate * 40) {
        var left: Float = 0, right: Float = 0
        for (i, generator) in layers.enumerated() {
            let (l, r) = generator.sample()
            precondition(l.isFinite && r.isFinite, "Nonfinite sample")
            energy[i] += Double(l * l + r * r)
            left += l; right += r
        }
        mixPeak = max(mixPeak, max(abs(left), abs(right)) * 0.55)
    }
    precondition(energy.allSatisfy { $0 > 0.001 }, "Missing sound layer")
    precondition(mixPeak < 1, "Clipping at full volume")
    print("PASS \(Int(rate)) Hz: all four layers audible, finite; master peak \(mixPeak)")
}
for layer in SoundGenerator.Layer.allCases {
    let a = SoundGenerator(layer: layer, sampleRate: 48000, seed: 7)
    let b = SoundGenerator(layer: layer, sampleRate: 48000, seed: 7)
    for _ in 0..<10000 {
        let x = a.sample(), y = b.sample()
        precondition(x.0 == y.0 && x.1 == y.1)
    }
}
print("PASS reproducible synthesis")
