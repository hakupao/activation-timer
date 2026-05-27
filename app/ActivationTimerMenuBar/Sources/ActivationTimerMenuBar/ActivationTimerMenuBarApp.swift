import ActivationTimerCore
import AppKit
import Foundation
import ServiceManagement
import SwiftUI

@main
struct ActivationTimerMenuBarApp: App {
    @StateObject private var model = ActivationTimerAppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model) {
                openWindow(id: "settings")
            }
            .task {
                await model.refresh()
            }
        } label: {
            Label("Activation Timer", systemImage: model.state?.installed == true ? "timer" : "timer.circle")
        }
        .menuBarExtraStyle(.menu)

        Window("Activation Timer", id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 400, height: 620)
    }
}

// MARK: - Model

@MainActor
final class ActivationTimerAppModel: ObservableObject {
    @Published var state: ActivationState?
    @Published var settings: AppSettings
    @Published var statusMessage = ""
    @Published var statusIsError = false
    @Published var isBusy = false
    @Published var launchAtLogin: Bool
    @Published var requestToolCheck = false

    let root: URL
    private var keepAwakeProcess: Process?

    init() {
        root = ProjectLocator.findRoot()
        settings = AppSettings(values: EnvParser.parse(Self.readEnv(root: root)))
        launchAtLogin = SMAppService.mainApp.status == .enabled
        updateKeepAwakeProcess()
    }

    deinit {
        keepAwakeProcess?.terminate()
    }

    func refresh() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let output = try await runExecutable(root.appendingPathComponent("bin/activation-state.sh"), arguments: ["--json"])
            let data = Data(output.utf8)
            state = try JSONDecoder().decode(ActivationState.self, from: data)
            settings = AppSettings(values: EnvParser.parse(Self.readEnv(root: root)))
            updateKeepAwakeProcess()
        } catch {
            showStatus(L10n.failedToReadStatus, isError: true)
        }
    }

    func toggleSchedule() {
        if state?.installed == true {
            runInstallCommand("uninstall", success: L10n.disabled)
        } else {
            runInstallCommand("install", success: L10n.scheduleOn)
        }
    }

    func runInstall() {
        runInstallCommand("install", success: L10n.savedAndEnabled)
    }

    func runNow() {
        runInstallCommand("run-now", success: L10n.triggered)
    }

    func runNowWithDelayedRefresh() {
        runNow()
        Task {
            try? await Task.sleep(for: .seconds(10))
            await refresh()
        }
    }

    func openLogs() {
        NSWorkspace.shared.open(root.appendingPathComponent("logs"))
    }

    func openInstallGuide() {
        let zhGuide = root.appendingPathComponent("INSTALL_CN.md")
        if FileManager.default.fileExists(atPath: zhGuide.path) {
            NSWorkspace.shared.open(zhGuide)
            return
        }
        NSWorkspace.shared.open(root.appendingPathComponent("INSTALL.md"))
    }

    func saveSettingsAndReload() {
        do {
            let envURL = root.appendingPathComponent(".env")
            let existing: String
            if FileManager.default.fileExists(atPath: envURL.path) {
                existing = try String(contentsOf: envURL, encoding: .utf8)
            } else {
                existing = Self.readEnv(root: root)
            }

            let updated = EnvFile.updating(existing, values: settings.envValues)
            try updated.write(to: envURL, atomically: true, encoding: .utf8)
            updateKeepAwakeProcess()
            runInstall()
        } catch {
            showStatus(L10n.saveFailed, isError: true)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            showStatus(L10n.launchAtLoginFailed, isError: true)
        }
    }

    func showStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
        Task {
            try? await Task.sleep(for: .seconds(3))
            if statusMessage == message {
                withAnimation(.easeOut(duration: 0.3)) {
                    statusMessage = ""
                }
            }
        }
    }

    func addTime(_ time: String) {
        guard let normalized = ScheduleFormatter.normalize(time) else { return }
        if !settings.scheduleTimes.contains(normalized) {
            settings.scheduleTimes.append(normalized)
            settings.scheduleTimes.sort()
        }
    }

    func removeTime(at index: Int) {
        guard settings.scheduleTimes.count > 1, settings.scheduleTimes.indices.contains(index) else { return }
        settings.scheduleTimes.remove(at: index)
    }

    private func runInstallCommand(_ command: String, success: String) {
        Task {
            isBusy = true
            defer { isBusy = false }

            do {
                _ = try await runExecutable(root.appendingPathComponent("install.sh"), arguments: [command])
                showStatus(success, isError: false)
                await refresh()
            } catch {
                showStatus("\(command) \(L10n.failed)", isError: true)
            }
        }
    }

    private func updateKeepAwakeProcess() {
        if settings.keepAwakeMode == "always" {
            guard keepAwakeProcess?.isRunning != true else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            process.arguments = ["-dimsu"]
            do {
                try process.run()
                keepAwakeProcess = process
            } catch {
                statusMessage = L10n.keepAwakeFailed
            }
        } else {
            keepAwakeProcess?.terminate()
            keepAwakeProcess = nil
        }
    }

    private func runExecutable(_ executable: URL, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) { [root] in
            let process = Process()
            let output = Pipe()
            let error = Pipe()

            process.currentDirectoryURL = root
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = error

            try process.run()
            process.waitUntilExit()

            let outputData = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = error.fileHandleForReading.readDataToEndOfFile()
            let outputText = String(data: outputData, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw CommandError(status: process.terminationStatus, message: errorText.isEmpty ? outputText : errorText)
            }

            return outputText
        }.value
    }

    private static func readEnv(root: URL) -> String {
        let env = root.appendingPathComponent(".env")
        if let contents = try? String(contentsOf: env, encoding: .utf8) {
            return contents
        }
        let example = root.appendingPathComponent(".env.example")
        return (try? String(contentsOf: example, encoding: .utf8)) ?? ""
    }
}

