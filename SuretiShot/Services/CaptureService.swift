import Foundation
import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureService: NSObject {

    private var captureStream: SCStream?
    private var capturedImage: CGImage?
    private var captureCompletion: ((Result<Data, Error>) -> Void)?

    // MARK: - Public Methods

    func capture(type: CaptureType) async throws -> Data {
        switch type {
        case .fullScreen:
            return try await captureFullScreen()
        case .selectedArea:
            return try await captureWithScreencapture(arguments: ["-i", "-x"])
        case .activeWindow:
            return try await captureWithScreencapture(arguments: ["-i", "-w", "-x"])
        }
    }

    // MARK: - ScreenCaptureKit Full Screen

    private func captureFullScreen() async throws -> Data {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = Int(display.width) * 2
        config.height = Int(display.height) * 2
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 1

        return try await withCheckedThrowingContinuation { continuation in
            self.captureCompletion = { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            self.captureStream = stream

            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                stream.startCapture { error in
                    if let error = error {
                        self.captureCompletion?(.failure(error))
                        self.captureCompletion = nil
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func pngData(from image: CGImage) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    private func stopCapture() {
        captureStream?.stopCapture { _ in }
        captureStream = nil
    }

    // MARK: - Screencapture Helper (for interactive modes)

    nonisolated private func captureWithScreencapture(arguments: [String]) async throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")

        var args = arguments
        args.append(tempURL.path)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = args

                let errorPipe = Pipe()
                task.standardError = errorPipe

                do {
                    try task.run()
                    task.waitUntilExit()

                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        do {
                            let data = try Data(contentsOf: tempURL)
                            try? FileManager.default.removeItem(at: tempURL)

                            if data.count > 100 {
                                continuation.resume(returning: data)
                            } else {
                                continuation.resume(throwing: CaptureError.captureFailed)
                            }
                        } catch {
                            continuation.resume(throwing: CaptureError.saveFailed)
                        }
                    } else {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorString = String(data: errorData, encoding: .utf8) ?? ""

                        if errorString.contains("cannot") || errorString.contains("error") {
                            continuation.resume(throwing: CaptureError.captureFailed)
                        } else {
                            continuation.resume(throwing: CaptureError.cancelled)
                        }
                    }
                } catch {
                    continuation.resume(throwing: CaptureError.captureFailed)
                }
            }
        }
    }
}

// MARK: - SCStreamDelegate

extension CaptureService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.captureCompletion?(.failure(error))
            self.captureCompletion = nil
        }
    }
}

// MARK: - SCStreamOutput

extension CaptureService: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor in
            if let data = self.pngData(from: cgImage) {
                self.captureCompletion?(.success(data))
            } else {
                self.captureCompletion?(.failure(CaptureError.captureFailed))
            }
            self.captureCompletion = nil
            self.stopCapture()
        }
    }
}
