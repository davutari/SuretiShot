import Foundation
import AVFoundation
import ScreenCaptureKit
import SwiftUI
import Combine

@MainActor
final class ScreenRecordingService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var recordingStatus: RecordingStatus = .idle
    @Published private(set) var recordingPreview: NSImage?
    @Published private(set) var estimatedFileSize: Int64 = 0
    @Published private(set) var recordingQuality: RecordingQuality = .high
    @Published private(set) var availableDisplays: [SCDisplay] = []
    @Published private(set) var selectedDisplay: SCDisplay?
    @Published private(set) var recordingOptions = RecordingOptions()
    
    // MARK: - Private Properties
    
    private var stream: SCStream?
    private var streamOutput: EnhancedRecordingStreamOutput?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var recordingTimer: Timer?
    private var startTime: Date?
    private var previewTimer: Timer?
    
    // Configuration
    private let recordingQualitySettings = RecordingQualityManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    
    override init() {
        super.init()
        setupRecordingOptions()
        loadAvailableDisplays()
    }
    
    // MARK: - Public Methods
    
    /// Start recording with enhanced options
    func startRecording(
        to url: URL,
        display: SCDisplay? = nil,
        options: RecordingOptions? = nil
    ) async throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        // Update status
        updateRecordingStatus(.preparing)

        // Check permissions
        let hasPermission = await PermissionManager.shared.hasScreenCapturePermission()
        guard hasPermission else {
            updateRecordingStatus(.failed(RecordingError.noPermission))
            throw RecordingError.noPermission
        }

        // Use provided options or default
        if let options = options {
            recordingOptions = options
        }
        
        do {
            try await setupRecordingSession(url: url, display: display)
            try await beginRecording()
            
            updateRecordingStatus(.recording)
            startRecordingTimer()
            startPreviewGeneration()
            
        } catch {
            updateRecordingStatus(.failed(error))
            throw error
        }
    }

    /// Stop recording with optional post-processing
    func stopRecording(shouldOptimize: Bool = true) async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }

        updateRecordingStatus(.finalizing)
        
        // Stop timers
        stopRecordingTimer()
        stopPreviewGeneration()

        do {
            try await finishRecording()
            
            if shouldOptimize, let url = outputURL {
                updateRecordingStatus(.optimizing)
                try await optimizeRecording(at: url)
            }
            
            updateRecordingStatus(.completed)
            
        } catch {
            updateRecordingStatus(.failed(error))
            throw error
        }
    }
    
    /// Pause recording (iOS 15+)
    @available(macOS 13.0, *)
    func pauseRecording() async throws {
        guard isRecording else { throw RecordingError.notRecording }
        // Implementation for pause functionality
        updateRecordingStatus(.paused)
        stopRecordingTimer()
    }
    
    /// Resume recording
    @available(macOS 13.0, *)
    func resumeRecording() async throws {
        guard recordingStatus == .paused else { throw RecordingError.invalidState }
        updateRecordingStatus(.recording)
        startRecordingTimer()
    }
    
    /// Update recording quality during recording
    func updateRecordingQuality(_ quality: RecordingQuality) {
        recordingQuality = quality
        // Apply quality changes if recording is active
        if isRecording {
            Task {
                try await applyQualityChanges()
            }
        }
    }
    
    /// Get estimated recording file size
    func estimateFileSize(duration: TimeInterval, quality: RecordingQuality) -> Int64 {
        return recordingQualitySettings.estimateFileSize(
            duration: duration,
            quality: quality,
            display: selectedDisplay ?? availableDisplays.first
        )
    }

    // MARK: - Private Setup Methods
    
    private func setupRecordingOptions() {
        // Load saved preferences
        if let savedQuality = UserDefaults.standard.object(forKey: "RecordingQuality") as? String,
           let quality = RecordingQuality(rawValue: savedQuality) {
            recordingQuality = quality
        }
        
        // Setup reactive updates
        $recordingQuality
            .sink { [weak self] quality in
                UserDefaults.standard.set(quality.rawValue, forKey: "RecordingQuality")
                self?.recordingOptions.quality = quality
            }
            .store(in: &cancellables)
    }
    
    private func loadAvailableDisplays() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                await MainActor.run {
                    self.availableDisplays = content.displays
                    self.selectedDisplay = content.displays.first
                }
            } catch {
                print("Failed to load displays: \(error)")
            }
        }
    }
    
    private func setupRecordingSession(url: URL, display: SCDisplay?) async throws {
        outputURL = url
        
        // Get content to record
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        let targetDisplay = display ?? selectedDisplay ?? content.displays.first
        guard let targetDisplay = targetDisplay else {
            throw RecordingError.noDisplay
        }
        
        selectedDisplay = targetDisplay
        
        // Configure stream
        let filter = createContentFilter(display: targetDisplay, content: content)
        let configuration = createStreamConfiguration(display: targetDisplay)
        
        // Setup asset writer with enhanced settings
        try setupAssetWriter(url: url, configuration: configuration)
        
        // Create enhanced stream output
        guard let assetWriter = assetWriter,
              let videoInput = videoInput else {
            throw RecordingError.setupFailed
        }
        
        streamOutput = EnhancedRecordingStreamOutput(
            assetWriter: assetWriter,
            videoInput: videoInput,
            audioInput: audioInput,
            options: recordingOptions
        )
        
        // Create and configure stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        guard let stream = stream,
              let streamOutput = streamOutput else {
            throw RecordingError.setupFailed
        }
        
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        
        // Add audio if enabled
        if recordingOptions.includeAudio {
            try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))
        }
    }
    
    private func createContentFilter(display: SCDisplay, content: SCShareableContent) -> SCContentFilter {
        var excludedWindows: [SCWindow] = []
        
        // Exclude our own app and other specified apps
        if recordingOptions.excludeSelf {
            excludedWindows.append(contentsOf: content.windows.filter { window in
                window.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
            })
        }
        
        // Add custom excluded apps
        excludedWindows.append(contentsOf: content.windows.filter { window in
            guard let bundleId = window.owningApplication?.bundleIdentifier else { return false }
            return recordingOptions.excludedApps.contains(bundleId)
        })
        
        return SCContentFilter(display: display, excludingWindows: excludedWindows)
    }
    
    private func createStreamConfiguration(display: SCDisplay) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let settings = recordingQualitySettings.settings(for: recordingQuality, display: display)
        
        configuration.width = settings.width
        configuration.height = settings.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: settings.frameRate)
        configuration.queueDepth = settings.queueDepth
        configuration.showsCursor = recordingOptions.showCursor
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        
        if #available(macOS 14.0, *) {
            configuration.captureResolution = settings.captureResolution
        }
        
        return configuration
    }
    
    private func setupAssetWriter(url: URL, configuration: SCStreamConfiguration) throws {
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        
        guard let assetWriter = assetWriter else {
            throw RecordingError.setupFailed
        }
        
        // Video input setup
        let videoSettings = recordingQualitySettings.videoSettings(
            for: recordingQuality,
            width: configuration.width,
            height: configuration.height
        )
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        videoInput?.transform = .identity
        
        if let videoInput = videoInput, assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)
        } else {
            throw RecordingError.setupFailed
        }
        
        // Audio input setup (if enabled)
        if recordingOptions.includeAudio {
            let audioSettings = recordingQualitySettings.audioSettings()
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            
            if let audioInput = audioInput, assetWriter.canAdd(audioInput) {
                assetWriter.add(audioInput)
            }
        }
    }
    
    private func beginRecording() async throws {
        guard let stream = stream,
              let assetWriter = assetWriter else {
            throw RecordingError.setupFailed
        }
        
        assetWriter.startWriting()
        
        try await stream.startCapture()
        
        isRecording = true
        startTime = Date()
        recordingDuration = 0
    }
    
    private func finishRecording() async throws {
        // Stop stream
        try await stream?.stopCapture()
        stream = nil
        
        // Finish video input
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        // Finish writing
        await assetWriter?.finishWriting()
        
        // Cleanup
        cleanup()
    }
    
    private func optimizeRecording(at url: URL) async throws {
        // Implement video optimization/compression
        // This could include:
        // - Re-encoding for better compression
        // - Removing unused audio channels
        // - Optimizing metadata
        
        let optimizedURL = url.appendingPathExtension("optimized")
        
        // For now, just move the file (placeholder for actual optimization)
        try FileManager.default.moveItem(at: url, to: optimizedURL)
        try FileManager.default.moveItem(at: optimizedURL, to: url)
    }
    
    private func applyQualityChanges() async throws {
        // Update stream configuration during recording
        guard let stream = stream,
              let display = selectedDisplay else { return }
        
        let newConfiguration = createStreamConfiguration(display: display)
        
        // Note: In a real implementation, you might need to restart the stream
        // or use dynamic configuration updates if available
    }
    
    // MARK: - Timer Management
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
                
                // Update estimated file size
                self.estimatedFileSize = self.estimateFileSize(
                    duration: self.recordingDuration,
                    quality: self.recordingQuality
                )
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startPreviewGeneration() {
        previewTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.generatePreview()
        }
    }
    
    private func stopPreviewGeneration() {
        previewTimer?.invalidate()
        previewTimer = nil
    }
    
    private func generatePreview() {
        // Generate a preview frame from current recording
        // This is a simplified implementation
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                if let display = selectedDisplay ?? content.displays.first {
                    // Create a quick screenshot for preview
                    // In a real implementation, you'd extract a frame from the recording stream
                    await MainActor.run {
                        // Update preview (placeholder)
                        self.recordingPreview = nil
                    }
                }
            } catch {
                // Handle preview generation error silently
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func updateRecordingStatus(_ status: RecordingStatus) {
        recordingStatus = status
        
        switch status {
        case .idle, .completed, .failed:
            isRecording = false
        case .recording:
            isRecording = true
        default:
            break
        }
    }
    
    private func cleanup() {
        streamOutput = nil
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        outputURL = nil
        recordingPreview = nil
        estimatedFileSize = 0
    }
}