struct CommandError: LocalizedError {
    var status: Int32
    var message: String

    var errorDescription: String? {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "exit \(status)" : cleaned
    }
}

// MARK: - Design System

enum DS {
    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16

    static let activeGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let activeBg = Color(red: 0.12, green: 0.22, blue: 0.14)
    static let windowActiveTint = Color(red: 0.06, green: 0.12, blue: 0.08)

    static let accentBlue = Color(red: 0.25, green: 0.52, blue: 0.96)
    static let accentOrange = Color(red: 0.95, green: 0.62, blue: 0.22)

    static let claudePurple = Color(red: 0.56, green: 0.44, blue: 0.85)
    static let codexGreen = Color(red: 0.18, green: 0.75, blue: 0.49)

    static let cardBg = Color(nsColor: .controlBackgroundColor)
    static let subtleBorder = Color.primary.opacity(0.06)

    static func quotaColor(_ pct: Double?) -> Color {
        guard let pct else { return .secondary }
        if pct > 50 { return activeGreen }
        if pct > 20 { return accentOrange }
        return .red
    }

    static func quotaLabel(_ pct: Double?) -> String {
        guard let pct else { return "--" }
        return "\(Int(pct.rounded()))%"
    }
}

// MARK: - Button Style with Press Feedback

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Menu

struct MenuContentView: View {
    @ObservedObject var model: ActivationTimerAppModel
    var openSettings: () -> Void

    var body: some View {
        let isOn = model.state?.installed == true

        Button {
            model.toggleSchedule()
        } label: {
            Label(
                isOn ? L10n.scheduleOn : L10n.scheduleOff,
                systemImage: isOn ? "circle.inset.filled" : "circle"
            )
        }

        if let state = model.state {
            Text("\(L10n.schedule): \(state.schedule.times.joined(separator: ", "))")
            Text(quotaSummary(state.quota))
        }

        Divider()

        Button(L10n.runOnce) { model.runNowWithDelayedRefresh() }

        Divider()

        Button(L10n.environmentCheck) {
            model.requestToolCheck = true
            openSettings()
        }
        Button(L10n.settings) { openSettings() }
        Button(L10n.quit) { NSApplication.shared.terminate(nil) }
    }

    private func quotaSummary(_ quota: [String: ActivationState.ToolQuota]) -> String {
        let claudeH = DS.quotaLabel(quota["claude"]?.fiveHour?.remainingPercent)
        let codexH = DS.quotaLabel(quota["codex"]?.fiveHour?.remainingPercent)
        return "Claude 5h \(claudeH) · Codex 5h \(codexH)"
    }
}

// MARK: - Settings Window

struct SettingsView: View {
    @ObservedObject var model: ActivationTimerAppModel
    @AppStorage("hideOnboarding") private var hideOnboarding = false
    @State private var showOnboarding = false

    private var isOn: Bool { model.state?.installed == true }

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(model: model)

