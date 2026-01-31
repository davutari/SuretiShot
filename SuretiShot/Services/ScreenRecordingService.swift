import Foundation
import AVFoundation
import ScreenCaptureKit

final class ScreenRecordingService: NSObject, ObservableObject {

    @Published private(set) var isRecording = false

    private var stream: SCStream?
    private var streamOutput: RecordingStreamOutput?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var outputURL: URL?

    // MARK: - Public Methods

    func startRecording(to url: URL) async throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw RecordingError.setupFailed
        }

        // Configure stream
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()

        configuration.width = Int(display.width) * 2
        configuration.height = Int(display.height) * 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 fps
        configuration.queueDepth = 5
        configuration.showsCursor = true
        if #available(macOS 14.0, *) {
            configuration.captureResolution = .best
        }
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        // Setup asset writer
        outputURL = url

        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: configuration.width,
            AVVideoHeightKey: configuration.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        guard let assetWriter = assetWriter, let videoInput = videoInput else {
            throw RecordingError.setupFailed
        }

        if assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)
        } else {
            throw RecordingError.setupFailed
        }

        // Create stream output
        streamOutput = RecordingStreamOutput(
            assetWriter: assetWriter,
            videoInput: videoInput
        )

        // Create and start stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)

        guard let stream = stream, let streamOutput = streamOutput else {
            throw RecordingError.setupFailed
        }

        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))

        assetWriter.startWriting()

        try await stream.startCapture()

        await MainActor.run {
            self.isRecording = true
        }
    }

    func stopRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }

        await MainActor.run {
            self.isRecording = false
        }

        // Stop stream
        try await stream?.stopCapture()
        stream = nil

        // Finish writing
        videoInput?.markAsFinished()

        await assetWriter?.finishWriting()

        // Cleanup
        streamOutput = nil
        assetWriter = nil
        videoInput = nil
        outputURL = nil
    }
}

// MARK: - SCStreamDelegate

extension ScreenRecordingService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.isRecording = false
        }
        print("Stream stopped with error: \(error)")
    }
}

// MARK: - Recording Stream Output

private final class RecordingStreamOutput: NSObject, SCStreamOutput {
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private var sessionStarted = false
    private let lock = NSLock()

    init(assetWriter: AVAssetWriter, videoInput: AVAssetWriterInput) {
        self.assetWriter = assetWriter
        self.videoInput = videoInput
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        lock.lock()
        defer { lock.unlock() }

        guard assetWriter.status == .writing else { return }

        if !sessionStarted {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        if videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }
}
