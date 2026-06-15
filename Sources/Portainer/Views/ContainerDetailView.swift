import AppKit
import SwiftUI

struct ContainerDetailView: View {
    @EnvironmentObject private var store: ContainerStore

    var body: some View {
        Group {
            if let container = selectedDetailContainer {
                VStack(alignment: .leading, spacing: 18) {
                    detailHeader(for: container)
                    detailTabs
                    detailContent(for: container)
                }
            } else {
                EmptyDetailSelectionView {
                    store.selectedRows.removeAll()
                    store.selectedContainerID = nil
                    store.selectedDetailTab = .overview
                }
            }
        }
        .task(id: store.selectedContainerID) {
            guard selectedDetailContainer != nil else { return }
            await store.loadSelectedDetail()
        }
    }

    private var selectedDetailContainer: ContainerItem? {
        guard let id = store.selectedContainerID else { return nil }
        return store.containers.first { $0.id == id }
    }

    @ViewBuilder
    private func detailContent(for container: ContainerItem) -> some View {
        switch store.selectedDetailTab {
        case .overview:
            OverviewDetailGrid(container: container, detail: store.selectedDetail)
        case .logs:
            LogsView(container: container)
        case .inspect:
            InspectDetailView(detail: store.selectedDetail)
        case .stats:
            StatsDetailView(container: container)
        case .environment:
            EnvironmentDetailView(detail: store.selectedDetail)
        case .mounts:
            MountsDetailView(detail: store.selectedDetail)
        case .terminal:
            DetailTabPlaceholder(
                tab: .terminal,
                message: "Terminal attachment is not available from this full-window view yet."
            )
        }
    }

    private func detailHeader(for container: ContainerItem) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Containers") {
                        store.selectedRows.removeAll()
                        store.selectedContainerID = nil
                        store.selectedDetailTab = .overview
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                    Text("/")
                        .foregroundStyle(AppTheme.muted)
                    Text(container.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }

                HStack(spacing: 12) {
                    Text(container.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    StatusBadge(status: container.status)
                }

                HStack(spacing: 24) {
                    Text(container.platform)
                    Text(uptimeText(for: container))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            HStack(spacing: 10) {
                ActionButton(
                    title: container.status == .running ? "Stop" : "Start",
                    icon: container.status == .running ? "stop" : "play",
                    tint: container.status == .running ? AppTheme.red : AppTheme.blue,
                    filled: container.status == .running,
                    disabled: container.status == .unknown
                ) {
                    if container.status == .running {
                        Task { await store.stopSelectedContainer() }
                    } else {
                        Task { await store.startSelectedContainer() }
                    }
                }
                ActionButton(title: "Restart", icon: "arrow.clockwise", tint: AppTheme.blue, disabled: container.status != .running) {
                    Task { await store.restartSelectedContainer() }
                }
                ActionButton(title: "Terminal", icon: "terminal", tint: AppTheme.ink, disabled: true) {}
                ContainerMoreActionsMenu(container: container, detail: store.selectedDetail) {
                    store.selectedDetailTab = .inspect
                }
            }
        }
    }

    private func uptimeText(for container: ContainerItem) -> String {
        guard container.uptime != "-" else { return "Runtime unknown" }
        return container.status == .running ? "Up for \(container.uptime)" : container.uptime
    }

    private var detailTabs: some View {
        HStack(spacing: 24) {
            ForEach(DetailTab.allCases) { tab in
                let enabled = tab.isImplemented
                Button {
                    guard enabled else { return }
                    store.selectedDetailTab = tab
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(detailTabForeground(tab: tab, enabled: enabled))

                        Rectangle()
                            .fill(store.selectedDetailTab == tab && enabled ? AppTheme.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.48)
                .help(enabled ? tab.rawValue : "\(tab.rawValue) is not implemented yet")
            }
            Spacer()
        }
        .frame(height: 38)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
    }

    private func detailTabForeground(tab: DetailTab, enabled: Bool) -> Color {
        guard enabled else { return AppTheme.muted }
        return store.selectedDetailTab == tab ? AppTheme.blue : AppTheme.ink
    }
}

struct DetailTabPlaceholder: View {
    var tab: DetailTab
    var message: String

