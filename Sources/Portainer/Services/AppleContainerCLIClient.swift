import Foundation

enum AppleContainerCLIClientError: Error, Equatable, LocalizedError {
    case emptyContainerID(operation: String)
    case invalidLogLineLimit(Int)
    case invalidSystemLogWindow(String)

    var errorDescription: String? {
        switch self {
        case .emptyContainerID(let operation):
            return "Container ID is required to \(operation)."
        case .invalidLogLineLimit(let lines):
            return "Log line limit must be greater than zero; received \(lines)."
        case .invalidSystemLogWindow(let value):
            return "System log window must use a value like 5m, 1h, or 2d; received \(value)."
        }
    }
}

protocol ContainerRuntime {
    func listContainers() async throws -> [ContainerItem]
    func stats() async throws -> [String: ContainerStats]
    func listImages() async throws -> [ImageItem]
    func listVolumes() async throws -> [VolumeItem]
    func listNetworks() async throws -> [NetworkAttachmentItem]
    func listConfigs() async throws -> [DerivedConfigItem]
    func listSecrets() async throws -> [DerivedSecretReference]
    func systemEvents(last: String) async throws -> [SystemEventLine]
    func composeSupport() async -> ComposeSupportStatus
    func overview() async throws -> RuntimeOverview
    func logs(containerID: String, lines: Int) async throws -> [ContainerLogLine]
    func inspect(containerID: String) async throws -> ContainerDetail
    func runContainer(_ request: RunContainerRequest) async throws
    func start(containerID: String) async throws
    func stop(containerID: String) async throws
    func delete(containerID: String) async throws
}

struct AppleContainerCLIClient: ContainerRuntime {
    private let runner: CommandRunning

    init(runner: CommandRunning = ProcessRunner()) {
        self.runner = runner
    }

    func listContainers() async throws -> [ContainerItem] {
        try await runOnBackground {
            try preflight()
            let output = try runner.run("container", arguments: ["list", "--all", "--format", "json"]).stdout
            let containers = try AppleContainerJSONParser.parseContainers(output)
            let statsOutput = try runner.run("container", arguments: ["stats", "--no-stream", "--format", "json"]).stdout
            let stats = try AppleContainerJSONParser.parseStats(statsOutput)
            return AppleContainerJSONParser.mergeStats(stats, into: containers)
        }
    }

    func stats() async throws -> [String: ContainerStats] {
        try await runOnBackground {
            let statsOutput = try runner.run("container", arguments: ["stats", "--no-stream", "--format", "json"]).stdout
            return try AppleContainerJSONParser.parseStats(statsOutput)
        }
    }

    func listImages() async throws -> [ImageItem] {
        try await runOnBackground {
            let output = try runner.run("container", arguments: ["image", "list", "--format", "json"]).stdout
            return try AppleContainerJSONParser.parseImages(output)
        }
    }

    func listVolumes() async throws -> [VolumeItem] {
        try await runOnBackground {
            let output = try runner.run("container", arguments: ["volume", "list", "--format", "json"]).stdout
            return try AppleContainerJSONParser.parseVolumes(output)
        }
    }

    func listNetworks() async throws -> [NetworkAttachmentItem] {
        try await runOnBackground {
            let output = try runner.run("container", arguments: ["list", "--all", "--format", "json"]).stdout
            return try AppleContainerJSONParser.parseNetworkAttachments(output)
        }
    }

    func listConfigs() async throws -> [DerivedConfigItem] {
        try await runOnBackground {
            let output = try runner.run("container", arguments: ["list", "--all", "--format", "json"]).stdout
            return try AppleContainerJSONParser.parseDerivedConfigs(output)
        }
    }

    func listSecrets() async throws -> [DerivedSecretReference] {
        try await runOnBackground {
            let output = try runner.run("container", arguments: ["list", "--all", "--format", "json"]).stdout
            return try AppleContainerJSONParser.parseDerivedSecrets(output)
        }
    }

    func systemEvents(last: String) async throws -> [SystemEventLine] {
        try await runOnBackground {
            let last = try Self.validatedSystemLogWindow(last)
            do {
                let result = try runner.run("container", arguments: ["system", "logs", "--last", last])
                return AppleContainerJSONParser.parseSystemEvents(result.stdout + result.stderr)
            } catch let ProcessRunnerError.nonZeroExit(_, _, stderr) {
                return AppleContainerJSONParser.parseSystemEvents(stderr)
            }
        }
    }

