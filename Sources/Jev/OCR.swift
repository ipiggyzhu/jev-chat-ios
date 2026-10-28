import Foundation
import Vision
import UIKit

/// On-device OCR for imported chat screenshots (Vision framework, Chinese).
/// Nothing is uploaded: recognition runs locally, like the original's ML Kit path.
/// Speaker split follows the chat-UI convention: bubbles on the right are mine,
/// bubbles on the left are the other person's.
enum ScreenshotOCR {
    struct Line {
        var text: String
        var midX: Double
        var maxY: Double
    }

    static func recognize(_ image: UIImage) async throws -> [ChatMessage] {
        guard let cg = image.cgImage else { return [] }
        let lines = try await Task.detached(priority: .userInitiated) { () throws -> [Line] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            return observations.compactMap { obs -> Line? in
                guard let text = obs.topCandidates(1).first?.string else { return nil }
                let box = obs.boundingBox
                return Line(text: text, midX: Double(box.midX), maxY: Double(box.maxY))
            }
        }.value

        // Vision coordinates are bottom-up: sort by maxY descending = top to bottom.
        let sorted = lines.sorted { $0.maxY > $1.maxY }
        return sorted.map { line in
            ChatMessage(speaker: line.midX > 0.55 ? .me : .them, text: line.text)
        }
    }
}