// MARK: - SCStreamDelegate

extension ScreenRecordingService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.updateRecordingStatus(.failed(error))
            print("🔴 Recording stream stopped with error: \(error)")
        }
    }
}

// MARK: - Enhanced Supporting Types

enum RecordingStatus: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case finalizing
    case optimizing
    case completed
    case failed(Error)
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .preparing: return "Preparing..."
        case .recording: return "Recording"
        case .paused: return "Paused"
        case .finalizing: return "Finalizing..."
        case .optimizing: return "Optimizing..."
        case .completed: return "Completed"
        case .failed: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .secondary
        case .preparing: return .orange
        case .recording: return .red
        case .paused: return .yellow
        case .finalizing, .optimizing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    // Equatable conformance
    static func == (lhs: RecordingStatus, rhs: RecordingStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.recording, .recording), 
             (.paused, .paused), (.finalizing, .finalizing), (.optimizing, .optimizing), 
             (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

enum RecordingQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    var displayName: String {
        switch self {
        case .low: return "Low (720p)"
        case .medium: return "Medium (1080p)"
        case .high: return "High (1440p)"
        case .ultra: return "Ultra (4K)"
        }
    }
}

struct RecordingOptions {
    var quality: RecordingQuality = .high
    var includeAudio: Bool = false
    var showCursor: Bool = true
    var excludeSelf: Bool = true
    var excludedApps: [String] = []
    var frameRate: Int32 = 30
}

