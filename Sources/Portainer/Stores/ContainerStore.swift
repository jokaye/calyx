import Foundation

@MainActor
final class ContainerStore: ObservableObject {
    @Published var selectedSection: SidebarSection = .dashboard
    @Published var selectedContainerID: String?
    @Published var selectedDetailTab: DetailTab = .overview
    @Published var selectedRows: Set<String> = []
    @Published var searchQuery = ""
    @Published var containers: [ContainerItem] = []
    @Published var images: [ImageItem] = []
    @Published var volumes: [VolumeItem] = []
    @Published var networks: [NetworkAttachmentItem] = []
    @Published var configs: [DerivedConfigItem] = []
    @Published var secrets: [DerivedSecretReference] = []
    @Published var systemEvents: [SystemEventLine] = []
    @Published var systemEventWindow = "5m"
    @Published var composePreview = ComposeFilePreview.empty
    @Published var composeSupport = ComposeSupportStatus.unchecked
    @Published var overview = RuntimeOverview(images: 0, volumes: 0, networks: 0, storageBytes: 0)
    @Published var details: [String: ContainerDetail] = [:]
    @Published var logs: [ContainerLogLine] = []
    @Published var runtimeIssue: RuntimeIssue?
    @Published var operationIssue: RuntimeIssue?
    @Published var isRefreshing = false
    @Published var autoRefreshLogs = true
    @Published var logLineLimit = 100
    @Published var uiMode: AppUIMode = .saved
    @Published var isRunContainerPresented = false
    @Published var busyContainerIDs: Set<String> = []
    @Published var systemMetrics = SystemMetrics()

    private let runtime: ContainerRuntime
    private var metricsTask: Task<Void, Never>?
    private var lastContainerStatSamples: [String: TimedContainerStats] = [:]
    private var lastSystemCounterSample: SystemCounterSample?
    private let metricsSampleLimit = 24
    private let metricsIntervalNanoseconds: UInt64 = 5_000_000_000

    nonisolated init(runtime: ContainerRuntime) {
        self.runtime = runtime
    }

    var selectedContainer: ContainerItem? {
        guard let selectedContainerID else { return nil }
        return containers.first { $0.id == selectedContainerID }
    }

    var selectedDetail: ContainerDetail? {
        guard let id = selectedContainer?.id else { return nil }
        return details[id]
    }

