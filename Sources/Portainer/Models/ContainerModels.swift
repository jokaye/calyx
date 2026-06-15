import Foundation
import SwiftUI

enum AppUIMode: String, CaseIterable, Identifiable {
    case full = "Full"
    case drawer = "Drawer"

    var id: String { rawValue }

    static var saved: AppUIMode {
        guard
            let rawValue = UserDefaults.standard.string(forKey: "appUIMode"),
            let mode = AppUIMode(rawValue: rawValue)
        else {
            return .full
        }
        return mode
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case containers = "Containers"
    case images = "Images"
    case networks = "Networks"
    case volumes = "Volumes"
    case compose = "Compose"
    case configs = "Configs"
    case secrets = "Secrets"
    case events = "Events"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "house"
        case .containers: "shippingbox"
        case .images: "cube.box"
        case .networks: "point.3.connected.trianglepath.dotted"
        case .volumes: "externaldrive"
        case .compose: "square.stack.3d.up"
        case .configs: "doc.text"
        case .secrets: "lock.shield"
        case .events: "dot.radiowaves.left.and.right"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .dashboard, .containers, .images, .networks, .volumes, .compose, .configs, .secrets, .events:
            true
        }
    }
}

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case environment = "Environment"
    case mounts = "Mounts"
    case logs = "Logs"
    case inspect = "Inspect"
    case stats = "Stats"
    case terminal = "Terminal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .environment: "slider.horizontal.3"
        case .mounts: "externaldrive"
        case .logs: "doc.text"
        case .inspect: "tablecells"
        case .stats: "waveform.path.ecg"
        case .terminal: "terminal"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .overview, .environment, .mounts, .logs, .inspect, .stats:
            true
        case .terminal:
            false
        }
    }
}

enum ContainerStatus: String, CaseIterable, Codable, Equatable {
    case running = "Running"
    case exited = "Exited"
    case stopped = "Stopped"
    case paused = "Paused"
    case created = "Created"
    case unknown = "Unknown"

    init(rawStatus: String?) {
        let normalized = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if normalized.contains("running") || normalized == "up" {
            self = .running
        } else if normalized.contains("exit") {
            self = .exited
        } else if normalized.contains("stop") {
            self = .stopped
        } else if normalized.contains("pause") {
            self = .paused
        } else if normalized.contains("created") {
            self = .created
        } else {
            self = .unknown
        }
    }

    var badgeForeground: Color {
        switch self {
        case .running: Color(hex: 0x6DE6A6)
        case .exited, .stopped: Color(hex: 0xFF7C91)
        case .paused, .created: Color(hex: 0xFFD166)
        case .unknown: Color(hex: 0xB1BED0)
        }
    }

    var badgeBackground: Color {
        switch self {
        case .running: Color(hex: 0x123A2B, alpha: 0.86)
        case .exited, .stopped: Color(hex: 0x421D2A, alpha: 0.88)
        case .paused, .created: Color(hex: 0x3D2F12, alpha: 0.88)
        case .unknown: Color(hex: 0x1B2635, alpha: 0.86)
        }
    }
}

struct ContainerStats: Codable, Equatable {
    var cpuPercent: Double
    var cpuUsageUsec: Int64
    var memoryBytes: Int64
    var memoryLimitBytes: Int64
    var networkRxBytes: Int64
    var networkTxBytes: Int64
    var blockReadBytes: Int64
    var blockWriteBytes: Int64
    var processes: Int

    var memoryPercent: Double {
        guard memoryLimitBytes > 0 else { return 0 }
        return min(100, (Double(memoryBytes) / Double(memoryLimitBytes)) * 100)
    }
}

struct SystemMetricSample: Equatable {
    var sampledAt: Date
    var cpuPercent: Double
    var memoryBytes: Int64
    var memoryLimitBytes: Int64
    var networkRxBytesPerSecond: Double
    var networkTxBytesPerSecond: Double
    var blockReadBytesPerSecond: Double
    var blockWriteBytesPerSecond: Double

    var memoryPercent: Double {
        guard memoryLimitBytes > 0 else { return 0 }
        return min(100, Double(memoryBytes) / Double(memoryLimitBytes) * 100)
    }

    var networkBytesPerSecond: Double {
        networkRxBytesPerSecond + networkTxBytesPerSecond
    }

    var blockBytesPerSecond: Double {
        blockReadBytesPerSecond + blockWriteBytesPerSecond
    }
}

