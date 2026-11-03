import AVFoundation
import Combine
import MediaPlayer

final class TrailAudio: NSObject, ObservableObject {
    @Published private(set) var playing = false
    @Published var error: String?
    @Published private(set) var sleepEnd: Date?
    @Published var volume: Float = UserDefaults.standard.object(forKey: "volume") as? Float ?? 0.44 {
        didSet { rampVolume(to: playing ? volume * 0.55 : 0); UserDefaults.standard.set(volume, forKey: "volume") }
    }
    @Published var levels: [Float] = (0..<4).map { UserDefaults.standard.object(forKey: "layer\($0)") as? Float ?? 1 } {
        didSet {
            for (i, mixer) in mixers.enumerated() { mixer.outputVolume = levels[i] }
            for i in levels.indices { UserDefaults.standard.set(levels[i], forKey: "layer\(i)") }
        }
    }
    private var engine = AVAudioEngine()
    private var mixers: [AVAudioMixerNode] = []
    private var fadeTask: Task<Void, Never>?
    private var timer: Timer?
    private var resumeAfterInterruption = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaReset), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in DispatchQueue.main.async { self?.play() }; return .success }
        commands.pauseCommand.addTarget { [weak self] _ in DispatchQueue.main.async { self?.pause() }; return .success }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in DispatchQueue.main.async { self?.toggle() }; return .success }
    }
    private func prepareEngine() {
        guard mixers.isEmpty else { return }
        let rate = AVAudioSession.sharedInstance().sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        for layer in SoundGenerator.Layer.allCases {
            let generator = SoundGenerator(layer: layer, sampleRate: rate, seed: UInt64(layer.rawValue + 1) * 7919)
            let source = AVAudioSourceNode(format: format) { _, _, count, list -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(list)
                guard buffers.count == 2,
                      let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                      let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return -50 }
                for frame in 0..<Int(count) {
                    let (l, r) = generator.sample(); left[frame] = l; right[frame] = r
                }
                return noErr
            }
            let mixer = AVAudioMixerNode()
            engine.attach(source); engine.attach(mixer)
            engine.connect(source, to: mixer, format: format)
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
            mixer.outputVolume = levels[layer.rawValue]; mixers.append(mixer)
        }
        engine.mainMixerNode.outputVolume = 0
        engine.prepare()
    }
    func toggle() { playing ? pause() : play() }
    func play() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Playback already supports AirPlay. Explicit allowAirPlay is only valid
            // with playAndRecord and causes OSStatus -50 on physical iPhones.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            prepareEngine()
            fadeTask?.cancel()
            try engine.start()
            playing = true; error = nil; updateNowPlaying()
            rampVolume(to: volume * 0.55)
        } catch { self.error = "Audio couldn’t start: \(error.localizedDescription)"; playing = false }
    }
    func pause(immediately: Bool = false) {
        playing = false; resumeAfterInterruption = false
        setSleepTimer(minutes: 0); updateNowPlaying()
        if immediately {
            fadeTask?.cancel(); finishPause()
        } else { rampVolume(to: 0, stopAfterward: true) }
    }
    private func finishPause() {
        engine.pause(); engine.mainMixerNode.outputVolume = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func rampVolume(to target: Float, stopAfterward: Bool = false) {
        fadeTask?.cancel()
        let start = engine.mainMixerNode.outputVolume
        fadeTask = Task { @MainActor [weak self] in
            for step in 1...40 {
                do { try await Task.sleep(nanoseconds: 10_000_000) } catch { return }
                guard let self, !Task.isCancelled else { return }
                let progress = Float(step) / 40
                let smooth = progress * progress * (3 - 2 * progress)
                self.engine.mainMixerNode.outputVolume = start + (target - start) * smooth
            }
            if stopAfterward { self?.finishPause() }
        }
    }
    func setSleepTimer(minutes: Int) {
        timer?.invalidate(); timer = nil
        sleepEnd = minutes > 0 ? Date().addingTimeInterval(Double(minutes * 60)) : nil
        guard let end = sleepEnd else { return }
        timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in self?.pause() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Trail Radio",
            MPMediaItemPropertyArtist: "Wind · Hoofbeats · Wagon · Birds",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0
        ]
    }
    @objc private func interruption(_ note: Notification) {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.interruption(note) }; return }
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let kind = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if kind == .began {
            fadeTask?.cancel(); resumeAfterInterruption = playing; engine.pause(); playing = false; updateNowPlaying()
        } else {
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            let shouldResume = resumeAfterInterruption && options.contains(.shouldResume)
            resumeAfterInterruption = false
            if let end = sleepEnd, end <= Date() { pause() }
            else if shouldResume { play() }
        }
    }
    @objc private func routeChanged(_ note: Notification) {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.routeChanged(note) }; return }
        if note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { pause(immediately: true) }
    }
    @objc private func mediaReset() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.mediaReset() }; return }
        fadeTask?.cancel()
        let wasPlaying = playing
        engine = AVAudioEngine(); mixers.removeAll(); playing = false
        if wasPlaying { play() }
    }
}
