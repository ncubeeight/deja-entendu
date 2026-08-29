import Foundation
import Vision
import UniformTypeIdentifiers
import ImageIO

enum ImageIngestionError: LocalizedError {
    case couldNotDecodeImage
    case couldNotCopyFile(underlying: Error)
    case recognitionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .couldNotDecodeImage:
            return "That photo couldn't be read."
        case .couldNotCopyFile(let underlying):
            return "Couldn't copy the photo into the app: \(underlying.localizedDescription)"
        case .recognitionFailed(let underlying):
            return "Text recognition failed: \(underlying.localizedDescription)"
        }
    }
}

/// Copies a picked photo into the app's own container and runs on-device
/// Vision text recognition on it. Deliberately Vision (VNRecognizeTextRequest)
/// rather than Foundation Models' newer multimodal image input — that path
/// only works on Apple Intelligence-eligible hardware (A17 Pro+), while
/// Vision's OCR has no such gate and runs on every device this app supports.
enum ImageIngestion {

    static func copyAndRecognizeText(
        from imageData: Data,
        suggestedFilename: String,
        language: SupportedLanguage
    ) throws -> ImportedImageSample {

        let recognizedText = try recognizeText(in: imageData, language: language)

        let sampleID = UUID()
        let destinationDirectory = try imagesDirectory()
        let fileExtension = UTType(data: imageData)?.preferredFilenameExtension ?? "jpg"
        let destinationURL = destinationDirectory
            .appendingPathComponent(sampleID.uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try imageData.write(to: destinationURL, options: .atomic)
        } catch {
            throw ImageIngestionError.couldNotCopyFile(underlying: error)
        }

        return ImportedImageSample(
            id: sampleID,
            originalFilename: suggestedFilename,
            localURL: destinationURL,
            recognizedText: recognizedText,
            importedAt: .now,
            language: language
        )
    }

    private static func recognizeText(in imageData: Data, language: SupportedLanguage) throws -> String {
        let handler = VNImageRequestHandler(data: imageData, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [language.locale.identifier(.bcp47)]

        do {
            try handler.perform([request])
        } catch {
            throw ImageIngestionError.recognitionFailed(underlying: error)
        }

        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private static func imagesDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ImportedImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

private extension UTType {
    /// Best-effort type sniffing from raw image bytes — PhotosPickerItem
    /// hands us Data, not a URL with an extension, so we can't rely on a
    /// path extension like AudioIngestion does with file-importer URLs.
    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return nil }
        self.init(type as String)
    }
}
