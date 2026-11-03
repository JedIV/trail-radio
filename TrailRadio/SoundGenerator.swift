import Foundation

/// Render-thread-owned synthesis, adapted from brooklyn-trail-emulator/ambient.js.
/// No network, recordings, timers, or allocations in the sample loop.
final class SoundGenerator {
    enum Layer: Int, CaseIterable { case wind, hoofbeats, wagon, birds }
    private let layer: Layer
    private let rate: Double
    private let retention: Double
    private let filterCoefficient: Double
    private var random: UInt64
    private var time = 0.0
    private var brown = 0.0
    private var filtered = 0.0
    private var bass = 0.0
    private let bassCoefficient: Double
    private var nextEvent = 0.0
    private var eventStart = -100.0
    private var birdFrequency = 2200.0
    private var pan = 0.0
    private var creakFrequency = 200.0

    init(layer: Layer, sampleRate: Double, seed: UInt64 = 12345) {
        self.layer = layer; rate = sampleRate; random = seed == 0 ? 1 : seed
        retention = pow(1 / 1.025, 44100 / sampleRate)
        filterCoefficient = 1 - exp(-2 * .pi * 580 / sampleRate)
        bassCoefficient = 1 - exp(-2 * .pi * 160 / sampleRate)
        nextEvent = layer == .birds ? 5 : (layer == .wagon ? 2 : 0)
    }
    private func rand() -> Double {
        random ^= random << 13; random ^= random >> 7; random ^= random << 17
        return Double(random >> 11) / 9007199254740992.0
    }
    private func triangle(_ p: Double) -> Double {
        2 * abs(2 * (p / (2 * .pi) - floor(p / (2 * .pi) + 0.5))) - 1
    }
    private func envelope(_ age: Double, duration: Double, attack: Double = 0.012) -> Double {
        guard age >= 0, age < duration else { return 0 }
        if age < attack { return exp(log(0.0001) * (1 - age / attack)) }
        return exp(log(0.0001) * (age - attack) / (duration - attack))
    }
    private func sweep(_ age: Double, duration: Double, from: Double, to: Double, triangleWave: Bool = false, attack: Double = 0.012) -> Double {
        guard age >= 0, age < duration else { return 0 }
        let k = log(to / from) / duration
        let angle = 2 * Double.pi * from * expm1(k * age) / k
        return (triangleWave ? triangle(angle) : sin(angle)) * envelope(age, duration: duration, attack: attack)
    }
    func sample() -> (Float, Float) {
        let white = rand() * 2 - 1
        // Equivalent time constants across 44.1/48 kHz hardware.
        brown = retention * brown + (1 - retention) * white
        filtered += filterCoefficient * (brown * 3 - filtered)
        bass += bassCoefficient * (brown * 3 - bass)
        var value = 0.0
        switch layer {
        case .wind:
            // More low-mid body with similar overall level and a gentler swell.
            value = 0.82 * (filtered + bass * 1.2) * (0.2 + 0.025 * sin(2 * .pi * 0.075 * time))
            pan = 0
        case .hoofbeats:
            if time >= nextEvent { eventStart = time; nextEvent = time + 0.72 + rand() * 0.12 }
            let age = time - eventStart
            value = 0.15 * sweep(age, duration: 0.18, from: 88, to: 38, attack: 0.025)
                + 0.11 * sweep(age - 0.17, duration: 0.16, from: 104, to: 45, attack: 0.025)
                + filtered * (0.035 * envelope(age, duration: 0.09, attack: 0.02)
                    + 0.025 * envelope(age - 0.17, duration: 0.08, attack: 0.02))
            pan = age < 0.17 ? -0.22 : 0.22
        case .wagon:
            if time >= nextEvent {
                eventStart = time; nextEvent = time + 4 + rand() * 6; creakFrequency = 185 + rand() * 35
            }
            let age = time - eventStart
            value = 0.023 * sweep(age, duration: 0.55, from: creakFrequency, to: 105, triangleWave: true)
                + filtered * 0.055 * envelope(age, duration: 0.6, attack: 0.008)
            pan = -0.2
        case .birds:
            if time >= nextEvent {
                eventStart = time; nextEvent = time + 12 + rand() * 18
                birdFrequency = 1900 + rand() * 700; pan = rand() * 1.4 - 0.7
            }
            let age = time - eventStart
            value = 0.019 * sweep(age, duration: 0.12, from: birdFrequency, to: birdFrequency * 1.4)
                + 0.014 * sweep(age - 0.2, duration: 0.16, from: birdFrequency * 1.2, to: birdFrequency * 0.84)
        }
        time += 1 / rate
        let angle = (pan + 1) * .pi / 4
        return (Float(value * cos(angle)), Float(value * sin(angle)))
    }
}
