import SwiftUI
import AVFoundation

/// Records audio directly in the app — for a user who wants to speak a
/// practice sentence right now rather than importing an existing file or
/// a Voice Memos recording (which, unlike Files, has no way to hand a
/// recording to another app except its own Share Sheet). Saved through
/// the same AudioIngestion/ImportedRecordingStore path as any other
/// audio sample, so it's indistinguishable once imported.
struct LiveRecordingView: View {
    let language: SupportedLanguage
    let onFinish: (ImportedRecording) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var recordedURL: URL?
    @State private var permissionDenied = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(timeString(elapsed))
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit()

                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(isRecording ? .red : AppTheme.coral)
                }
                .disabled(permissionDenied)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Record — \(language.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupAndDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Recording") {
                        finish()
                    }
                    .disabled(recordedURL == nil || isRecording)
                }
            }
        }
        .task {
            await requestPermission()
        }
    }

    private var statusText: String {
        if permissionDenied { return "Microphone access is required to record. Enable it in Settings." }
        if isRecording { return "Recording…" }
        if recordedURL != nil { return "Tap Use Recording to save, or record again to redo it." }
        return "Tap to start recording."
    }

    private func requestPermission() async {
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        permissionDenied = !granted
    }

    private func startRecording() {
        do {
            // .record (not .playback) since this session only captures —
            // matches the app's other AVAudioSession use, each scoped to
            // what that screen actually does with audio.
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.record()
            recorder = newRecorder
            recordedURL = url
            isRecording = true
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                elapsed += 0.1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
    }

    private func finish() {
        guard let recordedURL else { return }
        do {
            // Not security-scoped (it's our own temp file, not something
            // picked from outside the sandbox) — copyIntoAppContainer's
            // isReadableFile fallback covers that case already.
            let copy = try AudioIngestion.copyIntoAppContainer(from: recordedURL, source: .liveRecording, language: language)
            try? FileManager.default.removeItem(at: recordedURL)

            // copyIntoAppContainer uses the source file's own name, which
            // for a live recording is just a UUID — replace it with
            // something a user would actually recognize in the list.
            let recording = ImportedRecording(
                id: copy.id,
                originalFilename: "Recording — \(copy.importedAt.formatted(date: .abbreviated, time: .shortened))",
                localURL: copy.localURL,
                importedAt: copy.importedAt,
                source: copy.source,
                language: copy.language
            )
            onFinish(recording)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cleanupAndDismiss() {
        stopRecording()
        if let recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        dismiss()
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    LiveRecordingView(language: .french) { _ in }
}