// MARK: - Recording Stream Output

private final class RecordingStreamOutput: NSObject, SCStreamOutput {
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private var sessionStarted = false
    private var firstTimestamp: CMTime?
    private let lock = NSLock()

    init(assetWriter: AVAssetWriter, videoInput: AVAssetWriterInput, width: Int, height: Int) {
        self.assetWriter = assetWriter
        self.videoInput = videoInput

        // Create pixel buffer adaptor for proper format conversion
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        // Check if the sample buffer is valid
        guard CMSampleBufferIsValid(sampleBuffer) else { return }

        // Get the pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lock.lock()
        defer { lock.unlock() }

        guard assetWriter.status == .writing else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if !sessionStarted {
            firstTimestamp = timestamp
            assetWriter.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        // Calculate relative timestamp
        guard let firstTS = firstTimestamp else { return }
        let relativeTime = CMTimeSubtract(timestamp, firstTS)

        if videoInput.isReadyForMoreMediaData {
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: relativeTime)
        }
    }
}

// MARK: - Enhanced Recording Stream Output

private final class EnhancedRecordingStreamOutput: NSObject, SCStreamOutput {
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private let options: RecordingOptions
    
    private var sessionStarted = false
    private var firstTimestamp: CMTime?
    private var frameCount: Int64 = 0
    private let lock = NSLock()
    
    // Performance monitoring
    private var droppedFrames: Int = 0
    private var lastFrameTime: CMTime?