    var filteredContainers: [ContainerItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return containers }
        return containers.filter {
            $0.name.lowercased().contains(query)
                || $0.image.lowercased().contains(query)
                || $0.ipAddress.lowercased().contains(query)
                || $0.status.rawValue.lowercased().contains(query)
        }
    }

    var runningCount: Int {
        containers.filter { $0.status == .running }.count
    }

    var canStartSelected: Bool {
        guard let selectedContainer else { return false }
        return selectedContainer.status != .running
    }

    var canStopSelected: Bool {
        selectedContainer?.status == .running
    }

    func isContainerBusy(_ containerID: String) -> Bool {
        busyContainerIDs.contains(containerID)
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let loadedContainers = runtime.listContainers()
            async let loadedOverview = runtime.overview()
            let refreshedContainers = try await loadedContainers
            let runtimeOverview = try await loadedOverview
            containers = refreshedContainers
            overview = RuntimeOverview(
                images: runtimeOverview.images,
                volumes: runtimeOverview.volumes,
                networks: runtimeOverview.networks,
                storageBytes: runtimeOverview.storageBytes == 0 ? overview.storageBytes : runtimeOverview.storageBytes
            )
            reconcileSelectionAfterRefresh()
            recordSystemMetrics(sampledAt: Date())
            runtimeIssue = nil
            await loadSelectedDetail()
        } catch {
            clearRuntimeState()
            runtimeIssue = issue(
                title: "Apple container CLI unavailable",
                error: error,
                recovery: "Install Apple's container CLI, run `container system start`, then refresh."
            )
        }
    }

    func startSystemMetricsCollection() {
        guard metricsTask == nil else { return }
        let interval = metricsIntervalNanoseconds
        metricsTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    return
                }
                await self?.refreshSystemMetrics()
            }
        }
    }

    func stopSystemMetricsCollection() {
        metricsTask?.cancel()
        metricsTask = nil
    }

    func refreshSystemMetrics() async {
        do {
            let statsByID = try await runtime.stats()
            applyLiveStats(statsByID, sampledAt: Date())
        } catch {
            runtimeIssue = issue(
                title: "System metrics unavailable",
                error: error,
                recovery: "Verify `container stats --no-stream --format json` works, then refresh."
            )
        }
    }

    func showSection(_ section: SidebarSection) {
        selectedSection = section
        if section != .containers {
            selectedDetailTab = .overview
        }
        Task { await loadResources(for: section) }
    }

    func setUIMode(_ mode: AppUIMode) {
        guard uiMode != mode else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: "appUIMode")
        uiMode = mode
    }

    func showRunContainer() {
        isRunContainerPresented = true
    }

    func openDetail(_ container: ContainerItem, tab: DetailTab = .overview) {
        selectedSection = .containers
        selectedContainerID = container.id
        selectedRows = [container.id]
        selectedDetailTab = tab
        Task { await loadSelectedDetail() }
    }

    func loadSelectedDetail() async {
        guard let id = selectedContainer?.id else {
            logs = []
            operationIssue = nil
            return
        }
        do {
            async let loadedDetail = runtime.inspect(containerID: id)
            async let loadedLogs = runtime.logs(containerID: id, lines: logLineLimit)
            let detail = try await loadedDetail
            let logLines = try await loadedLogs
            details[id] = detail
            logs = logLines
            operationIssue = nil
        } catch {
            details[id] = nil
            logs = []
            operationIssue = issue(
                title: "Container detail unavailable",
                error: error,
                recovery: "Refresh the container list and verify the selected container still exists."
            )
        }
    }

    func loadResources(for section: SidebarSection) async {
        do {
            switch section {
            case .images:
                images = try await runtime.listImages()
                operationIssue = nil
            case .networks:
                networks = try await runtime.listNetworks()
                overview.networks = Set(networks.map(\.networkName)).count
                operationIssue = nil
            case .volumes:
                volumes = try await runtime.listVolumes()
                operationIssue = nil
            case .compose:
                await refreshComposeSupport()
                operationIssue = nil
            case .configs:
                configs = try await runtime.listConfigs()
                operationIssue = nil
            case .secrets:
                secrets = try await runtime.listSecrets()
                operationIssue = nil
            case .events:
                systemEvents = try await runtime.systemEvents(last: systemEventWindow)
                operationIssue = nil
            case .dashboard, .containers:
                break
            }
        } catch {
            operationIssue = issue(
                title: "\(section.rawValue) unavailable",
                error: error,
                recovery: "Verify the Apple container CLI supports this command and the runtime is running."
            )
        }
    }

    func startSelectedContainer() async {
        guard let selectedContainer else { return }
        let containerID = selectedContainer.id
        await perform("Start failed", recovery: "Verify the container exists and `container system status` reports healthy.", busyContainerID: containerID) {
            try await runtime.start(containerID: containerID)
        }
    }

    func runContainer(_ request: RunContainerRequest) async -> Bool {
        do {
            try await runtime.runContainer(request)
            operationIssue = nil
            isRunContainerPresented = false
            await refresh()
            return true
        } catch {
            operationIssue = issue(
                title: "Run failed",
                error: error,
                recovery: "Check the image name, network access, and container system status, then retry."
            )
            return false
        }
    }

    func refreshEvents() async {
        await loadResources(for: .events)
    }

    func refreshComposeSupport() async {
        let support = await runtime.composeSupport()
        composeSupport = support
        composePreview = ComposeFilePreview(
            path: composePreview.path,
            name: composePreview.name,
            content: composePreview.content,
            detectedServices: composePreview.detectedServices,
            issues: composePreview.issues,
            pluginAvailable: support.available,
            pluginMessage: support.message
        )
    }

    func loadComposeFile(at url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            composePreview = composePreview(for: url, content: content, support: composeSupport)
            operationIssue = nil
        } catch {
            operationIssue = issue(
                title: "Compose file unavailable",
                error: error,
                recovery: "Choose a readable compose.yaml, compose.yml, or docker-compose.yml file."
            )
        }
    }

    func stopSelectedContainer() async {
        guard let selectedContainer else { return }
        let containerID = selectedContainer.id
        await perform("Stop failed", recovery: "The container may have already stopped. Refresh and retry.", busyContainerID: containerID) {
            try await runtime.stop(containerID: containerID)
        }
    }

    func restartSelectedContainer() async {
        guard let selectedContainer else { return }
        let containerID = selectedContainer.id
        await perform("Restart failed", recovery: "Stop and start the container manually from the CLI to inspect the failure.", busyContainerID: containerID) {
            try await runtime.stop(containerID: containerID)
            try await runtime.start(containerID: containerID)
        }
    }

    func deleteSelectedContainer() async {
        guard let selectedContainer else { return }
        let containerID = selectedContainer.id
        await perform("Remove failed", recovery: "Stop the container first or remove it with `container delete --force`.", busyContainerID: containerID) {
            try await runtime.delete(containerID: containerID)
        }
    }

    private func perform(_ title: String, recovery: String, busyContainerID: String? = nil, action: () async throws -> Void) async {
        if let busyContainerID {
            busyContainerIDs.insert(busyContainerID)
        }
        defer {
            if let busyContainerID {
                busyContainerIDs.remove(busyContainerID)
            }
        }

        do {
            try await action()
            operationIssue = nil
            await refresh()
        } catch {
            operationIssue = issue(title: title, error: error, recovery: recovery)
        }
    }

    private func reconcileSelectionAfterRefresh() {
        let validIDs = Set(containers.map(\.id))
        details = details.filter { validIDs.contains($0.key) }
        selectedRows = selectedRows.intersection(validIDs)

        if let selectedContainerID, validIDs.contains(selectedContainerID) {
            return
        }

        selectedContainerID = nil
        selectedRows = []
        logs = []
    }

    private func applyLiveStats(_ statsByID: [String: ContainerStats], sampledAt: Date) {
        containers = containers.map { container in
            let incomingStats = statsByID[container.id] ?? statsByID[container.name]
            guard let incomingStats else { return container }

            var updated = container
            updated.stats = mergedStats(incomingStats, preservingMissingValuesFrom: container.stats)
            updated.memoryBytes = updated.stats.memoryBytes
            return updated
        }
        recordSystemMetrics(sampledAt: sampledAt)
        operationIssue = nil
    }

    private func recordSystemMetrics(sampledAt: Date) {
        let previousContainerSamples = lastContainerStatSamples
        var updatedContainers = containers

        for index in updatedContainers.indices {
            let id = updatedContainers[index].id
            var stats = updatedContainers[index].stats
            if let previousSample = previousContainerSamples[id] {
                let elapsed = sampledAt.timeIntervalSince(previousSample.sampledAt)
                let deltaUsec = stats.cpuUsageUsec - previousSample.stats.cpuUsageUsec
                if let cpuPercent = cpuPercent(deltaUsec: deltaUsec, elapsed: elapsed) {
                    stats.cpuPercent = cpuPercent
                    updatedContainers[index].stats = stats
                    updatedContainers[index].cpuPercent = cpuPercent
                }
            }
            updatedContainers[index].memoryBytes = stats.memoryBytes
        }

        containers = updatedContainers
        let counters = SystemCounterSample(containers: updatedContainers, sampledAt: sampledAt)
        let sample = SystemMetricSample(
            sampledAt: sampledAt,
            cpuPercent: updatedContainers.reduce(0) { $0 + $1.cpuPercent },
            memoryBytes: counters.memoryBytes,
            memoryLimitBytes: counters.memoryLimitBytes,
            networkRxBytesPerSecond: rate(current: counters.networkRxBytes, previous: lastSystemCounterSample?.networkRxBytes, elapsed: counters.elapsed(since: lastSystemCounterSample)),
            networkTxBytesPerSecond: rate(current: counters.networkTxBytes, previous: lastSystemCounterSample?.networkTxBytes, elapsed: counters.elapsed(since: lastSystemCounterSample)),
            blockReadBytesPerSecond: rate(current: counters.blockReadBytes, previous: lastSystemCounterSample?.blockReadBytes, elapsed: counters.elapsed(since: lastSystemCounterSample)),
            blockWriteBytesPerSecond: rate(current: counters.blockWriteBytes, previous: lastSystemCounterSample?.blockWriteBytes, elapsed: counters.elapsed(since: lastSystemCounterSample))
        )
        systemMetrics.append(sample, limit: metricsSampleLimit)
        lastSystemCounterSample = counters
        lastContainerStatSamples = Dictionary(uniqueKeysWithValues: updatedContainers.map {
            ($0.id, TimedContainerStats(sampledAt: sampledAt, stats: $0.stats))
        })
    }

    private func mergedStats(_ incoming: ContainerStats, preservingMissingValuesFrom existing: ContainerStats) -> ContainerStats {
        ContainerStats(
            cpuPercent: incoming.cpuPercent == 0 ? existing.cpuPercent : incoming.cpuPercent,
            cpuUsageUsec: incoming.cpuUsageUsec == 0 ? existing.cpuUsageUsec : incoming.cpuUsageUsec,
            memoryBytes: incoming.memoryBytes == 0 ? existing.memoryBytes : incoming.memoryBytes,
            memoryLimitBytes: incoming.memoryLimitBytes == 0 ? existing.memoryLimitBytes : incoming.memoryLimitBytes,
            networkRxBytes: incoming.networkRxBytes == 0 ? existing.networkRxBytes : incoming.networkRxBytes,
            networkTxBytes: incoming.networkTxBytes == 0 ? existing.networkTxBytes : incoming.networkTxBytes,
            blockReadBytes: incoming.blockReadBytes == 0 ? existing.blockReadBytes : incoming.blockReadBytes,
            blockWriteBytes: incoming.blockWriteBytes == 0 ? existing.blockWriteBytes : incoming.blockWriteBytes,
            processes: incoming.processes == 0 ? existing.processes : incoming.processes
        )
    }

    private func cpuPercent(deltaUsec: Int64, elapsed: TimeInterval) -> Double? {
        guard deltaUsec >= 0, elapsed > 0 else { return nil }
        let activeCPUCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        let elapsedCapacityUsec = elapsed * 1_000_000 * Double(activeCPUCount)
        guard elapsedCapacityUsec > 0 else { return nil }
        return min(100, max(0, Double(deltaUsec) / elapsedCapacityUsec * 100))
    }

    private func rate(current: Int64, previous: Int64?, elapsed: TimeInterval?) -> Double {
        guard let previous, let elapsed, elapsed > 0, current >= previous else { return 0 }
        return Double(current - previous) / elapsed
    }

    private func clearRuntimeState() {
        containers = []
        images = []
        volumes = []
        networks = []
        configs = []
        secrets = []
        systemEvents = []
        composePreview = ComposeFilePreview.empty
        composeSupport = .unchecked
        overview = RuntimeOverview(images: 0, volumes: 0, networks: 0, storageBytes: 0)
        details = [:]
        logs = []
        selectedContainerID = nil
        selectedRows = []
        operationIssue = nil
        busyContainerIDs = []
        systemMetrics.reset()
        lastContainerStatSamples = [:]
        lastSystemCounterSample = nil
    }

    private func issue(title: String, error: Error, recovery: String) -> RuntimeIssue {
        RuntimeIssue(
            title: title,
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
            recovery: recovery
        )
    }

    private func composePreview(for url: URL, content: String, support: ComposeSupportStatus) -> ComposeFilePreview {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: [String] = []
        if trimmed.isEmpty {
            issues.append("File is empty.")
        }
        if !isAcceptedComposeFile(url) {
            issues.append("File name should be compose.yaml, compose.yml, or docker-compose.yml.")
        }
        let services = detectedComposeServices(in: content)
        if !trimmed.isEmpty, services.isEmpty {
            issues.append("No top-level services block was detected by the best-effort scanner.")
        }
        if !support.available {
            issues.append("Runtime actions are unavailable until the Apple container Compose plugin is installed.")
        }
        return ComposeFilePreview(
            path: url.path,
            name: url.lastPathComponent,
            content: content,
            detectedServices: services,
            issues: issues,
            pluginAvailable: support.available,
            pluginMessage: support.message
        )
    }

    private func isAcceptedComposeFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return ["compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml"].contains(name)
    }

    private func detectedComposeServices(in content: String) -> [String] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let servicesIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "services:" }) else {
            return []
        }
        var services: [String] = []
        for line in lines.dropFirst(servicesIndex + 1) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            let leadingSpaces = line.prefix { $0 == " " }.count
            if leadingSpaces == 0 {
                break
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if leadingSpaces == 2, trimmed.hasSuffix(":") {
                let serviceName = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                if !serviceName.isEmpty, !serviceName.hasPrefix("#") {
                    services.append(serviceName)
                }
            }
        }
        return services
    }
}

