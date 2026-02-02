import Foundation
import AVFoundation
import ScreenCaptureKit
import SwiftUI
import Combine

@MainActor
final class CaptureService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isCapturing = false
    @Published private(set) var captureProgress: Double = 0.0
    @Published private(set) var lastCaptureMetrics: CaptureMetrics?
    
    // MARK: - Private Properties

    private var captureStream: SCStream?
    private var capturedImage: CGImage?
    private var captureCompletion: ((Result<Data, Error>) -> Void)?
    private let performanceMonitor = CapturePerformanceMonitor()
    private let imageProcessor = CaptureImageProcessor()
    private let cacheManager = CaptureCache()

    // Capture settings with performance optimizations
    var scaleFactor: Double {
        let saved = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.captureScaleFactor)
        return saved > 0 ? saved : Constants.CaptureQuality.defaultScaleFactor
    }

    var captureDPI: Int {
        let saved = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.captureDPI)
        return saved > 0 ? saved : Constants.CaptureQuality.defaultDPI
    }
    
    // Performance optimization settings
    private var useHardwareAcceleration: Bool {
        UserDefaults.standard.bool(forKey: "UseHardwareAcceleration")
    }
    
    private var enableCaching: Bool {
        UserDefaults.standard.bool(forKey: "EnableCaching")
    }

    // MARK: - Public Methods

    func capture(type: CaptureType, options: CaptureOptions = CaptureOptions()) async throws -> CaptureResult {
        guard !isCapturing else {
            throw CaptureError.captureInProgress
        }
        
        isCapturing = true
        captureProgress = 0.0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isCapturing = false
            captureProgress = 1.0
        }
        
        do {
            // Don't pre-check permission - CGPreflightScreenCaptureAccess is unreliable
            // Instead, let the capture fail naturally and handle the error
            captureProgress = 0.1
            
            let data: Data
            let metadata: CaptureMetadata
            
            switch type {
            case .fullScreen:
                (data, metadata) = try await captureFullScreenOptimized(options: options)
            case .selectedArea:
                (data, metadata) = try await captureWithScreencaptureOptimized(arguments: ["-i", "-x"], options: options)
            case .activeWindow:
                (data, metadata) = try await captureWithScreencaptureOptimized(arguments: ["-i", "-w", "-x"], options: options)
            }
            
            captureProgress = 0.9
            
            // Post-process if needed
            let finalData = try await postProcessCapture(data: data, options: options)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            let metrics = CaptureMetrics(
                captureType: type,
                duration: duration,
                dataSize: Int64(finalData.count),
                resolution: metadata.resolution,
                scaleFactor: scaleFactor,
                useHardwareAcceleration: useHardwareAcceleration
            )
            
            lastCaptureMetrics = metrics
            performanceMonitor.recordCapture(metrics)
            
            captureProgress = 1.0
            
            return CaptureResult(
                data: finalData,
                metadata: metadata,
                metrics: metrics
            )
            
        } catch {
            captureProgress = 0.0
            throw error
        }
    }
    
    /// Optimized batch capture for multiple screenshots
    func batchCapture(
        type: CaptureType,
        count: Int,
        interval: TimeInterval = 1.0,
        options: CaptureOptions = CaptureOptions()
    ) async throws -> [CaptureResult] {
        var results: [CaptureResult] = []
        
        for i in 0..<count {
            do {
                let result = try await capture(type: type, options: options)
                results.append(result)
                
                if i < count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            } catch {
                // Continue with other captures even if one fails
                print("Batch capture failed at index \(i): \(error)")
            }
        }
        
        return results
    }

    // MARK: - ScreenCaptureKit Full Screen (Optimized)

    private func captureFullScreenOptimized(options: CaptureOptions) async throws -> (Data, CaptureMetadata) {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        // Use cached filter if available for better performance
        let filter = cacheManager.getCachedFilter(for: display) ?? SCContentFilter(display: display, excludingWindows: [])
        if cacheManager.getCachedFilter(for: display) == nil {
            cacheManager.cacheFilter(filter, for: display)
        }

        let config = createOptimizedStreamConfiguration(display: display, options: options)
        
        captureProgress = 0.3

        return try await withCheckedThrowingContinuation { continuation in
            self.captureCompletion = { result in
                switch result {
                case .success(let data):
                    let metadata = CaptureMetadata(
                        captureTime: Date(),
                        resolution: CGSize(width: config.width, height: config.height),
                        scaleFactor: self.scaleFactor,
                        dpi: self.captureDPI,
                        display: display
                    )
                    continuation.resume(returning: (data, metadata))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            self.captureStream = stream

            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
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
    
    private func createOptimizedStreamConfiguration(display: SCDisplay, options: CaptureOptions) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        
        // Optimize resolution based on system capabilities
        let optimalWidth = Int(Double(display.width) * scaleFactor)
        let optimalHeight = Int(Double(display.height) * scaleFactor)
        
        config.width = optimalWidth
        config.height = optimalHeight
        config.pixelFormat = useHardwareAcceleration ? kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange : kCVPixelFormatType_32BGRA
        config.showsCursor = options.showCursor
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 1
        
        // Use hardware acceleration if available
        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }
        
        return config
    }

    private func pngDataOptimized(from image: CGImage) async -> Data? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let bitmapRep = NSBitmapImageRep(cgImage: image)

                // Set DPI metadata for maximum quality
                let dpi = CGFloat(self.captureDPI)
                bitmapRep.setProperty(.init(rawValue: "DPIWidth"), withValue: dpi)
                bitmapRep.setProperty(.init(rawValue: "DPIHeight"), withValue: dpi)

                // PNG is lossless, no compression factor needed for best quality
                let data = bitmapRep.representation(using: .png, properties: [:])
                continuation.resume(returning: data)
            }
        }
    }

    private func stopCapture() {
        captureStream?.stopCapture { _ in }
        captureStream = nil
    }

    // MARK: - Screencapture Helper (Optimized)

    nonisolated private func captureWithScreencaptureOptimized(
        arguments: [String],
        options: CaptureOptions
    ) async throws -> (Data, CaptureMetadata) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")

        var args = arguments
        args.append(tempURL.path)

        // Add performance optimizations
        if options.highPerformance {
            args.append("-C") // Capture cursor
        }

        // Get user settings
        let userScaleFactor = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.captureScaleFactor)
        let userDPI = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.captureDPI)
        let finalScaleFactor = userScaleFactor > 0 ? userScaleFactor : Constants.CaptureQuality.defaultScaleFactor
        let finalDPI = userDPI > 0 ? userDPI : Constants.CaptureQuality.defaultDPI

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = args
                task.qualityOfService = .userInitiated

                let errorPipe = Pipe()
                task.standardError = errorPipe

                do {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    try task.run()
                    task.waitUntilExit()
                    let endTime = CFAbsoluteTimeGetCurrent()

                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        do {
                            var data = try Data(contentsOf: tempURL)
                            try? FileManager.default.removeItem(at: tempURL)

                            if data.count > 100 {
                                // Apply user's scale factor and DPI settings
                                if let processedData = self.applyQualitySettings(
                                    to: data,
                                    scaleFactor: finalScaleFactor,
                                    dpi: finalDPI
                                ) {
                                    data = processedData
                                }

                                // Get actual resolution from processed image
                                var resolution = CGSize.zero
                                if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                                   let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
                                   let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                                   let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                                    resolution = CGSize(width: width, height: height)
                                }

                                let metadata = CaptureMetadata(
                                    captureTime: Date(),
                                    resolution: resolution,
                                    scaleFactor: finalScaleFactor,
                                    dpi: finalDPI,
                                    display: nil,
                                    captureMethod: .screencapture,
                                    processingTime: endTime - startTime
                                )
                                continuation.resume(returning: (data, metadata))
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

    /// Apply scale factor and DPI to captured image
    nonisolated private func applyQualitySettings(to data: Data, scaleFactor: Double, dpi: Int) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        let originalWidth = cgImage.width
        let originalHeight = cgImage.height

        // Calculate new size based on scale factor
        let newWidth = Int(Double(originalWidth) * scaleFactor)
        let newHeight = Int(Double(originalHeight) * scaleFactor)

        // Create scaled image
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Use high quality interpolation for scaling
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let scaledImage = context.makeImage() else {
            return nil
        }

        // Convert to PNG with DPI metadata
        let bitmapRep = NSBitmapImageRep(cgImage: scaledImage)

        // Set DPI
        let dpiValue = CGFloat(dpi)
        bitmapRep.setProperty(.init(rawValue: "DPIWidth"), withValue: dpiValue)
        bitmapRep.setProperty(.init(rawValue: "DPIHeight"), withValue: dpiValue)

        // PNG with no compression for best quality
        return bitmapRep.representation(using: .png, properties: [:])
    }
    
    // MARK: - Post-Processing
    
    private func postProcessCapture(data: Data, options: CaptureOptions) async throws -> Data {
        guard options.enablePostProcessing else { return data }
        
        return try await imageProcessor.processImage(data: data, options: options)
    }
    
    // MARK: - Performance Monitoring
    
    func getPerformanceReport() -> PerformanceReport {
        return performanceMonitor.generateReport()
    }
    
    func clearPerformanceData() {
        performanceMonitor.clearData()
        lastCaptureMetrics = nil
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
        
        // Use hardware acceleration setting from UserDefaults directly
        let useHardware = UserDefaults.standard.bool(forKey: "UseHardwareAcceleration")
        let context = CIContext(options: [.useSoftwareRenderer: !useHardware])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor in
            self.captureProgress = 0.7
            
            let data: Data?
            if useHardware {
                data = await self.pngDataOptimized(from: cgImage)
            } else {
                // Fallback to synchronous processing
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                let dpi = CGFloat(self.captureDPI)
                bitmapRep.setProperty(.init(rawValue: "DPIWidth"), withValue: dpi)
                bitmapRep.setProperty(.init(rawValue: "DPIHeight"), withValue: dpi)
                data = bitmapRep.representation(using: .png, properties: [:])
            }
            
            if let data = data {
                self.captureCompletion?(.success(data))
            } else {
                self.captureCompletion?(.failure(CaptureError.captureFailed))
            }
            self.captureCompletion = nil
            self.stopCapture()
        }
    }
}