    init(assetWriter: AVAssetWriter, videoInput: AVAssetWriterInput, audioInput: AVAssetWriterInput?, options: RecordingOptions) {
        self.assetWriter = assetWriter
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.options = options

        // Create enhanced pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(videoInput.naturalSize.width),
            kCVPixelBufferHeightKey as String: Int(videoInput.naturalSize.height),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        lock.lock()
        defer { lock.unlock() }
        
        guard assetWriter.status == .writing else { return }
        guard CMSampleBufferIsValid(sampleBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if !sessionStarted {
            firstTimestamp = timestamp
            assetWriter.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        guard let firstTS = firstTimestamp else { return }
        let relativeTime = CMTimeSubtract(timestamp, firstTS)

        switch type {
        case .screen:
            handleVideoSample(sampleBuffer, timestamp: relativeTime)
        case .audio:
            handleAudioSample(sampleBuffer, timestamp: relativeTime)
        @unknown default:
            break
        }
    }
    
    private func handleVideoSample(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Frame rate control
        if let lastTime = lastFrameTime {
            let expectedInterval = CMTime(value: 1, timescale: options.frameRate)
            let actualInterval = CMTimeSubtract(timestamp, lastTime)
            
            if CMTimeCompare(actualInterval, expectedInterval) < 0 {
                // Skip frame to maintain target frame rate
                droppedFrames += 1
                return
            }
        }
        
        if videoInput.isReadyForMoreMediaData {
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: timestamp)
            frameCount += 1
            lastFrameTime = timestamp
        } else {
            droppedFrames += 1
        }
    }
    
    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else { return }
        
        audioInput.append(sampleBuffer)
    }
    
    // Performance metrics
    var performanceMetrics: RecordingPerformanceMetrics {
        RecordingPerformanceMetrics(
            frameCount: frameCount,
            droppedFrames: droppedFrames,
            dropRate: frameCount > 0 ? Double(droppedFrames) / Double(Int(frameCount) + droppedFrames) : 0
        )
    }
}

// MARK: - Recording Quality Manager

private final class RecordingQualityManager {
    
    func settings(for quality: RecordingQuality, display: SCDisplay?) -> RecordingSettings {
        let displayWidth = display?.width ?? 1920
        let displayHeight = display?.height ?? 1080
        
        switch quality {
        case .low:
            return RecordingSettings(
                width: min(1280, Int(displayWidth)),
                height: min(720, Int(displayHeight)),
                frameRate: 30,
                bitRate: 5_000_000,
                queueDepth: 3
            )
        case .medium:
            return RecordingSettings(
                width: min(1920, Int(displayWidth)),
                height: min(1080, Int(displayHeight)),
                frameRate: 30,
                bitRate: 8_000_000,
                queueDepth: 4
            )
        case .high:
            return RecordingSettings(
                width: min(2560, Int(displayWidth)),
                height: min(1440, Int(displayHeight)),
                frameRate: 60,
                bitRate: 15_000_000,
                queueDepth: 5
            )
        case .ultra:
            return RecordingSettings(
                width: Int(displayWidth),
                height: Int(displayHeight),
                frameRate: 60,
                bitRate: 25_000_000,
                queueDepth: 6
            )
        }
    }
    
    func videoSettings(for quality: RecordingQuality, width: Int, height: Int) -> [String: Any] {
        let settings = self.settings(for: quality, display: nil)
        
        return [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.bitRate,
                AVVideoExpectedSourceFrameRateKey: settings.frameRate,
                AVVideoMaxKeyFrameIntervalKey: Int(settings.frameRate) * 2,
                AVVideoQualityKey: qualityValue(for: quality),
                AVVideoAllowFrameReorderingKey: true
            ]
        ]
    }
    
    func audioSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
    }
    
    func estimateFileSize(duration: TimeInterval, quality: RecordingQuality, display: SCDisplay?) -> Int64 {
        let settings = self.settings(for: quality, display: display)
        let videoBitRate = Double(settings.bitRate)
        let audioBitRate: Double = 128000 // 128 kbps audio
        
        let totalBitRate = videoBitRate + audioBitRate
        let estimatedBytes = (totalBitRate * duration) / 8 // Convert bits to bytes
        
        return Int64(estimatedBytes)
    }
    
    private func qualityValue(for quality: RecordingQuality) -> Double {
        switch quality {
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.7
        case .ultra: return 0.9
        }
    }
}

// MARK: - Supporting Structures

private struct RecordingSettings {
    let width: Int
    let height: Int
    let frameRate: Int32
    let bitRate: Int
    let queueDepth: Int
    
    @available(macOS 14.0, *)
    var captureResolution: SCCaptureResolutionType {
        return .automatic
    }
}

struct RecordingPerformanceMetrics {
    let frameCount: Int64
    let droppedFrames: Int
    let dropRate: Double
    
    var isPerformanceGood: Bool {
        dropRate < 0.05 // Less than 5% drop rate is considered good
    }
}
