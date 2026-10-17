import AVFoundation
import Speech
import Combine

@MainActor final class SpeechInput: ObservableObject {
    @Published var recording = false
    @Published var processing = false
    @Published var transcript = ""
    @Published var error: String?
    @Published var completionID = UUID()
    private(set) var completedTranscript = ""
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapped = false
    private var session = UUID()
    private var silence: Task<Void, Never>?
    private var deadline: Task<Void, Never>?

    func start() async {
        guard !recording, !processing else { return }
        cancel()
        let token = UUID(); session = token
        processing = true; error = nil; transcript = ""; completedTranscript = ""
        let permission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard session == token else { return }
        guard permission == .authorized else {
            processing = false; error = "请在系统设置 → 隐私与安全性 → 语音识别中允许 POPZILLA。"; return
        }
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard session == token else { return }
        guard mic else { processing = false; error = "请在系统设置 → 隐私与安全性 → 麦克风中允许 POPZILLA。"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else {
            processing = false; error = "中文语音识别暂不可用，请检查网络或直接打字。"; return
        }
        self.recognizer = recognizer
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        request = req
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            cancel(); error = "找不到可用的麦克风，请检查声音输入设备。"; return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
        tapped = true
        task = recognizer.recognitionTask(with: req) { [weak self] result, failure in
            Task { @MainActor in
                guard let self, self.session == token else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if text != self.transcript { self.transcript = text; if self.recording { self.scheduleSilence(token, seconds: 2) } }
                    if result.isFinal { self.finish(token); return }
                }
                if let failure {
                    if self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self.error = "语音识别失败：\(failure.localizedDescription)" }
                    self.finish(token)
                }
            }
        }
        do {
            engine.prepare(); try engine.start()
            processing = false; recording = true
            scheduleSilence(token, seconds: 12)
        } catch { cancel(); self.error = "录音启动失败：\(error.localizedDescription)" }
    }
    private func scheduleSilence(_ token: UUID, seconds: Double) {
        silence?.cancel()
        silence = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self, self.session == token, self.recording else { return }
            self.stop()
        }
    }
    private func stopAudio() {
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
    }
    /// End the audio stream and allow Apple to return its final transcription.
    func stop() {
        guard recording else { return }
        silence?.cancel(); stopAudio(); request?.endAudio()
        recording = false; processing = true
        let token = session
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            self?.finish(token)
        }
    }
    private func finish(_ token: UUID) {
        guard session == token else { return }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        cancel()
        if text.isEmpty { if error == nil { error = "没有识别到内容，请再说一次。" }; return }
        completedTranscript = text
        completionID = UUID()
    }
    /// Discard a session without adding a task when the view goes away.
    func cancel() {
        session = UUID(); silence?.cancel(); deadline?.cancel()
        silence = nil; deadline = nil
        stopAudio(); task?.cancel(); task = nil; request = nil; recognizer = nil
        recording = false; processing = false
    }
}