    func composeSupport() async -> ComposeSupportStatus {
        await runOnBackgroundNonThrowing {
            do {
                _ = try runner.run("container", arguments: ["compose", "--help"])
                return ComposeSupportStatus(
                    available: true,
                    message: "Compose plugin detected. Runtime actions can be wired in a follow-up."
                )
            } catch let ProcessRunnerError.nonZeroExit(_, _, stderr) {
                let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return ComposeSupportStatus(
                    available: false,
                    message: message.isEmpty ? "Compose plugin is not available." : message
                )
            } catch {
                return ComposeSupportStatus(
                    available: false,
                    message: error.localizedDescription
                )
            }
        }
    }

    func overview() async throws -> RuntimeOverview {
        try await runOnBackground {
            let images = try countItems(["image", "list", "--format", "json"])
            let volumes = try countItems(["volume", "list", "--format", "json"])
            let containerList = try? runner.run("container", arguments: ["list", "--all", "--format", "json"]).stdout
            let networks = Set((try? AppleContainerJSONParser.parseNetworkAttachments(containerList ?? ""))?.map(\.networkName) ?? []).count
            let diskUsage = try? runner.run("container", arguments: ["system", "df", "--format", "json"]).stdout
            let storageBytes = (try? AppleContainerJSONParser.parseDiskUsageBytes(diskUsage ?? "")) ?? 0
            return RuntimeOverview(images: images, volumes: volumes, networks: networks, storageBytes: storageBytes)
        }
    }

    func logs(containerID: String, lines: Int) async throws -> [ContainerLogLine] {
        try await runOnBackground {
            let containerID = try validatedContainerID(containerID, operation: "fetch logs")
            guard lines > 0 else {
                throw AppleContainerCLIClientError.invalidLogLineLimit(lines)
            }
            let output = try runner.run("container", arguments: ["logs", "-n", "\(lines)", containerID]).stdout
            return AppleContainerJSONParser.parseLogs(output)
        }
    }

    func inspect(containerID: String) async throws -> ContainerDetail {
        try await runOnBackground {
            let containerID = try validatedContainerID(containerID, operation: "inspect a container")
            let output = try runner.run("container", arguments: ["inspect", containerID]).stdout
            return try AppleContainerJSONParser.parseDetail(output, fallbackID: containerID)
        }
    }

    func runContainer(_ request: RunContainerRequest) async throws {
        try await command(Self.runArguments(for: request))
    }

    func start(containerID: String) async throws {
        try await command(["start", try Self.validatedContainerID(containerID, operation: "start a container")])
    }

    func stop(containerID: String) async throws {
        try await command(["stop", try Self.validatedContainerID(containerID, operation: "stop a container")])
    }

    func delete(containerID: String) async throws {
        try await command(["delete", try Self.validatedContainerID(containerID, operation: "delete a container")])
    }

    private func command(_ arguments: [String]) async throws {
        try await runOnBackground {
            _ = try runner.run("container", arguments: arguments)
        }
    }

    static func runArguments(for request: RunContainerRequest) throws -> [String] {
        try request.validate()
        var arguments = ["run"]
        if request.detached {
            arguments.append("-d")
        }
        if !request.trimmedName.isEmpty {
            arguments.append(contentsOf: ["--name", request.trimmedName])
        }
        arguments.append(request.trimmedImage)
        arguments.append(contentsOf: request.arguments.filter { !$0.isEmpty })
        return arguments
    }

    private static func validatedSystemLogWindow(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[1-9][0-9]*[smhd]?$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            throw AppleContainerCLIClientError.invalidSystemLogWindow(value)
        }
        return trimmed
    }

    private func countItems(_ arguments: [String]) throws -> Int {
        let output = try runner.run("container", arguments: arguments).stdout
        return try AppleContainerJSONParser.itemCount(output)
    }

    private func preflight() throws {
        _ = try runner.run("container", arguments: ["system", "status"])
    }

    private static func validatedContainerID(_ containerID: String, operation: String) throws -> String {
        let trimmedID = containerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            throw AppleContainerCLIClientError.emptyContainerID(operation: operation)
        }
        return trimmedID
    }

    private func validatedContainerID(_ containerID: String, operation: String) throws -> String {
        try Self.validatedContainerID(containerID, operation: operation)
    }

    private func runOnBackground<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            try work()
        }.value
    }

    private func runOnBackgroundNonThrowing<T>(_ work: @escaping () -> T) async -> T {
        await Task.detached(priority: .userInitiated) {
            work()
        }.value
    }

}
