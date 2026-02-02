import ScreenCaptureKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @Namespace private var namespace

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 580, height: 520)
        .background {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.1),
                    Color.clear,
                    Color.accentColor.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @Namespace private var glassNamespace

    private var scaleFactorDescription: String {
        switch viewModel.captureScaleFactor {
        case 1.0:
            return "Standard resolution (1:1 with screen pixels)"
        case 1.5:
            return "1.5x resolution - Good balance of quality and file size"
        case 2.0:
            return "Retina quality (2x) - Recommended for most uses"
        case 3.0:
            return "3x resolution - High quality for detailed screenshots"
        case 4.0:
            return "4x resolution - Maximum quality, larger file sizes"
        default:
            return "Custom resolution scale"
        }
    }

    private var dpiDescription: String {
        switch viewModel.captureDPI {
        case 72:
            return "72 DPI - Standard screen resolution"
        case 144:
            return "144 DPI - Retina display quality (recommended)"
        case 216:
            return "216 DPI - High quality for presentations"
        case 288:
            return "288 DPI - Very high quality"
        case 300:
            return "300 DPI - Print quality"
        default:
            return "Custom DPI setting"
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Save Location Section with Glass Effect
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                        Text("Save Location")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                if let path = viewModel.selectedFolderURL?.path {
                                    Text(path)
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                } else {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("No folder selected")
                                            .foregroundColor(.orange)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Button("Choose Folder...") {
                                    Task {
                                        await viewModel.selectFolder()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                if viewModel.selectedFolderURL != nil {
                                    Button("Reveal in Finder") {
                                        viewModel.revealFolderInFinder()
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    }
                }

                // Capture Quality Section with Glass Effect
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "camera.aperture")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Capture Quality")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Scale Factor with enhanced UI
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Resolution Scale", systemImage: "viewfinder.rectangular")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            Picker("", selection: $viewModel.captureScaleFactor) {
                                ForEach(
                                    Constants.CaptureQuality.scaleFactors,
                                    id: \.self
                                ) { scale in
                                    Text("\(scale, specifier: "%.1f")×").tag(scale)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text(scaleFactorDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }

                        Divider()
                            .overlay(Color.accentColor.opacity(0.3))

                        // DPI with enhanced UI
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("DPI (Dots Per Inch)", systemImage: "grid.circle")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            HStack {
                                Picker("", selection: $viewModel.captureDPI) {
                                    ForEach(
                                        Constants.CaptureQuality.dpiOptions,
                                        id: \.self
                                    ) { dpi in
                                        Text("\(dpi) DPI").tag(dpi)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 140)

                                Spacer()
                            }
                            
                            Text(dpiDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    }
                }

                // Startup Section with Glass Effect
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "power")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Startup")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch at Login")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Start SuretiShot automatically when you log in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.launchAtLogin)
                            .toggleStyle(.switch)
                            .scaleEffect(0.9)
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .background {
            // Subtle animated background
            ZStack {
                Color.clear
                
                // Floating glass orbs for ambient effect
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                    .offset(x: -100, y: -50)
                
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .blur(radius: 25)
                    .offset(x: 120, y: 100)
            }
        }
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @Namespace private var shortcutsNamespace
    @State private var animateShortcuts = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Screenshots Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .foregroundColor(.purple)
                            .font(.title2)
                        Text("Screenshots")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(spacing: 16) {
                        ShortcutRow(
                            title: "Capture Full Screen",
                            subtitle: "Take a screenshot of the entire screen",
                            shortcut: viewModel.captureFullScreenShortcut,
                            action: .captureFullScreen,
                            icon: "rectangle.on.rectangle",
                            color: .blue
                        )

                        Divider()
                            .padding(.horizontal, 8)

                        ShortcutRow(
                            title: "Capture Selected Area",
                            subtitle: "Select an area to capture",
                            shortcut: viewModel.captureAreaShortcut,
                            action: .captureArea,
                            icon: "viewfinder.rectangular",
                            color: .orange
                        )

                        Divider()
                            .padding(.horizontal, 8)

                        ShortcutRow(
                            title: "Capture Active Window",
                            subtitle: "Capture the currently focused window",
                            shortcut: viewModel.captureWindowShortcut,
                            action: .captureWindow,
                            icon: "macwindow",
                            color: .green
                        )
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    }
                }

                // Recording Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "video.circle")
                            .foregroundColor(.red)
                            .font(.title2)
                        Text("Recording")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(spacing: 16) {
                        ShortcutRow(
                            title: "Start Recording",
                            subtitle: "Begin screen recording",
                            shortcut: viewModel.startRecordingShortcut,
                            action: .startRecording,
                            icon: "record.circle",
                            color: .red
                        )

                        Divider()
                            .padding(.horizontal, 8)

                        ShortcutRow(
                            title: "Stop Recording",
                            subtitle: "End screen recording",
                            shortcut: viewModel.stopRecordingShortcut,
                            action: .stopRecording,
                            icon: "stop.circle",
                            color: .red
                        )
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    }
                }

                // Reset Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button("Reset to Defaults") {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                viewModel.resetShortcutsToDefault()
                                animateShortcuts = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                animateShortcuts = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.secondary)
                        .scaleEffect(animateShortcuts ? 1.05 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateShortcuts)
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Global shortcuts work system-wide")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .opacity(0.7)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .background {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.05),
                    Color.red.opacity(0.03),
                    Color.blue.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct ShortcutRow: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    let title: String
    let subtitle: String
    let shortcut: KeyboardShortcut?
    let action: ShortcutAction
    let icon: String
    let color: Color

    @State private var isRecording = false
    @State private var conflictWarning: String?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 24, height: 24)
                
                // Title and Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Shortcut Recorder
                ShortcutRecorderView(
                    shortcut: shortcut,
                    isRecording: $isRecording,
                    onShortcutRecorded: { newShortcut in
                        if let conflict = viewModel.hasConflict(
                            newShortcut,
                            excluding: action
                        ) {
                            conflictWarning = "Conflicts with \(conflict.rawValue)"
                        } else if viewModel.isShortcutReserved(newShortcut) {
                            conflictWarning = "Reserved by macOS"
                        } else {
                            conflictWarning = nil
                            viewModel.updateShortcut(newShortcut, for: action)
                        }
                    },
                    onClear: {
                        conflictWarning = nil
                        viewModel.updateShortcut(nil, for: action)
                    }
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            }

            // Conflict Warning
            if let warning = conflictWarning {
                HStack {
                    Spacer()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var isRequestingPermission = false
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("Permissions") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screen Recording")
                            .font(.headline)

                        Text(
                            viewModel.hasScreenCapturePermission
                                ? "Granted" : "Not granted"
                        )
                        .font(.caption)
                        .foregroundColor(
                            viewModel.hasScreenCapturePermission ? .green : .red
                        )

                        if !viewModel.hasScreenCapturePermission {
                            Text(
                                "Required for capturing screenshots and recordings"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !viewModel.hasScreenCapturePermission {
                        VStack(spacing: 8) {
                            Button("Request Permission") {
                                Task {
                                    isRequestingPermission = true
                                    let granted =
                                        await viewModel
                                        .requestScreenCapturePermission()
                                    isRequestingPermission = false

                                    if !granted {
                                        // If not granted after request, show system settings
                                        viewModel.openScreenRecordingSettings()
                                    }

                                    // Force refresh after a delay to catch system changes
                                    DispatchQueue.main.asyncAfter(
                                        deadline: .now() + 2.0
                                    ) {
                                        Task {
                                            await viewModel
                                                .forceRefreshPermissions()
                                        }
                                    }
                                }
                            }
                            .disabled(isRequestingPermission)

                            Button("Open Settings") {
                                viewModel.openScreenRecordingSettings()

                                // Start polling for permission changes
                                startPermissionPolling()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)

                            Button("Refresh Status") {
                                Task {
                                    await viewModel.forceRefreshPermissions()
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                            Button("Test Capture") {
                                Task {
                                    NSLog(
                                        "🧪 SuretiShot: Starting test capture..."
                                    )
                                    do {
                                        let content =
                                            try await SCShareableContent
                                            .excludingDesktopWindows(
                                                false,
                                                onScreenWindowsOnly: true
                                            )
                                        print(
                                            "✅ Test capture successful! Displays: \(content.displays.count)"
                                        )
                                        NSLog(
                                            "✅ SuretiShot: Test capture successful! Displays: \(content.displays.count)"
                                        )
                                        await viewModel.forceRefreshPermissions()
                                    } catch {
                                        print("❌ Test capture failed: \(error)")
                                        NSLog(
                                            "❌ SuretiShot: Test capture failed: \(error)"
                                        )
                                        await viewModel.forceRefreshPermissions()
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption2)
                            .foregroundColor(.blue)
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                }
                .padding(8)
            }

            GroupBox("Privacy Information") {
                Text(PrivacyNote.screenCapture)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
            }

            Spacer()
        }
        .padding(20)
        .onAppear {
            print("🟢 SuretiShot: Privacy view appeared")
            NSLog("🟢 SuretiShot: Privacy view appeared")
            Task {
                await viewModel.forceRefreshPermissions()
            }
            startPermissionPolling()
        }
        .onDisappear {
            stopPermissionPolling()
        }
        .onChange(of: viewModel.hasScreenCapturePermission) { newValue in
            // Automatically refresh permission status when it changes
            if !newValue {
                Task {
                    await viewModel.forceRefreshPermissions()
                }
            } else {
                // Permission granted, stop polling
                stopPermissionPolling()
            }
        }
    }

    private func startPermissionPolling() {
        print("🔄 SuretiShot: Starting permission polling...")
        NSLog("🔄 SuretiShot: Starting permission polling...")
        stopPermissionPolling()

        // More frequent checking when permission is missing
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { _ in
            print("⏰ SuretiShot: Polling timer fired")
            NSLog("⏰ SuretiShot: Polling timer fired")
            Task {
                await viewModel.forceRefreshPermissions()
            }
        }
    }

    private func stopPermissionPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - About View

struct AboutView: View {
    @State private var isAnimating = false
    @State private var showDetails = false
    
    var body: some View {
        ZStack {
            // Background with glass effect
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color.blue.opacity(0.08)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer(minLength: 40)

                    // App Icon with Glass Effect
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 120)
                                .shadow(color: .accentColor.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentColor, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                .animation(
                                    .spring(response: 2.0, dampingFraction: 0.6)
                                    .repeatForever(autoreverses: false),
                                    value: isAnimating
                                )
                        }
                        
                        VStack(spacing: 8) {
                            Text("SuretiShot")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .accentColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("Version 1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                    
                    // Description with Glass Container
                    VStack(spacing: 16) {
                        Text("Ultra-fast screen capture with AI-powered smart naming")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Feature highlights
                        VStack(spacing: 12) {
                            FeatureRow(icon: "bolt.fill", text: "Lightning fast capture", color: .yellow)
                            FeatureRow(icon: "brain", text: "AI-powered naming", color: .purple)
                            FeatureRow(icon: "eye", text: "OCR text recognition", color: .blue)
                            FeatureRow(icon: "shield.fill", text: "Privacy-first design", color: .green)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .opacity(showDetails ? 1 : 0)
                    .offset(y: showDetails ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.3), value: showDetails)
                    
                    // Technical Info
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "swift")
                                .foregroundColor(.orange)
                            Text("Built with Swift & SwiftUI")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "apple.logo")
                                .foregroundColor(.primary)
                            Text("Native macOS Application")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Sandbox Compliant & Secure")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .opacity(showDetails ? 1 : 0)
                    .offset(y: showDetails ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.5), value: showDetails)

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showDetails = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}
