import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ContainerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Dashboard")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 18) {
                SummaryCard(title: "Containers", value: "\(store.containers.count)", detail: containerSummary, dot: store.runningCount > 0 ? .green : nil)
                SummaryCard(title: "Images", value: "\(store.overview.images)", detail: imageSummary, dot: nil)
                SummaryCard(title: "Volumes", value: "\(store.overview.volumes)", detail: volumeSummary, dot: nil)
                SummaryCard(title: "Networks", value: "\(store.overview.networks)", detail: networkSummary, dot: nil)
            }

            GlassCard(cornerRadius: 14, padding: 0) {
                VStack(spacing: 0) {
                    HStack {
                        SectionTitle(title: "Containers")
                        Spacer()
                        Button("View all") {
                            store.showSection(.containers)
                            store.selectedRows.removeAll()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.blue)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                    ContainerTableHeader(compact: true)
                        .padding(.horizontal, 22)

                    if store.containers.isEmpty {
                        EmptyContainersView(
                            compact: true,
                            message: "Run a container from the toolbar or create one with the Apple container CLI, then refresh.",
                            actionTitle: "Run Container"
                        ) {
                            store.showRunContainer()
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(Array(store.containers.prefix(5))) { container in
                            ContainerTableRow(container: container, compact: true, isBusy: store.isContainerBusy(container.id)) {
                                store.openDetail(container)
                            } onStart: {
                                start(container)
                            } onStop: {
                                stop(container)
                            } onRestart: {
                                restart(container)
                            }
                            .padding(.horizontal, 22)
                        }
                    }
                }
            }
            .frame(height: 316)

            Text("System")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.top, 6)

            HStack(spacing: 18) {
                MetricCard(title: "CPU", value: liveCPU.percentText, detail: metricsDetail, color: AppTheme.blue, values: metricValues(store.systemMetrics.cpuValues))
                MetricCard(title: "Memory", value: ByteFormatter.memory(liveMemoryBytes), detail: liveMemoryDetail, color: AppTheme.violet, values: metricValues(store.systemMetrics.memoryValues))
                MetricCard(title: "Disk I/O", value: ByteFormatter.rate(liveBlockBytesPerSecond), detail: liveBlockDetail, color: AppTheme.blue, values: metricValues(store.systemMetrics.blockValues))
                MetricCard(title: "Network I/O", value: ByteFormatter.rate(liveNetworkBytesPerSecond), detail: liveNetworkDetail, color: AppTheme.cyan, values: metricValues(store.systemMetrics.networkValues))
            }

            Spacer(minLength: 0)
        }
    }

    private var containerSummary: String {
        let stoppedCount = max(0, store.containers.count - store.runningCount)
        return "Running: \(store.runningCount) / Stopped: \(stoppedCount)"
    }

    private var imageSummary: String {
        guard store.overview.storageBytes > 0 else { return "Storage not reported" }
        return "Storage: \(ByteFormatter.compact(store.overview.storageBytes))"
    }

    private var volumeSummary: String {
        store.overview.volumes == 1 ? "Volume" : "Volumes"
    }

    private var networkSummary: String {
        store.overview.networks == 1 ? "Network" : "Networks"
    }

    private var latestMetricSample: SystemMetricSample? {
        store.systemMetrics.latest
    }

    private var aggregateCPU: Double {
        store.containers.reduce(0) { $0 + $1.cpuPercent }
    }

    private var aggregateMemoryBytes: Int64 {
        store.containers.reduce(Int64(0)) { $0 + $1.stats.memoryBytes }
    }

    private var aggregateMemoryLimitBytes: Int64 {
        store.containers.reduce(Int64(0)) { $0 + $1.stats.memoryLimitBytes }
    }

    private var aggregateMemoryPercent: Double {
        guard aggregateMemoryLimitBytes > 0 else { return 0 }
        return min(100, Double(aggregateMemoryBytes) / Double(aggregateMemoryLimitBytes) * 100)
    }

    private var aggregateMemoryDetail: String {
        guard aggregateMemoryLimitBytes > 0 else { return "Limit not reported" }
        return "\(aggregateMemoryPercent.percentText) of \(ByteFormatter.memory(aggregateMemoryLimitBytes))"
    }

    private var liveCPU: Double {
        latestMetricSample?.cpuPercent ?? aggregateCPU
    }

    private var liveMemoryBytes: Int64 {
        latestMetricSample?.memoryBytes ?? aggregateMemoryBytes
    }

    private var liveMemoryLimitBytes: Int64 {
        latestMetricSample?.memoryLimitBytes ?? aggregateMemoryLimitBytes
    }

    private var liveMemoryPercent: Double {
        guard liveMemoryLimitBytes > 0 else { return 0 }
        return min(100, Double(liveMemoryBytes) / Double(liveMemoryLimitBytes) * 100)
    }

    private var liveMemoryDetail: String {
        guard latestMetricSample != nil else { return "Waiting for first sample" }
        guard liveMemoryLimitBytes > 0 else { return "Limit not reported" }
        return "\(liveMemoryPercent.percentText) of \(ByteFormatter.memory(liveMemoryLimitBytes))"
    }

    private var aggregateNetworkRxBytes: Int64 {
        store.containers.reduce(Int64(0)) { $0 + $1.stats.networkRxBytes }
    }

    private var aggregateNetworkTxBytes: Int64 {
        store.containers.reduce(Int64(0)) { $0 + $1.stats.networkTxBytes }
    }

    private var aggregateNetworkBytes: Int64 {
        aggregateNetworkRxBytes + aggregateNetworkTxBytes
    }

    private var liveNetworkBytesPerSecond: Double {
        latestMetricSample?.networkBytesPerSecond ?? 0
    }

    private var liveNetworkDetail: String {
        guard let latestMetricSample else { return "Waiting for first sample" }
        return "Rx \(ByteFormatter.rate(latestMetricSample.networkRxBytesPerSecond)) / Tx \(ByteFormatter.rate(latestMetricSample.networkTxBytesPerSecond))"
    }

    private var liveBlockBytesPerSecond: Double {
        latestMetricSample?.blockBytesPerSecond ?? 0
    }

    private var liveBlockDetail: String {
        guard let latestMetricSample else { return "Waiting for first sample" }
        return "Read \(ByteFormatter.rate(latestMetricSample.blockReadBytesPerSecond)) / Write \(ByteFormatter.rate(latestMetricSample.blockWriteBytesPerSecond))"
    }

    private var metricsDetail: String {
        latestMetricSample == nil ? "Waiting for first sample" : "Live sample every 5s"
    }

    private func metricValues(_ values: [Double]) -> [Double] {
        values.isEmpty ? [0] : values
    }

    private func start(_ container: ContainerItem) {
        target(container)
        Task { await store.startSelectedContainer() }
    }

    private func stop(_ container: ContainerItem) {
        target(container)
        Task { await store.stopSelectedContainer() }
    }

    private func restart(_ container: ContainerItem) {
        target(container)
        Task { await store.restartSelectedContainer() }
    }

    private func target(_ container: ContainerItem) {
        store.selectedContainerID = container.id
        store.selectedRows.removeAll()
    }
}

struct SummaryCard: View {
    var title: String
    var value: String
    var detail: String
    var dot: Color?

    var body: some View {
        GlassCard(cornerRadius: 14, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(dot ?? AppTheme.ink)
                HStack(spacing: 6) {
                    if let dot {
                        Circle()
                            .fill(dot)
                            .frame(width: 7, height: 7)
                    }
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 138)
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var detail: String
    var color: Color
    var values: [Double]

    var body: some View {
        GlassCard(cornerRadius: 14, padding: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                Spacer(minLength: 0)
                Sparkline(values: values, color: color)
                    .frame(height: 34)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 142)
    }
}
