import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

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
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Save Location Section
            GroupBox("Save Location") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let path = viewModel.selectedFolderURL?.path {
                                Text(path)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                            } else {
                                Text("No folder selected")
                                    .foregroundColor(.red)
                            }
                        }

                        Spacer()

                        Button("Choose Folder...") {
                            Task {
                                await viewModel.selectFolder()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if viewModel.selectedFolderURL != nil {
                        Button("Reveal in Finder") {
                            viewModel.revealFolderInFinder()
                        }
                    }
                }
                .padding(8)
            }

            // Startup Section
            GroupBox("Startup") {
                Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                    .padding(8)
            }

            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Screenshots") {
                VStack(spacing: 12) {
                    ShortcutRow(
                        title: "Capture Full Screen",
                        shortcut: viewModel.captureFullScreenShortcut,
                        action: .captureFullScreen
                    )

                    ShortcutRow(
                        title: "Capture Selected Area",
                        shortcut: viewModel.captureAreaShortcut,
                        action: .captureArea
                    )

                    ShortcutRow(
                        title: "Capture Active Window",
                        shortcut: viewModel.captureWindowShortcut,
                        action: .captureWindow
                    )
                }
                .padding(8)
            }

            GroupBox("Recording") {
                VStack(spacing: 12) {
                    ShortcutRow(
                        title: "Start Recording",
                        shortcut: viewModel.startRecordingShortcut,
                        action: .startRecording
                    )

                    ShortcutRow(
                        title: "Stop Recording",
                        shortcut: viewModel.stopRecordingShortcut,
                        action: .stopRecording
                    )
                }
                .padding(8)
            }

            Button("Reset to Defaults") {
                viewModel.resetShortcutsToDefault()
            }

            Spacer()
        }
        .padding(20)
    }
}

struct ShortcutRow: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    let title: String
    let shortcut: KeyboardShortcut?
    let action: ShortcutAction

    @State private var isRecording = false
    @State private var conflictWarning: String?

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 180, alignment: .leading)

            Spacer()

            ShortcutRecorderView(
                shortcut: shortcut,
                isRecording: $isRecording,
                onShortcutRecorded: { newShortcut in
                    if let conflict = viewModel.hasConflict(newShortcut, excluding: action) {
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
        }

        if let warning = conflictWarning {
            Text(warning)
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("Permissions") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screen Recording")
                            .font(.headline)

                        Text(viewModel.hasScreenCapturePermission ? "Granted" : "Not granted")
                            .font(.caption)
                            .foregroundColor(viewModel.hasScreenCapturePermission ? .green : .red)
                    }

                    Spacer()

                    if !viewModel.hasScreenCapturePermission {
                        Button("Open Settings") {
                            viewModel.openScreenRecordingSettings()
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
            Task {
                await viewModel.checkPermissions()
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("SuretiShot")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Ultra-fast screen capture with AI-powered smart naming")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Text("Built with Swift and SwiftUI")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