private struct TimedContainerStats {
    var sampledAt: Date
    var stats: ContainerStats
}

private struct SystemCounterSample {
    var sampledAt: Date
    var memoryBytes: Int64
    var memoryLimitBytes: Int64
    var networkRxBytes: Int64
    var networkTxBytes: Int64
    var blockReadBytes: Int64
    var blockWriteBytes: Int64

    init(containers: [ContainerItem], sampledAt: Date) {
        self.sampledAt = sampledAt
        memoryBytes = containers.reduce(Int64(0)) { $0 + $1.stats.memoryBytes }
        memoryLimitBytes = containers.reduce(Int64(0)) { $0 + $1.stats.memoryLimitBytes }
        networkRxBytes = containers.reduce(Int64(0)) { $0 + $1.stats.networkRxBytes }
        networkTxBytes = containers.reduce(Int64(0)) { $0 + $1.stats.networkTxBytes }
        blockReadBytes = containers.reduce(Int64(0)) { $0 + $1.stats.blockReadBytes }
        blockWriteBytes = containers.reduce(Int64(0)) { $0 + $1.stats.blockWriteBytes }
    }

    func elapsed(since previous: SystemCounterSample?) -> TimeInterval? {
        guard let previous else { return nil }
        return sampledAt.timeIntervalSince(previous.sampledAt)
    }
}