            ScrollView {
                VStack(spacing: 14) {
                    StatusCard(model: model)
                    ScheduleCard(model: model)
                    ToolCard(model: model)
                    AdvancedSection(model: model)
                    ActionBar(model: model)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
        .frame(minWidth: 380, minHeight: 480)
        .background(
            (isOn ? DS.windowActiveTint : Color(nsColor: .windowBackgroundColor))
                .animation(.easeInOut(duration: 0.4), value: isOn)
        )
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            if !hideOnboarding {
                Task {
                    let missing = await ToolChecker.checkMissingTools()
                    if !missing.isEmpty {
                        showOnboarding = true
                    }
                }
            }
        }
        .onChange(of: model.requestToolCheck) { _, newValue in
            if newValue {
                showOnboarding = true
                model.requestToolCheck = false
            }
        }
    }
}

// MARK: - Tool Checker

enum ToolChecker {
    struct ToolInfo: Sendable {
        var name: String
        var found: Bool
        var installHint: String
    }

    static let requiredTools: [(name: String, hint: String)] = [
        ("claude", "npm i -g @anthropic-ai/claude-code"),
        ("codex",  "npm i -g @openai/codex"),
        ("jq",     "brew install jq")
    ]

    static func checkMissingTools() async -> [String] {
        var missing: [String] = []
        for tool in requiredTools {
            let found = await isToolAvailable(tool.name)
            if !found { missing.append(tool.name) }
        }
        return missing
    }

    static func checkAllTools() async -> [ToolInfo] {
        var results: [ToolInfo] = []
        for tool in requiredTools {
            let found = await isToolAvailable(tool.name)
            results.append(ToolInfo(name: tool.name, found: found, installHint: tool.hint))
        }
        return results
    }

    private static let searchPaths = [
        "\(NSHomeDirectory())/.local/bin",
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin"
    ]

    private static func isToolAvailable(_ name: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            for dir in searchPaths {
                let path = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: path) {
                    return true
                }
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-l", "-c", "which \(name)"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hideOnboarding") private var hideOnboarding = false
    @State private var toolResults: [ToolChecker.ToolInfo] = []
    @State private var isChecking = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.accentOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.environmentCheckTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(L10n.environmentCheckSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(DS.cardPadding)

            Divider()

            // Tool list
            VStack(spacing: 0) {
                if isChecking {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(L10n.checking)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(toolResults, id: \.name) { tool in
                        ToolStatusRow(tool: tool)
                        if tool.name != toolResults.last?.name {
                            Divider().padding(.leading, DS.cardPadding)
                        }
                    }
                }
            }
            .background(DS.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .strokeBorder(DS.subtleBorder, lineWidth: 1)
            )
            .padding(.horizontal, DS.cardPadding)
            .padding(.top, DS.cardPadding)

            // Footer
            HStack(spacing: 12) {
                Toggle(L10n.dontShowAgain, isOn: $hideOnboarding)
                    .font(.system(size: 13))
                    .toggleStyle(.checkbox)

                Spacer()

                Button(L10n.close) {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accentBlue)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(DS.cardPadding)
        }
        .frame(width: 380)
        .task {
            toolResults = await ToolChecker.checkAllTools()
            isChecking = false
        }
    }
}

struct ToolStatusRow: View {
    var tool: ToolChecker.ToolInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: tool.found ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tool.found ? DS.activeGreen : .red)

                Text(tool.name)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))

                Spacer()

                Text(tool.found ? L10n.installed : L10n.notFound)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tool.found ? DS.activeGreen : .red)
            }

            if !tool.found {
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(tool.installHint)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.leading, 26)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 10)
    }
}

// MARK: - Header

struct SettingsHeader: View {
    @ObservedObject var model: ActivationTimerAppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                AppIconBadge()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Activation Timer")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(L10n.appSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    let lang = AppLanguage.current
                    AppLanguage.current = (lang == .zh) ? .en : .zh
                    model.objectWillChange.send()
                } label: {
                    Text(AppLanguage.current == .zh ? "EN" : "中")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(AppLanguage.current == .zh ? L10n.switchToEnglish : L10n.switchToChinese)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            if !model.statusMessage.isEmpty {
                NotificationBanner(
                    message: model.statusMessage,
                    isError: model.statusIsError
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.statusMessage)
    }
}

struct NotificationBanner: View {
    var message: String
    var isError: Bool

    private var icon: String { isError ? "xmark.circle.fill" : "checkmark.circle.fill" }
    private var color: Color { isError ? .red : DS.activeGreen }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
    }
}

