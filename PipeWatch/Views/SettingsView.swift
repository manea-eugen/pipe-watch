import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    let onSave: () -> Void

    @State private var tokenInput: String = ""
    @State private var instanceInput: String = ""
    @State private var showToken: Bool = false
    @State private var saved: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    appState.showingSettings = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // GitLab Instance
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitLab Instance URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("https://gitlab.com", text: $instanceInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                // Token
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Access Token")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        if showToken {
                            TextField("glpat-xxxxxxxxxxxxxxxxxxxx", text: $tokenInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        } else {
                            SecureField("glpat-xxxxxxxxxxxxxxxxxxxx", text: $tokenInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }

                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                    }

                    Text("Needs `read_api` scope. [Create one in GitLab](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Polling Interval
                VStack(alignment: .leading, spacing: 4) {
                    Text("Polling Interval: \(Int(appState.pollingInterval))s")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Slider(value: $appState.pollingInterval, in: 10...120, step: 5) {
                        Text("Interval")
                    }
                }

                // Notification toggles
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Toggle("Notify on pipeline success", isOn: $appState.notifyOnSuccess)
                        .font(.system(size: 12))
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    Toggle("Notify on pipeline failure", isOn: $appState.notifyOnFailure)
                        .font(.system(size: 12))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                // Launch at login
                VStack(alignment: .leading, spacing: 6) {
                    Text("System")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Toggle("Launch at login", isOn: $appState.launchAtLogin)
                        .font(.system(size: 12))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                Divider()

                // Save button
                HStack {
                    Spacer()

                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }

                    Button("Save & Reconnect") {
                        appState.gitlabInstanceURL = instanceInput
                        appState.token = tokenInput
                        saved = true
                        onSave()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saved = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(tokenInput.isEmpty || instanceInput.isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 360)
        .onAppear {
            tokenInput = appState.token
            instanceInput = appState.gitlabInstanceURL
        }
    }
}