// MARK: - Supporting Types

struct CaptureOptions {
    var showCursor: Bool = true
    var highPerformance: Bool = false
    var enablePostProcessing: Bool = false
    var compressionQuality: Double = 0.8
    var useHardwareAcceleration: Bool = true
}

struct CaptureResult {
    let data: Data
    let metadata: CaptureMetadata
    let metrics: CaptureMetrics
}

struct CaptureMetadata {
    let captureTime: Date
    let resolution: CGSize
    let scaleFactor: Double
    let dpi: Int
    let display: SCDisplay?
    var captureMethod: CaptureMethod = .screenCaptureKit
    var processingTime: Double = 0
}

enum CaptureMethod {
    case screenCaptureKit
    case screencapture
}

struct CaptureMetrics {
    let captureType: CaptureType
    let duration: Double
    let dataSize: Int64
    let resolution: CGSize
    let scaleFactor: Double
    let useHardwareAcceleration: Bool
    
    var throughput: Double {
        guard duration > 0 else { return 0 }
        return Double(dataSize) / duration
    }
    
    var pixelsPerSecond: Double {
        guard duration > 0 else { return 0 }
        let totalPixels = resolution.width * resolution.height
        return totalPixels / duration
    }
}

// MARK: - Performance Monitoring Classes

private final class CapturePerformanceMonitor {
    private var captureHistory: [CaptureMetrics] = []
    private let maxHistorySize = 100
    
