import StokerCore
import SwiftUI

// MARK: - Tab

enum MainTab: String, CaseIterable, Identifiable {
    case activity, settings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .activity: L10n.activity
        case .settings: AppLanguage.current == .zh ? "设置" : "Settings"
        }
    }
}

// MARK: - Main View

struct MainView: View {
    @ObservedObject var model: StokerAppModel

    var body: some View {
        MainPanel(model: model, root: model.root)
    }
}

private struct MainPanel: View {
    @ObservedObject var model: StokerAppModel
    @StateObject private var logStore: LogStore
    @State private var selectedTab = MainTab.activity
    @State private var langRefresh = false
    @AppStorage("hideOnboarding") private var hideOnboarding = false
    @State private var showOnboarding = false

    init(model: StokerAppModel, root: URL) {
        self._model = ObservedObject(wrappedValue: model)
        self._logStore = StateObject(wrappedValue: LogStore(root: root))
    }

    private var isOn: Bool { model.state?.installed == true }

    var body: some View {
        VStack(spacing: 0) {
            UnifiedHeader(model: model, selectedTab: $selectedTab, langRefresh: $langRefresh)
            Divider()

            Group {
                switch selectedTab {
                case .activity:
                    ActivityTabContent(logStore: logStore)
                case .settings:
                    SettingsTabContent(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            BottomActionBar(model: model, logStore: logStore, selectedTab: selectedTab)
        }
        .frame(minWidth: 720, minHeight: 600)
        .background(
            (isOn ? DS.windowActiveTint : Color(nsColor: .windowBackgroundColor))
                .animation(.easeInOut(duration: 0.4), value: isOn)
        )
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding, root: model.root)
        }
        .onAppear {
            logStore.load()
            Task { await model.refresh() }
            if model.requestToolCheck {
                showOnboarding = true
                model.requestToolCheck = false
            } else if !hideOnboarding {
                Task {
                    let missing = await ToolChecker.checkMissingTools(root: model.root)
                    if !missing.isEmpty { showOnboarding = true }
                }
            }
        }
        .onChange(of: langRefresh) { _, _ in
            logStore.objectWillChange.send()
        }
        .onChange(of: model.requestToolCheck) { _, newValue in
            if newValue {
                showOnboarding = true
                model.requestToolCheck = false
            }
        }
    }
}

// MARK: - Unified Header

private struct UnifiedHeader: View {
    @ObservedObject var model: StokerAppModel
    @Binding var selectedTab: MainTab
    @Binding var langRefresh: Bool

    private var isOn: Bool { model.state?.installed == true }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                AppIconBadge()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Stoker")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if let state = model.state {
                        Text(state.schedule.times.joined(separator: " · "))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(DS.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(isOn ? DS.activeGreen : .secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .shadow(color: isOn ? DS.activeGreen.opacity(0.6) : .clear, radius: 4)

                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { _ in model.toggleSchedule() }
                    ))
                    .toggleStyle(.switch)
                    .tint(DS.activeGreen)
                    .labelsHidden()
                    .scaleEffect(0.8)
                }

                if model.isBusy {
                    ProgressView().controlSize(.small)
                }

                Button {
                    AppLanguage.current = AppLanguage.current == .zh ? .en : .zh
                    model.objectWillChange.send()
                    langRefresh.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .semibold))
                        Text(AppLanguage.current == .zh ? "EN" : "中")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(DS.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(AppLanguage.current == .zh ? "Switch to English" : "切换到中文")
            }

            HStack(spacing: 16) {
                QuotaMiniBar(
                    label: "Claude",
                    percent: model.state?.quota["claude"]?.fiveHour?.remainingPercent,
                    color: DS.claudePurple
                )
                QuotaMiniBar(
                    label: "Codex",
                    percent: model.state?.quota["codex"]?.fiveHour?.remainingPercent,
                    color: DS.codexGreen
                )
                Spacer()
                TabPicker(selected: $selectedTab)
            }

            if !model.statusMessage.isEmpty {
                NotificationBanner(message: model.statusMessage, isError: model.statusIsError)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.25), value: model.statusMessage)
    }
}

// MARK: - Tab Picker

private struct TabPicker: View {
    @Binding var selected: MainTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases) { tab in
                Text(tab.label)
                    .font(.system(size: 12, weight: selected == tab ? .bold : .medium, design: .rounded))
                    .foregroundStyle(selected == tab ? DS.textPrimary : DS.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background {
                        if selected == tab {
                            Capsule()
                                .fill(Color.primary.opacity(0.1))
                                .matchedGeometryEffect(id: "activeTab", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture { selected = tab }
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selected)
    }
}

// MARK: - Quota Mini Bar

private struct QuotaMiniBar: View {
    var label: String
    var percent: Double?
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 42, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(0, geo.size.width * ((percent ?? 0) / 100)))
                }
            }
            .frame(width: 80, height: 5)

            Text(DS.quotaLabel(percent))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(DS.quotaColor(percent))
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Settings Tab Content

struct SettingsTabContent: View {
    @ObservedObject var model: StokerAppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScheduleCard(model: model)
                ToolCard(model: model)
                AdvancedSection(model: model)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Bottom Action Bar

struct BottomActionBar: View {
    @ObservedObject var model: StokerAppModel
    @ObservedObject var logStore: LogStore
    var selectedTab: MainTab

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Button {
                    model.saveSettingsAndReload()
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        logStore.load()
                    }
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
                    Task {
                        try? await Task.sleep(for: .seconds(12))
                        logStore.load()
                    }
                } label: {
                    Label(L10n.runOnce, systemImage: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)

                Spacer()

                if selectedTab == .activity {
                    Button(action: exportCSV) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                    }
                    .help(L10n.exportCsv)
                }

                Button { model.openLogs() } label: {
                    Image(systemName: "doc.text").font(.system(size: 13))
                }
                .help(L10n.logs)

                Button { model.openInstallGuide() } label: {
                    Image(systemName: "questionmark.circle").font(.system(size: 13))
                }
                .help(L10n.help)
            }

            HStack {
                Spacer()
                Text("v\(appVersion)")
                    .font(.caption)
                    .foregroundStyle(DS.textMuted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "stoker-export.csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? logStore.exportCSV().write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
