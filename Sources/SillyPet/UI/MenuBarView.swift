import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appDelegate = AppDelegate.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(.orange)
                Text("SillyPet")
                    .font(.headline)
                Spacer()
                Text("v0.1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            // Active sessions
            if appDelegate.sessions.isEmpty {
                Label("No active sessions", systemImage: "moon.zzz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            } else {
                ForEach(appDelegate.sessions.suffix(5)) { session in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(session.status))
                            .frame(width: 8, height: 8)
                        Text(session.type.displayName)
                            .font(.subheadline.bold())
                        Text(session.status.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                }
            }

            Divider()

            // Recent events
            if !appDelegate.eventLog.isEmpty {
                Text("Recent Events")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                ForEach(appDelegate.eventLog.suffix(3), id: \.self) { log in
                    Text(log)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                }

                Divider()
            }

            // Test buttons
            Menu("Test Events") {
                Button("Permission Request") {
                    appDelegate.testPermissionAlert()
                }
                Button("Task Completed") {
                    appDelegate.testTaskComplete()
                }
                Button("Session Start") {
                    appDelegate.testSessionStart()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)

            Divider()

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit SillyPet")
                    Spacer()
                    Text("Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .keyboardShortcut("q")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
        .padding(.vertical, 6)
        .frame(width: 260)
    }

    private func statusColor(_ status: AgentSession.SessionStatus) -> Color {
        switch status {
        case .active: return .green
        case .waitingForPermission: return .orange
        case .completed: return .blue
        case .error: return .red
        case .idle: return .gray
        }
    }
}