    func recordCapture(_ metrics: CaptureMetrics) {
        captureHistory.append(metrics)
        
        if captureHistory.count > maxHistorySize {
            captureHistory.removeFirst()
        }
    }
    
    func generateReport() -> PerformanceReport {
        guard !captureHistory.isEmpty else {
            return PerformanceReport.empty
        }
        
        let totalDuration = captureHistory.reduce(0) { $0 + $1.duration }
        let averageDuration = totalDuration / Double(captureHistory.count)
        
        let totalSize = captureHistory.reduce(0) { $0 + $1.dataSize }
        let averageSize = totalSize / Int64(captureHistory.count)
        
        let averageThroughput = captureHistory.reduce(0) { $0 + $1.throughput } / Double(captureHistory.count)
        
        return PerformanceReport(
            totalCaptures: captureHistory.count,
            averageDuration: averageDuration,
            averageSize: averageSize,
            averageThroughput: averageThroughput,
            fastestCapture: captureHistory.min { $0.duration < $1.duration }?.duration ?? 0,
            slowestCapture: captureHistory.max { $0.duration < $1.duration }?.duration ?? 0
        )
    }
    
    func clearData() {
        captureHistory.removeAll()
    }
}

private final class CaptureImageProcessor {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    func processImage(data: Data, options: CaptureOptions) async throws -> Data {
        guard let image = CIImage(data: data) else {
            return data
        }
        