struct AppIconBadge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.31, blue: 0.70),
                            Color(red: 0.03, green: 0.62, blue: 0.58),
                            Color(red: 0.95, green: 0.67, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "timer")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.22))
                .offset(x: 12, y: -11)
        }
        .frame(width: 44, height: 44)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Status Card

struct StatusCard: View {
    @ObservedObject var model: ActivationTimerAppModel

    private var isOn: Bool { model.state?.installed == true }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isOn ? DS.activeGreen.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 42, height: 42)
                    Image(systemName: "power")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isOn ? DS.activeGreen : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isOn ? L10n.scheduleOn : L10n.scheduleOff)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    if let state = model.state {
                        Text(state.schedule.times.joined(separator: "  ·  "))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { _ in model.toggleSchedule() }
                ))
                .toggleStyle(.switch)
                .tint(DS.activeGreen)
                .labelsHidden()
                .scaleEffect(0.9)
            }

            HStack(spacing: 10) {
                QuotaBadge(
                    tool: "Claude",
                    color: DS.claudePurple,
                    icon: "c.circle.fill",
                    quota: model.state?.quota["claude"]
                )
                QuotaBadge(
                    tool: "Codex",
                    color: DS.codexGreen,
                    icon: "chevron.left.forwardslash.chevron.right",
                    quota: model.state?.quota["codex"]
                )
            }

            // Last run result
            LastRunRow(lastUsage: model.state?.lastUsage)
        }
        .padding(DS.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .fill(isOn ? DS.activeBg : DS.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .strokeBorder(isOn ? DS.activeGreen.opacity(0.25) : DS.subtleBorder, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

// MARK: - Last Run Row

struct LastRunRow: View {
    var lastUsage: ActivationState.LastUsage?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if let usage = lastUsage {
                Text(L10n.lastRun)
                    .foregroundStyle(.secondary)
                + Text(toolLabel(usage))
                    .foregroundStyle(.primary)
                + Text("  ")
                + Text(resultLabel(usage))
                    .foregroundStyle(resultColor(usage))

                Spacer()

                if let ts = usage.timestamp {
                    Text(formatTimestamp(ts))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(L10n.noRunHistory)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }

    private func toolLabel(_ usage: ActivationState.LastUsage) -> String {
        guard let tool = usage.tool else { return L10n.unknown }
        return tool.capitalized
    }

    private func resultLabel(_ usage: ActivationState.LastUsage) -> String {
        if let result = usage.result, !result.isEmpty {
            return result
        }
        if usage.skipped == true {
            if let reason = usage.skipReason, !reason.isEmpty {
                return "\(L10n.skipped)(\(reason))"
            }
            return L10n.skipped
        }
        if let ok = usage.ok {
            return ok ? L10n.success : L10n.failed
        }
        return "--"
    }

    private func resultColor(_ usage: ActivationState.LastUsage) -> Color {
        if usage.skipped == true { return DS.accentOrange }
        if let ok = usage.ok { return ok ? DS.activeGreen : .red }
        return .secondary
    }

    private func formatTimestamp(_ ts: String) -> String {
        // ts is ISO8601 or similar; show date+time compactly
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: ts) {
            return Self.displayFormatter.string(from: date)
        }
        // fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: ts) {
            return Self.displayFormatter.string(from: date)
        }
        // last resort: return first 16 chars of ts
        return String(ts.prefix(16))
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()
}

struct QuotaBadge: View {
    var tool: String
    var color: Color
    var icon: String
    var quota: ActivationState.ToolQuota?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(tool)
                    .font(.system(size: 12, weight: .semibold))
            }

            HStack(spacing: 12) {
                QuotaRow(label: L10n.fiveHour, pct: quota?.fiveHour?.remainingPercent)
                QuotaRow(label: L10n.weekly, pct: quota?.weekly?.remainingPercent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct QuotaRow: View {
    var label: String
    var pct: Double?

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(DS.quotaLabel(pct))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(DS.quotaColor(pct))
        }
    }
}

// MARK: - Schedule Card

struct ScheduleCard: View {
    @ObservedObject var model: ActivationTimerAppModel
    @State private var newHour = 8
    @State private var newMinute = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(L10n.schedule)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(DS.accentBlue)
            }

            FlowLayout(spacing: 8) {
                ForEach(Array(model.settings.scheduleTimes.enumerated()), id: \.offset) { index, time in
                    TimePill(time: time, canDelete: model.settings.scheduleTimes.count > 1) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            model.removeTime(at: index)
                        }
                    }
                }

                AddTimePill(hour: $newHour, minute: $newMinute) {
                    let time = String(format: "%02d:%02d", newHour, newMinute)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.addTime(time)
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .fill(DS.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .strokeBorder(DS.subtleBorder, lineWidth: 1)
        )
    }
}

struct TimePill: View {
    var time: String
    var canDelete: Bool
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundStyle(DS.accentBlue.opacity(0.7))

            Text(time)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))

            if canDelete && isHovering {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(DS.accentBlue.opacity(isHovering ? 0.12 : 0.06))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(DS.accentBlue.opacity(0.15), lineWidth: 1))
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

