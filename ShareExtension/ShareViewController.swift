import UIKit
import UniformTypeIdentifiers

/// Registered directly as NSExtensionPrincipalClass in Info.plist — no
/// storyboard required. iOS instantiates this when the user picks this
/// extension from a Share Sheet. Handles two distinct cases:
///   - An audio/video file (e.g. Share on a recording in Voice Memos)
///     imports it as a new recording to transcribe.
///   - Plain text (e.g. Share on a translation in Translate, or a
///     selection in Notes/Safari) adds it to the vocabulary list.
final class ShareViewController: UIViewController {

    // Must exactly match the App Group ID in SharedContainer.swift.
    private let appGroupID = "group.com.ncubeeight.dejaentendu"

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        label.text = "Adding to Déjà Entendu…"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        view.addSubview(spinner)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            let outcome = await importSharedItem()
            await MainActor.run { label.text = outcome.message }
            try? await Task.sleep(nanoseconds: 500_000_000)
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private enum ImportOutcome {
        case audioAdded
        case vocabularyAdded
        case failed

        var message: String {
            switch self {
            case .audioAdded: return "Added to Déjà Entendu ✓"
            case .vocabularyAdded: return "Added to Vocabulary ✓"
            case .failed: return "Couldn't read that"
            }
        }
    }

    private func importSharedItem() async -> ImportOutcome {
        guard
            let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = extensionItem.attachments
        else { return .failed }

        // Plain text (Translate, Notes, a Safari selection, ...) goes to
        // the vocabulary list — check this before audio/movie since a
        // provider could technically advertise both.
        for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = await loadText(from: provider), !text.isEmpty {
                return saveVocabularyText(text) ? .vocabularyAdded : .failed
            }
        }

        let candidateTypes: [UTType] = [.audio, .mpeg4Audio, .movie, .mpeg4Movie]
        for provider in attachments {
            for type in candidateTypes where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                if let fileURL = await loadFileURL(from: provider, typeIdentifier: type.identifier) {
                    return saveToSharedInbox(fileURL) ? .audioAdded : .failed
                }
            }
        }
        return .failed
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let nsString = item as? NSString {
                    continuation.resume(returning: nsString as String)
                } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadFileURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data {
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("m4a")
                    do {
                        try data.write(to: tmp)
                        continuation.resume(returning: tmp)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func saveToSharedInbox(_ sourceURL: URL) -> Bool {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return false }

        let inbox = container.appendingPathComponent("ShareInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let destination = inbox
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return true
        } catch {
            return false
        }
    }

    private func saveVocabularyText(_ text: String) -> Bool {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return false }

        let inbox = container.appendingPathComponent("VocabularyInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let destination = inbox.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")

        do {
            try text.write(to: destination, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