struct SystemMetrics: Equatable {
    private(set) var samples: [SystemMetricSample] = []

    var latest: SystemMetricSample? {
        samples.last
    }

    var cpuValues: [Double] {
        samples.map(\.cpuPercent)
    }

    var memoryValues: [Double] {
        samples.map(\.memoryPercent)
    }

    var networkValues: [Double] {
        samples.map(\.networkBytesPerSecond)
    }

    var blockValues: [Double] {
        samples.map(\.blockBytesPerSecond)
    }

    mutating func append(_ sample: SystemMetricSample, limit: Int) {
        samples.append(sample)
        if samples.count > limit {
            samples.removeFirst(samples.count - limit)
        }
    }

    mutating func reset() {
        samples = []
    }
}

struct ContainerItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var image: String
    var status: ContainerStatus
    var cpuPercent: Double
    var memoryBytes: Int64
    var uptime: String
    var ipAddress: String
    var platform: String
    var stats: ContainerStats
}

struct RunContainerRequest: Equatable {
    var name: String
    var image: String
    var arguments: [String]
    var detached = true

    enum ValidationError: Error, Equatable, LocalizedError {
        case missingImage

        var errorDescription: String? {
            switch self {
            case .missingImage:
                return "Image is required to run a container."
            }
        }
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedImage: String {
        image.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func validate() throws {
        if trimmedImage.isEmpty {
            throw ValidationError.missingImage
        }
    }
}

struct ContainerLogLine: Identifiable, Equatable {
    var id = UUID()
    var timestamp: String
    var level: String
    var tag: String
    var message: String
}

enum DerivedConfigSource: String, Equatable {
    case environment = "Environment"
    case label = "Label"
}

struct ContainerDetail: Equatable {
    var containerID: String
    var runtime: String
    var hostname: String
    var imageReference: String
    var mediaType: String
    var digest: String
    var size: String
    var address: String
    var gateway: String
    var network: String
    var domain: String
    var cpus: String
    var memory: String
    var rosetta: String
    var executable: String
    var workingDirectory: String
    var terminal: String
    var user: String
    var arguments: String
    var environment: [ContainerEnvironmentVariable]
    var mounts: [ContainerMount]
    var rawInspectJSON: String
}

struct ContainerMount: Identifiable, Equatable {
    var id: Int
    var source: String
    var destination: String
    var type: String
    var options: [String]
}

struct ContainerEnvironmentVariable: Identifiable, Equatable {
    var id: Int
    var name: String
    var value: String
    var raw: String
}

struct ImageItem: Identifiable, Equatable {
    var id: String
    var name: String
    var digest: String
    var mediaType: String
    var sizeBytes: Int64
    var createdAt: String
    var platforms: String
}

struct VolumeItem: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var sizeBytes: Int64
    var createdAt: String
    var containerCount: Int
}

struct NetworkAttachmentItem: Identifiable, Equatable {
    var id: String
    var networkName: String
    var containerID: String
    var containerName: String
    var status: ContainerStatus
    var address: String
    var gateway: String
    var hostname: String
    var mtu: String
}

struct DerivedConfigItem: Identifiable, Equatable {
    var id: String
    var containerID: String
    var containerName: String
    var source: DerivedConfigSource
    var key: String
    var value: String
}

struct DerivedSecretReference: Identifiable, Equatable {
    var id: String
    var containerID: String
    var containerName: String
    var source: DerivedConfigSource
    var key: String
}

struct ComposeFilePreview: Equatable {
    var path: String
    var name: String
    var content: String
    var detectedServices: [String]
    var issues: [String]
    var pluginAvailable: Bool
    var pluginMessage: String

    static let empty = ComposeFilePreview(
        path: "",
        name: "",
        content: "",
        detectedServices: [],
        issues: [],
        pluginAvailable: false,
        pluginMessage: "Compose plugin status has not been checked."
    )
}

struct ComposeSupportStatus: Equatable {
    var available: Bool
    var message: String

    static let unchecked = ComposeSupportStatus(
        available: false,
        message: "Compose plugin status has not been checked."
    )
}

struct SystemEventLine: Identifiable, Equatable {
    var id: Int
    var timestamp: String
    var level: String
    var service: String
    var message: String
}


struct RuntimeOverview: Equatable {
    var images: Int
    var volumes: Int
    var networks: Int
    var storageBytes: Int64
}

struct RuntimeIssue: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var recovery: String
}