struct AddTimePill: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var onAdd: () -> Void

    @State private var isExpanded = false

    var body: some View {
        if isExpanded {
            HStack(spacing: 4) {
                Picker("", selection: $hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 56)
                .labelsHidden()

                Text(":")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Picker("", selection: $minute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 56)
                .labelsHidden()

                Button {
                    onAdd()
                    isExpanded = false
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(DS.accentBlue)
                        .clipShape(Circle())
                }
                .buttonStyle(PressButtonStyle())

                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text(L10n.add)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
            .buttonStyle(PressButtonStyle())
            .transition(.scale.combined(with: .opacity))
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let maxH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += maxH
            if i > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            let maxH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            if i > 0 { y += spacing }
            for sub in row {
                let size = sub.sizeThatFits(.unspecified)
                sub.place(at: CGPoint(x: x, y: y + (maxH - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += maxH
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(sub)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    @ObservedObject var model: ActivationTimerAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(L10n.tools)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(DS.accentOrange)
            }

            HStack(spacing: 10) {
                ToolToggleTile(
                    name: "Claude",
                    icon: "c.circle.fill",
                    color: DS.claudePurple,
                    isOn: $model.settings.enableClaude
                )
                ToolToggleTile(
                    name: "Codex",
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: DS.codexGreen,
                    isOn: $model.settings.enableCodex
                )
            }
        }
        .padding(DS.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .fill(DS.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .strokeBorder(DS.subtleBorder, lineWidth: 1)
        )
    }
}

struct ToolToggleTile: View {
    var name: String
    var icon: String
    var color: Color
    var isOn: Binding<Bool>

    var body: some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn.wrappedValue ? color : .secondary.opacity(0.5))

                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isOn.wrappedValue ? .primary : .secondary)

                Spacer()

                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isOn.wrappedValue ? color : .secondary.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isOn.wrappedValue ? color.opacity(0.08) : Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isOn.wrappedValue ? color.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isOn.wrappedValue)
    }
}

// MARK: - Advanced Settings (full-row clickable)

struct AdvancedSection: View {
    @ObservedObject var model: ActivationTimerAppModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(L10n.advanced)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.checkQuotaBefore, isOn: $model.settings.enableQuotaPreflight)
                    Toggle(L10n.recordSnapshotAfter, isOn: $model.settings.enableStatusSnapshots)

                    Picker(L10n.whenQuotaUnavailable, selection: $model.settings.quotaPreflightOnUnknown) {
                        Text(L10n.continueAnyway).tag("allow")
                        Text(L10n.skip).tag("skip")
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    Picker(L10n.keepAwake, selection: $model.settings.keepAwakeMode) {
                        Text(L10n.off).tag("off")
                        Text(L10n.duringRun).tag("during")
                        Text(L10n.whileAppOpen).tag("always")
                    }
                    .pickerStyle(.segmented)

                    LabeledContent(L10n.durationSeconds) {
                        TextField("900", text: $model.settings.keepAwakeSeconds)
                            .frame(maxWidth: 120)
                    }

                    Divider()

                    // Launch at Login toggle
                    Toggle(L10n.launchAtLogin, isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                }
                .font(.system(size: 13))
                .padding(16)
                .background(Color.primary.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Action Bar

struct ActionBar: View {
    @ObservedObject var model: ActivationTimerAppModel

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    model.saveSettingsAndReload()
                } label: {
                    Label(L10n.save, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accentBlue)

                Button {
                    model.runNowWithDelayedRefresh()
                } label: {
                    Label(L10n.runOnce, systemImage: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    model.openLogs()
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                }
                .help(L10n.logs)

                Button {
                    model.openInstallGuide()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13))
                }
                .help(L10n.help)
            }

            HStack {
                Spacer()
                Text("v\(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