    var body: some View {
        GlassCard(cornerRadius: 14, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: tab.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
                Text(tab.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct EmptyDetailSelectionView: View {
    var onReturn: () -> Void

    var body: some View {
        DetailStateCard(
            icon: "shippingbox",
            title: "No container selected",
            message: "Select a container from the list or run a new container to view details.",
            actionTitle: "Containers",
            action: onReturn
        )
    }
}

struct DetailStateCard: View {
    var icon: String
    var title: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        GlassCard(cornerRadius: 14, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(AppTheme.surfaceRaised.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct InlineDetailState: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppTheme.blue.opacity(0.72))
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OverviewDetailGrid: View {
    var container: ContainerItem
    var detail: ContainerDetail?

    var body: some View {
        if let detail {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    DetailCard(title: "Statistics") {
                        KeyValueRows(rows: [
                            ("Memory", ByteFormatter.memory(container.stats.memoryBytes), true),
                            ("Network I/O", "Rx \(ByteFormatter.compact(container.stats.networkRxBytes))\nTx \(ByteFormatter.compact(container.stats.networkTxBytes))", false),
                            ("Block I/O", "R \(ByteFormatter.compact(container.stats.blockReadBytes))\nW \(ByteFormatter.compact(container.stats.blockWriteBytes))", false),
                            ("Processes", "\(container.stats.processes)\nPIDs", false)
                        ])
                    }
                    DetailCard(title: "Overview") {
                        KeyValueRows(rows: [
                            ("Container ID", detail.containerID, false),
                            ("Runtime", detail.runtime, false),
                            ("Platform", container.platform, false),
                            ("Hostname", detail.hostname, false)
                        ], copyable: true)
                    }
                    DetailCard(title: "Image") {
                        KeyValueRows(rows: [
                            ("Reference", detail.imageReference, false),
                            ("Media Type", detail.mediaType, false),
                            ("Digest", detail.digest, false),
                            ("Size", detail.size, false)
                        ], copyable: true)
                    }
                }

                HStack(spacing: 16) {
                    DetailCard(title: "Network") {
                        KeyValueRows(rows: [
                            ("Address", detail.address, false),
                            ("Gateway", detail.gateway, false),
                            ("Network", detail.network, false),
                            ("Domain", detail.domain, false),
                            ("Published Ports", "None configured", false)
                        ], copyable: true)
                    }
                    DetailCard(title: "Resources") {
                        KeyValueRows(rows: [
                            ("CPUs", detail.cpus, false),
                            ("Memory", detail.memory, false),
                            ("Rosetta", detail.rosetta, false)
                        ], copyable: true)
                    }
                    DetailCard(title: "Process Configuration") {
                        KeyValueRows(rows: [
                            ("Executable", detail.executable, false),
                            ("Working Directory", detail.workingDirectory, false),
                            ("Terminal", detail.terminal, false),
                            ("User", detail.user, false),
                            ("Arguments", detail.arguments, false)
                        ])
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            DetailStateCard(
                icon: "hourglass",
                title: "Loading details",
                message: "Inspect data is loading for \(container.name)."
            )
        }
    }
}

struct StatsDetailView: View {
    var container: ContainerItem

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                DetailCard(title: "CPU and Memory") {
                    KeyValueRows(rows: [
                        ("CPU", container.cpuPercent.percentText, true),
                        ("Memory", ByteFormatter.memory(container.stats.memoryBytes), true),
                        ("Memory Limit", ByteFormatter.memory(container.stats.memoryLimitBytes), false),
                        ("Memory Use", container.stats.memoryPercent.percentText, false)
                    ])
                }
                DetailCard(title: "Network I/O") {
                    KeyValueRows(rows: [
                        ("Received", ByteFormatter.compact(container.stats.networkRxBytes), false),
                        ("Transmitted", ByteFormatter.compact(container.stats.networkTxBytes), false),
                        ("Address", container.ipAddress, false)
                    ])
                }
                DetailCard(title: "Block I/O") {
                    KeyValueRows(rows: [
                        ("Read", ByteFormatter.compact(container.stats.blockReadBytes), false),
                        ("Written", ByteFormatter.compact(container.stats.blockWriteBytes), false),
                        ("Processes", "\(container.stats.processes)", false)
                    ])
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct InspectDetailView: View {
    var detail: ContainerDetail?

    var body: some View {
        if let detail {
            GlassCard(cornerRadius: 14, padding: 0) {
                ScrollView {
                    Text(detail.rawInspectJSON.isEmpty ? "{}" : detail.rawInspectJSON)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                }
            }
        } else {
            DetailStateCard(
                icon: "tablecells",
                title: "Loading inspect data",
                message: "Inspect JSON is loading for the selected container."
            )
        }
    }
}

struct EnvironmentDetailView: View {
    var detail: ContainerDetail?

    var body: some View {
        if let detail {
            GlassCard(cornerRadius: 14, padding: 0) {
                if detail.environment.isEmpty {
                    InlineDetailState(
                        icon: "slider.horizontal.3",
                        title: "No environment variables",
                        message: "Inspect data does not include environment variables for this container."
                    )
                    .padding(22)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(detail.environment) { variable in
                                EnvironmentVariableRow(variable: variable)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                    }
                }
            }
        } else {
            DetailStateCard(
                icon: "slider.horizontal.3",
                title: "Loading environment",
                message: "Inspect data is loading for the selected container."
            )
        }
    }
}

private struct EnvironmentVariableRow: View {
    var variable: ContainerEnvironmentVariable

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(variable.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 210, alignment: .leading)
            Text(variable.value.isEmpty ? "-" : variable.value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
    }
}

struct MountsDetailView: View {
    var detail: ContainerDetail?

    var body: some View {
        if let detail {
            GlassCard(cornerRadius: 14, padding: 0) {
                if detail.mounts.isEmpty {
                    InlineDetailState(
                        icon: "externaldrive",
                        title: "No mounts",
                        message: "Inspect data does not include mounts for this container."
                    )
                    .padding(22)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(detail.mounts) { mount in
                                MountRow(mount: mount)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                    }
                }
            }
        } else {
            DetailStateCard(
                icon: "externaldrive",
                title: "Loading mounts",
                message: "Inspect data is loading for the selected container."
            )
        }
    }
}

private struct MountRow: View {
    var mount: ContainerMount

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(mount.destination)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.ink)
                Text(mount.source)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(mount.type)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 110, alignment: .leading)

            Text(mount.options.isEmpty ? "-" : mount.options.joined(separator: ", "))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.muted)
                .frame(width: 220, alignment: .leading)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
    }
}

private struct ContainerMoreActionsMenu: View {
    var container: ContainerItem
    var detail: ContainerDetail?
    var showInspect: () -> Void

    var body: some View {
        Menu {
            Button("Copy Container ID") {
                copy(container.id)
            }
            Button("Copy Image Reference") {
                copy(detail?.imageReference ?? container.image)
            }
            Button("Show Inspect JSON", action: showInspect)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.panelStroke, lineWidth: 1)
                }
        }
        .menuStyle(.borderlessButton)
        .help("More actions")
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct DetailCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        GlassCard(cornerRadius: 12, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: title)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 230)
    }
}

struct KeyValueRows: View {
    var rows: [(String, String, Bool)]
    var copyable = false

    var body: some View {
        VStack(spacing: 13) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 14) {
                    Text(rows[index].0)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 108, alignment: .leading)
                    Text(rows[index].1)
                        .font(.system(size: 12, weight: rows[index].2 ? .bold : .medium))
                        .foregroundStyle(rows[index].2 ? AppTheme.cyan : AppTheme.ink)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if copyable {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
    }
}

struct LogsView: View {
    @EnvironmentObject private var store: ContainerStore
    var container: ContainerItem
    @State private var logSearchQuery = ""

    var body: some View {
        GlassCard(cornerRadius: 14, padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    SearchField(placeholder: "Search logs...", text: $logSearchQuery)
                        .frame(width: 380)
                    Spacer()
                    Toggle("Auto-refresh", isOn: $store.autoRefreshLogs)
                        .toggleStyle(.switch)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                    Picker("", selection: $store.logLineLimit) {
                        Text("100 lines").tag(100)
                        Text("250 lines").tag(250)
                        Text("500 lines").tag(500)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    Button("Clear") {
                        logSearchQuery = ""
                    }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(canClearLogSearch ? AppTheme.ink : AppTheme.muted.opacity(0.55))
                        .frame(width: 58, height: 34)
                        .background(AppTheme.surfaceRaised.opacity(0.70), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .disabled(!canClearLogSearch)
                        .help("Clear log search")
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)

                if filteredLogs.isEmpty {
                    InlineDetailState(
                        icon: "doc.text",
                        title: emptyLogsTitle,
                        message: emptyLogsMessage
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(filteredLogs) { line in
                                LogLineView(line: line)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .task(id: store.autoRefreshLogs) {
            await refreshLogsWhileEnabled()
        }
        .task(id: store.logLineLimit) {
            await reloadLogsForCurrentLimit()
        }
    }

    private var normalizedLogSearch: String {
        logSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canClearLogSearch: Bool {
        !normalizedLogSearch.isEmpty
    }

    private var filteredLogs: [ContainerLogLine] {
        guard !normalizedLogSearch.isEmpty else { return store.logs }
        return store.logs.filter { line in
            line.timestamp.lowercased().contains(normalizedLogSearch)
                || line.level.lowercased().contains(normalizedLogSearch)
                || line.tag.lowercased().contains(normalizedLogSearch)
                || line.message.lowercased().contains(normalizedLogSearch)
        }
    }

    private var emptyLogsTitle: String {
        store.logs.isEmpty ? "No logs" : "No matching log lines"
    }

    private var emptyLogsMessage: String {
        if store.logs.isEmpty {
            return "No log output was returned for \(container.name)."
        }
        return "No log line matches the current search."
    }

    private func reloadLogsForCurrentLimit() async {
        let shouldReload = await MainActor.run {
            store.selectedContainerID == container.id
        }
        guard shouldReload else { return }
        await store.loadSelectedDetail()
    }

    private func refreshLogsWhileEnabled() async {
        let enabled = await MainActor.run {
            store.autoRefreshLogs
        }
        guard enabled else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            let shouldRefresh = await MainActor.run {
                store.autoRefreshLogs && store.selectedContainerID == container.id
            }
            guard shouldRefresh else { return }
            await store.loadSelectedDetail()
        }
    }
}

struct LogLineView: View {
    var line: ContainerLogLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(line.timestamp)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.78))
            Text(line.level)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: 0x6DE6A6))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: 0x123A2B, alpha: 0.86), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(line.tag)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.surfaceSelected.opacity(0.78), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(line.message)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
            Spacer(minLength: 0)
        }
    }
}
