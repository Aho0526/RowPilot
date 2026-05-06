import Foundation
import AVFoundation

/// 音声フィードバックを管理するViewModel
class SoundFeedbackViewModel: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var feedbackTimer: Timer?
    
    @Published var isEnabled: Bool = true
    @Published var voiceFeedbackEnabled: Bool = false
    @Published var feedbackInterval: TimeInterval = FeedbackConstants.defaultVoiceFeedbackInterval
    
    // 最後のフィードバック時刻
    private var lastFeedbackTime: Date?
    
    init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("音声セッションの設定に失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sound Effects
    
    /// ストローク音を再生
    func playStrokeSound() {
        guard isEnabled else { return }
        playSound(named: "stroke", withExtension: "wav")
    }
    
    /// 開始音を再生
    func playStartSound() {
        guard isEnabled else { return }
        playSound(named: "start", withExtension: "wav")
    }
    
    /// 停止音を再生
    func playStopSound() {
        guard isEnabled else { return }
        playSound(named: "stop", withExtension: "wav")
    }
    
    /// 警告音を再生
    func playWarningSound() {
        guard isEnabled else { return }
        playSound(named: "warning", withExtension: "wav")
    }
    
    private func playSound(named name: String, withExtension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("音声ファイルが見つかりません: \(name).\(ext)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("音声再生エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Voice Feedback
    
    /// 音声フィードバックを開始
    func startVoiceFeedback() {
        guard voiceFeedbackEnabled else { return }
        
        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(
            withTimeInterval: feedbackInterval,
            repeats: true
        ) { [weak self] _ in
            self?.provideFeedback()
        }
    }
    
    /// 音声フィードバックを停止
    func stopVoiceFeedback() {
        feedbackTimer?.invalidate()
        feedbackTimer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    /// 現在の状態をフィードバック
    private func provideFeedback() {
        // TODO: 実際の計測データを取得してフィードバック
        // 現在はプレースホルダー
    }
    
    /// カスタムメッセージを音声で読み上げ
    func speak(_ message: String, language: String = "ja-JP") {
        guard voiceFeedbackEnabled else { return }
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5 // 読み上げ速度（0.0〜1.0）
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    /// 計測データに基づいてフィードバック
    func provideFeedback(spm: Int, speed: Double, distance: Double, duration: TimeInterval) {
        guard voiceFeedbackEnabled else { return }
        
        // 前回のフィードバックから十分な時間が経過しているか確認
        if let lastTime = lastFeedbackTime,
           Date().timeIntervalSince(lastTime) < feedbackInterval {
            return
        }
        
        lastFeedbackTime = Date()
        
        // フィードバックメッセージを構築
        let minutes = Int(duration) / 60
        let distanceKm = distance / 1000.0
        
        var message = ""
        
        if minutes > 0 {
            message += "\(minutes)分経過。"
        }
        
        if distanceKm > 0.1 {
            message += String(format: "距離%.1fキロメートル。", distanceKm)
        }
        
        if spm > 0 {
            message += "ストロークレート\(spm)。"
        }
        
        if speed > 0 {
            message += String(format: "速度%.1fキロメートル毎時。", speed)
        }
        
        if !message.isEmpty {
            speak(message)
        }
    }
    
    /// SPMに基づいた励ましのフィードバック
    func provideEncouragement(spm: Int, targetSPM: Int) {
        guard voiceFeedbackEnabled else { return }
        
        let difference = abs(spm - targetSPM)
        
        if difference <= 2 {
            speak("良いペースです")
        } else if spm < targetSPM {
            speak("もう少しペースを上げましょう")
        } else {
            speak("ペースが速すぎます")
        }
    }
    
    // MARK: - Cleanup
    deinit {
        stopVoiceFeedback()
    }
}

// MARK: - Feedback Types
extension SoundFeedbackViewModel {
    enum FeedbackType {
        case stroke
        case start
        case stop
        case warning
        case milestone(String)
        case encouragement(String)
    }
    
    func provideFeedback(type: FeedbackType) {
        switch type {
        case .stroke:
            playStrokeSound()
        case .start:
            playStartSound()
        case .stop:
            playStopSound()
        case .warning:
            playWarningSound()
        case .milestone(let message):
            speak(message)
        case .encouragement(let message):
            speak(message)
        }
    }
}
