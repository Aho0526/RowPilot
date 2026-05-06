import Foundation
import AVFoundation

class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var sosTimer: Timer?
    private var pressingTimer: Timer?
    
    @Published var isSOSActive = false
    @Published var isPressing = false
    
    // Morse code parameters
    private let dotDuration: TimeInterval = 0.2
    private let dashDuration: TimeInterval = 0.6
    private let gapDuration: TimeInterval = 0.2
    private let letterGapDuration: TimeInterval = 0.6
    private let wordGapDuration: TimeInterval = 1.4
    
    init() {
        setupAudioSession()
        prepareAudioPlayer()
    }
    
    private func setupAudioSession() {
        do {
            // Use .playback option to play even in silent mode if important, and .defaultToSpeaker
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession setup failed: \(error)")
        }
    }
    
    private func prepareAudioPlayer() {
        // Generate the beep file once during init
        generateToneFile()
    }
    
    // MARK: - Pressing Sound (Countdown)
    
    func startPressingSound() {
        guard !isPressing else { return }
        isPressing = true
        
        // Play a fast beep (Warning)
        // Beep every 0.25 seconds
        playTone(duration: 0.1) // Immediate first beep
        
        pressingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.playTone(duration: 0.1)
        }
    }
    
    func stopPressingSound() {
        isPressing = false
        pressingTimer?.invalidate()
        pressingTimer = nil
        // Do not stop audioPlayer immediately if it's just a short beep, let it decay.
        // But if SOS triggers appropriately, we might want to stop.
    }
    
    // MARK: - SOS Alarm
    
    func playSOSTone() {
        stopPressingSound() // Ensure pressing sound stops
        guard !isSOSActive else { return }
        isSOSActive = true
        
        // Start the SOS sequence loop
        startMorseSequence()
    }
    
    func stopSOS() {
        isSOSActive = false
        sosTimer?.invalidate()
        sosTimer = nil
        audioPlayer?.stop()
    }
    
    // MARK: - Internal Logic
    
    private func startMorseSequence() {
        let sequence: [(duration: TimeInterval, isSound: Bool)] = [
            // S
            (dotDuration, true), (gapDuration, false),
            (dotDuration, true), (gapDuration, false),
            (dotDuration, true), (letterGapDuration, false),
            // O
            (dashDuration, true), (gapDuration, false),
            (dashDuration, true), (gapDuration, false),
            (dashDuration, true), (letterGapDuration, false),
            // S
            (dotDuration, true), (gapDuration, false),
            (dotDuration, true), (gapDuration, false),
            (dotDuration, true), (wordGapDuration, false)
        ]
        
        playNextSignal(sequence: sequence, index: 0)
    }
    
    private func playNextSignal(sequence: [(duration: TimeInterval, isSound: Bool)], index: Int) {
        guard isSOSActive else { return }
        
        let item = sequence[index % sequence.count]
        
        if item.isSound {
            playTone(duration: item.duration)
        }
        
        let nextDelay = item.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) { [weak self] in
            self?.playNextSignal(sequence: sequence, index: index + 1)
        }
    }
    
    private func playTone(duration: TimeInterval) {
        // Ensure player is ready
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        
        player.currentTime = 0
        player.volume = 1.0
        player.play()
        
        // Stop after 'duration'
        // Note: The timer approach to stop playback works for synthesized constant tones.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            // Only stop if we are still supposed to be playing this exact tone? 
            // If another tone started, player.currentTime would be reset.
            // This is a bit racy but for a beep it is usually fine.
            // Better: Fade out?
            self?.audioPlayer?.stop()
        }
    }
    
    private func generateToneFile() {
        let frequency = 880.0 // A5
        let amplitude = 1.0
        let sampleRate = 44100.0
        let duration = 2.0 // Long enough buffer
        
        let frameCount = Int(sampleRate * duration)
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        
        let channelData = buffer.floatChannelData![0]
        
        for i in 0..<frameCount {
            let x = Double(i) / sampleRate
            let value = Float(amplitude * sin(2.0 * .pi * frequency * x))
            channelData[i] = value
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("beep_v2.wav")
        
        do {
            let file = try AVAudioFile(forWriting: tempUrl, settings: audioFormat.settings)
            try file.write(from: buffer)
            
            audioPlayer = try AVAudioPlayer(contentsOf: tempUrl)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Tone generation failed: \(error)")
        }
    }
}