        var processedImage = image
        
        // Apply optimizations based on content
        if options.enablePostProcessing {
            // Noise reduction for low-light captures
            processedImage = processedImage.applyingFilter("CINoiseReduction")
            
            // Sharpening for text-heavy content
            processedImage = processedImage.applyingFilter("CISharpenLuminance", parameters: [
                "inputSharpness": 0.4
            ])
        }
        
        guard let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) else {
            return data
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:]) ?? data
    }
    
    func calculateOptimalCompression(for image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        let totalPixels = width * height
        
        // Larger images can use more compression
        switch totalPixels {
        case 0..<500_000: return 1.0 // Small images: no compression
        case 500_000..<2_000_000: return 0.9 // Medium images: light compression
        case 2_000_000..<8_000_000: return 0.8 // Large images: moderate compression
        default: return 0.7 // Very large images: aggressive compression
        }
    }
}

private final class CaptureCache {
    private var filterCache: [String: SCContentFilter] = [:]
    private let cacheQueue = DispatchQueue(label: "capture.cache", qos: .utility)
    
    func getCachedFilter(for display: SCDisplay) -> SCContentFilter? {
        let key = "\(display.displayID)"
        return cacheQueue.sync {
            return filterCache[key]
        }
    }
    
    func cacheFilter(_ filter: SCContentFilter, for display: SCDisplay) {
        let key = "\(display.displayID)"
        cacheQueue.async {
            self.filterCache[key] = filter
        }
    }
    
    func clearCache() {
        cacheQueue.async {
            self.filterCache.removeAll()
        }
    }
}

struct PerformanceReport {
    let totalCaptures: Int
    let averageDuration: Double
    let averageSize: Int64
    let averageThroughput: Double
    let fastestCapture: Double
    let slowestCapture: Double
    
    static var empty: PerformanceReport {
        PerformanceReport(
            totalCaptures: 0,
            averageDuration: 0,
            averageSize: 0,
            averageThroughput: 0,
            fastestCapture: 0,
            slowestCapture: 0
        )
    }
    
    var formattedAverageDuration: String {
        String(format: "%.3f s", averageDuration)
    }
    
    var formattedAverageSize: String {
        ByteCountFormatter.string(fromByteCount: averageSize, countStyle: .file)
    }
    
    var formattedThroughput: String {
        ByteCountFormatter.string(fromByteCount: Int64(averageThroughput), countStyle: .file) + "/s"
    }
}
