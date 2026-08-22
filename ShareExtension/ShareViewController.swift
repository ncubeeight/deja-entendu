import UIKit
import UniformTypeIdentifiers

/// Registered directly as NSExtensionPrincipalClass in Info.plist — no
/// storyboard required. iOS instantiates this when the user picks this
/// extension from a Share Sheet, e.g. tapping Share on a recording inside
/// Voice Memos and choosing "Add to Déjà Entendu."
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
            let didImport = await importSharedAudio()
            await MainActor.run { label.text = didImport ? "Added to Déjà Entendu ✓" : "Couldn't read that file" }
            try? await Task.sleep(nanoseconds: 500_000_000)
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func importSharedAudio() async -> Bool {
        guard
            let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = extensionItem.attachments
        else { return false }

        let candidateTypes: [UTType] = [.audio, .mpeg4Audio, .movie, .mpeg4Movie]

        for provider in attachments {
            for type in candidateTypes where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                if let fileURL = await loadFileURL(from: provider, typeIdentifier: type.identifier) {
                    return saveToSharedInbox(fileURL)
                }
            }
        }
        return false
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
}
