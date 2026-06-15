import Foundation

enum AppleContainerJSONParser {
    enum ParseError: Error, Equatable, LocalizedError {
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let message): "Unable to parse container CLI JSON: \(message)"
            }
        }
    }

    static func parseContainers(_ text: String) throws -> [ContainerItem] {
        let items = try jsonItems(text)
        return items.enumerated().map { index, object in
            let id = string(in: object, keys: ["id", "ID", "containerID", "containerId", "name", "Name"]) ?? "container-\(index + 1)"
            let name = string(in: object, keys: ["name", "Name", "names", "Names"]) ?? id
            let image = imageReference(in: object)
            let statusText = string(in: object, keys: ["status", "Status", "state", "State", "runtimeState"])
                ?? nestedString(in: object, path: ["status", "state"])
                ?? nestedString(in: object, path: ["Status", "State"])
            let status = ContainerStatus(rawStatus: statusText)
            let stats = stats(in: object)
            return ContainerItem(
                id: id,
                name: name,
                image: image,
                status: status,
                cpuPercent: stats.cpuPercent,
                memoryBytes: stats.memoryBytes,
                uptime: uptime(in: object),
                ipAddress: ipAddress(in: object),
                platform: platform(in: object),
                stats: stats
            )
        }
    }

    static func itemCount(_ text: String) throws -> Int {
        try jsonItems(text).count
    }

    static func parseStats(_ text: String) throws -> [String: ContainerStats] {
        let items = try jsonItems(text)
        return Dictionary(uniqueKeysWithValues: items.compactMap { object in
            guard let id = string(in: object, keys: ["id", "ID", "container", "Container", "containerID", "name", "Name"]) else {
                return nil
            }
            return (id, stats(in: object))
        })
    }

    static func parseImages(_ text: String) throws -> [ImageItem] {
        let items = try jsonItems(text)
        return items.enumerated().map { index, object in
            let id = string(in: object, keys: ["id", "ID"])
                ?? nestedString(in: object, path: ["configuration", "descriptor", "digest"])
                ?? "image-\(index + 1)"
            let name = string(in: object, keys: ["name", "Name"])
                ?? nestedString(in: object, path: ["configuration", "name"])
                ?? id
            let size = firstInt64(in: object, path: ["variants"], keys: ["size"])
                ?? int64(in: object, keys: ["size", "Size"])
                ?? nestedInt64(in: object, path: ["configuration", "descriptor", "size"])
                ?? 0
            return ImageItem(
                id: id,
                name: name,
                digest: string(in: object, keys: ["digest", "Digest"])
                    ?? nestedString(in: object, path: ["configuration", "descriptor", "digest"])
                    ?? firstString(in: object, path: ["variants"], keys: ["digest"])
                    ?? "-",
                mediaType: string(in: object, keys: ["mediaType", "MediaType"])
                    ?? nestedString(in: object, path: ["configuration", "descriptor", "mediaType"])
                    ?? "-",
                sizeBytes: size,
                createdAt: string(in: object, keys: ["created", "createdAt", "creationDate"])
                    ?? nestedString(in: object, path: ["configuration", "creationDate"])
                    ?? firstNestedString(in: object, path: ["variants"], nestedPath: ["config", "created"])
                    ?? "-",
                platforms: platforms(in: object)
            )
        }
    }

    static func parseVolumes(_ text: String) throws -> [VolumeItem] {
        let items = try jsonItems(text)
        return items.enumerated().map { index, object in
            let name = string(in: object, keys: ["name", "Name", "id", "ID"]) ?? "volume-\(index + 1)"
            return VolumeItem(
                name: name,
                sizeBytes: int64(in: object, keys: ["size", "Size", "sizeInBytes"]) ?? 0,
                createdAt: string(in: object, keys: ["created", "createdAt", "creationDate"]) ?? "-",
                containerCount: Int(int64(in: object, keys: ["containers", "containerCount", "references", "refCount"]) ?? 0)
            )
        }
    }

    static func parseNetworkAttachments(_ text: String) throws -> [NetworkAttachmentItem] {
        let items = try jsonItems(text)
        return items.flatMap { object in
            networkAttachments(in: object)
        }
    }

    static func parseDerivedConfigs(_ text: String) throws -> [DerivedConfigItem] {
        let items = try jsonItems(text)
        return items.flatMap { object -> [DerivedConfigItem] in
            let identity = containerIdentity(in: object)
            let environmentItems = environmentVariables(in: object)
                .filter { !isSensitiveKey($0.name) }
                .map {
                    DerivedConfigItem(
                        id: "\(identity.id)-env-\($0.id)",
                        containerID: identity.id,
                        containerName: identity.name,
                        source: .environment,
                        key: $0.name,
                        value: $0.value
                    )
                }
            let labelItems = labels(in: object)
                .filter { !isSensitiveKey($0.key) }
                .sorted { $0.key < $1.key }
                .map {
                    DerivedConfigItem(
                        id: "\(identity.id)-label-\($0.key)",
                        containerID: identity.id,
                        containerName: identity.name,
                        source: .label,
                        key: $0.key,
                        value: $0.value
                    )
                }
            return environmentItems + labelItems
        }
    }

    static func parseDerivedSecrets(_ text: String) throws -> [DerivedSecretReference] {
        let items = try jsonItems(text)
        return items.flatMap { object -> [DerivedSecretReference] in
            let identity = containerIdentity(in: object)
            let environmentItems = environmentVariables(in: object)
                .filter { isSensitiveKey($0.name) }
                .map {
                    DerivedSecretReference(
                        id: "\(identity.id)-env-\($0.id)",
                        containerID: identity.id,
                        containerName: identity.name,
                        source: .environment,
                        key: $0.name
                    )
                }
            let labelItems = labels(in: object)
                .filter { isSensitiveKey($0.key) }
                .sorted { $0.key < $1.key }
                .map {
                    DerivedSecretReference(
                        id: "\(identity.id)-label-\($0.key)",
                        containerID: identity.id,
                        containerName: identity.name,
                        source: .label,
                        key: $0.key
                    )
                }
            return environmentItems + labelItems
        }
    }

    static func parseSystemEvents(_ text: String) -> [SystemEventLine] {
        text.split(separator: "\n").enumerated().compactMap { index, line in
            let raw = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            let parts = raw.split(separator: " ", maxSplits: 3).map(String.init)
            let hasTimestamp = parts.first.map(isTimestampLike) ?? false
            let level = eventLevel(in: raw, parts: parts, hasTimestamp: hasTimestamp)
            let service = eventService(in: raw, parts: parts, hasTimestamp: hasTimestamp)
            return SystemEventLine(
                id: index,
                timestamp: hasTimestamp ? parts[0] : "-",
                level: level,
                service: service,
                message: raw
            )
        }
    }

    static func parseDiskUsageBytes(_ text: String) throws -> Int64 {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let json = try JSONSerialization.jsonObject(with: Data(trimmed.utf8))
        guard let object = json as? [String: Any] else {
            throw ParseError.invalidJSON("system df output must be an object")
        }
        return ["containers", "images", "volumes"].reduce(Int64(0)) { total, key in
            total + (nestedInt64(in: object, path: [key, "sizeInBytes"]) ?? 0)
        }
    }

    static func mergeStats(_ statsByID: [String: ContainerStats], into containers: [ContainerItem]) -> [ContainerItem] {
        containers.map { container in
            guard let stats = statsByID[container.id] ?? statsByID[container.name] else {
                return container
            }
            var updated = container
            updated.stats = stats
            updated.cpuPercent = stats.cpuPercent
            updated.memoryBytes = stats.memoryBytes
            return updated
        }
    }

    static func parseLogs(_ text: String) -> [ContainerLogLine] {
        text.split(separator: "\n").map { line in
            let raw = String(line)
            let parts = raw.split(separator: " ", maxSplits: 2).map(String.init)
            let hasTimestamp = parts.first?.contains("T") == true
            let timestamp = hasTimestamp ? parts[0] : "-"
            let level = hasTimestamp && parts.count >= 2 ? parts[1] : "LOG"
            let message = hasTimestamp && parts.count >= 3 ? parts[2] : raw
            return ContainerLogLine(timestamp: timestamp, level: level, tag: "container", message: message)
        }
    }

    static func parseDetail(_ text: String, fallbackID: String) throws -> ContainerDetail {
        let data = Data(text.utf8)
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ParseError.invalidJSON(error.localizedDescription)
        }

        let object: [String: Any]
        if let array = json as? [[String: Any]], let first = array.first {
            object = first
        } else if let dictionary = json as? [String: Any],
                  let items = dictionary["items"] as? [[String: Any]],
                  let first = items.first {
            object = first
        } else if let dictionary = json as? [String: Any] {
            object = dictionary
        } else {
            throw ParseError.invalidJSON("inspect output must be an object or object array")
        }

        let id = string(in: object, keys: ["id", "ID", "name", "Name"]) ?? fallbackID
        let image = imageReference(in: object)
        let address = ipAddress(in: object)
        return ContainerDetail(
            containerID: id,
            runtime: string(in: object, keys: ["runtime", "Runtime"])
                ?? nestedString(in: object, path: ["configuration", "runtimeHandler"])
                ?? "unknown",
            hostname: string(in: object, keys: ["hostname", "Hostname", "hostName"]) ?? "-",
            imageReference: image,
            mediaType: string(in: object, keys: ["mediaType", "MediaType"])
                ?? nestedString(in: object, path: ["configuration", "image", "descriptor", "mediaType"])
                ?? "-",
            digest: string(in: object, keys: ["digest", "Digest"])
                ?? nestedString(in: object, path: ["configuration", "image", "descriptor", "digest"])
                ?? "-",
            size: string(in: object, keys: ["size", "Size"])
                ?? nestedString(in: object, path: ["configuration", "image", "descriptor", "size"])
                ?? "-",
            address: normalizedCIDRAddress(address),
            gateway: nestedString(in: object, path: ["network", "gateway"])
                ?? firstString(in: object, path: ["status", "networks"], keys: ["ipv4Gateway", "gateway"])
                ?? "-",
            network: nestedString(in: object, path: ["network", "name"])
                ?? firstString(in: object, path: ["status", "networks"], keys: ["network", "name"])
                ?? "-",
            domain: string(in: object, keys: ["domain", "Domain"]) ?? "-",
            cpus: string(in: object, keys: ["cpus", "CPUs"])
                ?? nestedString(in: object, path: ["configuration", "resources", "cpus"])
                ?? "-",
            memory: string(in: object, keys: ["memory", "Memory"])
                ?? nestedString(in: object, path: ["configuration", "resources", "memoryInBytes"])
                ?? "-",
            rosetta: string(in: object, keys: ["rosetta", "Rosetta"])
                ?? nestedString(in: object, path: ["configuration", "rosetta"])
                ?? "-",
            executable: string(in: object, keys: ["executable", "Executable"])
                ?? nestedString(in: object, path: ["configuration", "initProcess", "executable"])
                ?? "-",
            workingDirectory: string(in: object, keys: ["workingDirectory", "Workdir", "workdir"])
                ?? nestedString(in: object, path: ["configuration", "initProcess", "workingDirectory"])
                ?? "-",
            terminal: string(in: object, keys: ["terminal", "Terminal"])
                ?? nestedString(in: object, path: ["configuration", "initProcess", "terminal"])
                ?? "-",
            user: string(in: object, keys: ["user", "User"])
                ?? nestedString(in: object, path: ["configuration", "initProcess", "user", "id", "uid"])
                ?? "-",
            arguments: string(in: object, keys: ["arguments", "Args", "command", "Command"])
                ?? arrayString(in: object, path: ["configuration", "initProcess", "arguments"])
                ?? "-",
            environment: environmentVariables(in: object),
            mounts: try mounts(in: object),
            rawInspectJSON: prettyJSON(data) ?? text
        )
    }

    private static func jsonItems(_ text: String) throws -> [[String: Any]] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            let json = try JSONSerialization.jsonObject(with: Data(trimmed.utf8))
            if let items = json as? [[String: Any]] {
                return items
            }
            if let dictionary = json as? [String: Any] {
                if let items = dictionary["items"] as? [[String: Any]] {
                    return items
                }
                if let containers = dictionary["containers"] as? [[String: Any]] {
                    return containers
                }
                return [dictionary]
            }
            throw ParseError.invalidJSON("top level value is not an object or array")
        } catch let error as ParseError {
            throw error
        } catch {
            throw ParseError.invalidJSON(error.localizedDescription)
        }
    }

    private static func stats(in object: [String: Any]) -> ContainerStats {
        let cpu = double(in: object, keys: ["cpu", "CPU", "cpuPercent", "cpuPercentage", "cpu_percent"]) ?? 0
        let memory = int64(in: object, keys: ["memory", "memoryBytes", "Memory", "memoryUsage", "memoryUsageBytes", "memory_usage", "memUsage"]) ?? 0
        return ContainerStats(
            cpuPercent: cpu,
            cpuUsageUsec: int64(in: object, keys: ["cpuUsageUsec", "cpuUsageUSec", "cpu_usage_usec"]) ?? 0,
            memoryBytes: memory,
            memoryLimitBytes: int64(in: object, keys: ["memoryLimit", "memoryLimitBytes", "memory_limit"]) ?? 0,
            networkRxBytes: int64(in: object, keys: ["networkRx", "networkRxBytes", "rxBytes", "rx", "network_rx"]) ?? 0,
            networkTxBytes: int64(in: object, keys: ["networkTx", "networkTxBytes", "txBytes", "tx", "network_tx"]) ?? 0,
            blockReadBytes: int64(in: object, keys: ["blockRead", "blockReadBytes", "readBytes", "block_read"]) ?? 0,
            blockWriteBytes: int64(in: object, keys: ["blockWrite", "blockWriteBytes", "writeBytes", "block_write"]) ?? 0,
            processes: Int(int64(in: object, keys: ["processes", "numProcesses", "pids", "PIDs"]) ?? 0)
        )
    }

    private static func uptime(in object: [String: Any]) -> String {
        if let value = string(in: object, keys: ["uptime", "Uptime", "runningFor", "RunningFor"]) {
            return value
        }
        if let value = nestedString(in: object, path: ["status", "startedDate"])
            ?? string(in: object, keys: ["startedDate", "StartedDate"]) {
            return value
        }
        return "-"
    }

    private static func ipAddress(in object: [String: Any]) -> String {
        string(in: object, keys: ["ip", "ipAddress", "IPAddress", "address", "Address"])
            ?? nestedString(in: object, path: ["network", "address"])
            ?? firstString(in: object, path: ["status", "networks"], keys: ["ipv4Address", "ipAddress", "address"])
            ?? "-"
    }

    private static func imageReference(in object: [String: Any]) -> String {
        string(in: object, keys: ["image", "Image", "imageName", "reference", "Reference"])
            ?? nestedString(in: object, path: ["image", "reference"])
            ?? nestedString(in: object, path: ["configuration", "image", "reference"])
            ?? "unknown"
    }

    private static func platform(in object: [String: Any]) -> String {
        if let value = string(in: object, keys: ["platform", "Platform", "osArch"]) {
            return value
        }
        let os = nestedString(in: object, path: ["configuration", "platform", "os"])
            ?? nestedString(in: object, path: ["platform", "os"])
        let architecture = nestedString(in: object, path: ["configuration", "platform", "architecture"])
            ?? nestedString(in: object, path: ["platform", "architecture"])
        if let os, let architecture {
            return "\(os)/\(architecture)"
        }
        return "linux/arm64"
    }

    private static func string(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] {
                if let string = value as? String { return string }
                if let bool = value as? Bool { return bool ? "true" : "false" }
                if let number = value as? NSNumber { return number.stringValue }
                if let strings = value as? [String] { return strings.joined(separator: ", ") }
            }
        }
        return nil
    }

    private static func nestedString(in object: [String: Any], path: [String]) -> String? {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        if let string = value as? String { return string }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func nestedInt64(in object: [String: Any], path: [String]) -> Int64? {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        if let int = value as? Int64 { return int }
        if let int = value as? Int { return Int64(int) }
        if let double = value as? Double { return Int64(double) }
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String {
            return Int64(string) ?? byteCount(string)
        }
        return nil
    }

    private static func normalizedCIDRAddress(_ address: String) -> String {
        guard address != "-" else { return "-" }
        return address.contains("/") ? address : "\(address)/24"
    }

    private static func firstString(in object: [String: Any], path: [String], keys: [String]) -> String? {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries.compactMap { string(in: $0, keys: keys) }.first
        }
        if let dictionary = value as? [String: Any] {
            return string(in: dictionary, keys: keys)
        }
        return nil
    }

    private static func firstNestedString(in object: [String: Any], path: [String], nestedPath: [String]) -> String? {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        guard let dictionaries = value as? [[String: Any]] else { return nil }
        return dictionaries.compactMap { nestedString(in: $0, path: nestedPath) }.first
    }

    private static func firstInt64(in object: [String: Any], path: [String], keys: [String]) -> Int64? {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        guard let dictionaries = value as? [[String: Any]] else { return nil }
        return dictionaries.compactMap { int64(in: $0, keys: keys) }.first
    }

    private static func array(in object: [String: Any], path: [String]) -> [[String: Any]] {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        return value as? [[String: Any]] ?? []
    }

    private static func dictionary(in object: [String: Any], path: [String]) -> [String: Any] {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        return value as? [String: Any] ?? [:]
    }

    private static func stringArray(in object: [String: Any], path: [String]) -> [String] {
        var value: Any? = object
        for key in path {
            value = (value as? [String: Any])?[key]
        }
        return value as? [String] ?? []
    }

    private static func arrayString(in object: [String: Any], path: [String]) -> String? {
        let values = stringArray(in: object, path: path)
        return values.isEmpty ? nil : values.joined(separator: " ")
    }

    private static func mounts(in object: [String: Any]) throws -> [ContainerMount] {
        let rawMounts = object["configuration"].flatMap { ($0 as? [String: Any])?["mounts"] } ?? object["mounts"]
        guard let rawMounts else { return [] }
        guard let dictionaries = rawMounts as? [[String: Any]] else {
            throw ParseError.invalidJSON("configuration.mounts must be an array")
        }

        return dictionaries.enumerated().map { index, mount in
            ContainerMount(
                id: index,
                source: string(in: mount, keys: ["source", "Source", "name", "volume"]) ?? "mount-\(index + 1)",
                destination: string(in: mount, keys: ["destination", "Destination", "target", "Target"]) ?? "-",
                type: mountType(in: mount),
                options: mountOptions(in: mount)
            )
        }
    }

    private static func environmentVariables(in object: [String: Any]) -> [ContainerEnvironmentVariable] {
        stringArray(in: object, path: ["configuration", "initProcess", "environment"])
            .enumerated()
            .map { index, raw in
                let parts = raw.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                return ContainerEnvironmentVariable(
                    id: index,
                    name: parts.first ?? raw,
                    value: parts.count > 1 ? parts[1] : "",
                    raw: raw
                )
            }
    }

    private static func labels(in object: [String: Any]) -> [String: String] {
        let rawLabels = dictionary(in: object, path: ["configuration", "labels"]).merging(dictionary(in: object, path: ["labels"])) { configured, _ in
            configured
        }
        return Dictionary(uniqueKeysWithValues: rawLabels.compactMap { key, value in
            if let string = value as? String {
                return (key, string)
            }
            if let bool = value as? Bool {
                return (key, bool ? "true" : "false")
            }
            if let number = value as? NSNumber {
                return (key, number.stringValue)
            }
            return nil
        })
    }

    private static func networkAttachments(in object: [String: Any]) -> [NetworkAttachmentItem] {
        let identity = containerIdentity(in: object)
        let status = containerStatus(in: object)
        let configuredNetworks = array(in: object, path: ["configuration", "networks"])
        let runtimeNetworks = array(in: object, path: ["status", "networks"])
        var attachments: [NetworkAttachmentItem] = []
        var seen = Set<String>()

        for (index, configuredNetwork) in configuredNetworks.enumerated() {
            let name = networkName(in: configuredNetwork) ?? "network-\(index + 1)"
            let runtimeNetwork = runtimeNetworks.first { networkName(in: $0) == name }
            attachments.append(
                networkAttachment(
                    name: name,
                    containerID: identity.id,
                    containerName: identity.name,
                    status: status,
                    configuredNetwork: configuredNetwork,
                    runtimeNetwork: runtimeNetwork,
                    index: index
                )
            )
            seen.insert(name)
        }

        for (index, runtimeNetwork) in runtimeNetworks.enumerated() {
            let name = networkName(in: runtimeNetwork) ?? "network-\(configuredNetworks.count + index + 1)"
            guard !seen.contains(name) else { continue }
            attachments.append(
                networkAttachment(
                    name: name,
                    containerID: identity.id,
                    containerName: identity.name,
                    status: status,
                    configuredNetwork: [:],
                    runtimeNetwork: runtimeNetwork,
                    index: configuredNetworks.count + index
                )
            )
        }

        return attachments
    }

    private static func networkAttachment(
        name: String,
        containerID: String,
        containerName: String,
        status: ContainerStatus,
        configuredNetwork: [String: Any],
        runtimeNetwork: [String: Any]?,
        index: Int
    ) -> NetworkAttachmentItem {
        let runtimeNetwork = runtimeNetwork ?? [:]
        let configuredOptions = dictionary(in: configuredNetwork, path: ["options"])
        return NetworkAttachmentItem(
            id: "\(name)-\(containerID)-\(index)",
            networkName: name,
            containerID: containerID,
            containerName: containerName,
            status: status,
            address: string(in: runtimeNetwork, keys: ["ipv4Address", "ipAddress", "address", "Address"]) ?? "-",
            gateway: string(in: runtimeNetwork, keys: ["ipv4Gateway", "gateway", "Gateway"]) ?? "-",
            hostname: string(in: runtimeNetwork, keys: ["hostname", "hostName"])
                ?? string(in: configuredOptions, keys: ["hostname", "hostName"])
                ?? "-",
            mtu: string(in: runtimeNetwork, keys: ["mtu", "MTU"])
                ?? string(in: configuredOptions, keys: ["mtu", "MTU"])
                ?? "-"
        )
    }

    private static func networkName(in object: [String: Any]) -> String? {
        string(in: object, keys: ["network", "name", "Name"])
    }

    private static func containerIdentity(in object: [String: Any]) -> (id: String, name: String) {
        let id = string(in: object, keys: ["id", "ID", "containerID", "containerId", "name", "Name"])
            ?? nestedString(in: object, path: ["configuration", "id"])
            ?? "container"
        let name = string(in: object, keys: ["name", "Name"])
            ?? nestedString(in: object, path: ["configuration", "id"])
            ?? id
        return (id, name)
    }

    private static func containerStatus(in object: [String: Any]) -> ContainerStatus {
        let statusText = string(in: object, keys: ["status", "Status", "state", "State", "runtimeState"])
            ?? nestedString(in: object, path: ["status", "state"])
            ?? nestedString(in: object, path: ["Status", "State"])
        return ContainerStatus(rawStatus: statusText)
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        let compact = normalized.replacingOccurrences(of: "-", with: "_")
        let markers = [
            "secret",
            "token",
            "password",
            "passwd",
            "credential",
            "api_key",
            "apikey",
            "access_key",
            "private_key",
            "auth"
        ]
        return markers.contains { compact.contains($0) }
    }

    private static func isTimestampLike(_ value: String) -> Bool {
        value.contains("T") || (value.contains("-") && value.contains(":"))
    }

    private static func eventLevel(in raw: String, parts: [String], hasTimestamp: Bool) -> String {
        let levelIndex = hasTimestamp ? 1 : 0
        if parts.indices.contains(levelIndex) {
            let token = parts[levelIndex].trimmingCharacters(in: CharacterSet(charactersIn: "[]:"))
            let uppercased = token.uppercased()
            if ["TRACE", "DEBUG", "INFO", "INF", "LOG", "NOTICE", "WARN", "WARNING", "ERROR", "ERR", "FAULT"].contains(uppercased) {
                return uppercased == "INF" ? "INFO" : uppercased
            }
        }
        let lowercased = raw.lowercased()
        if lowercased.contains("fault") { return "FAULT" }
        if lowercased.contains("error") || lowercased.contains("failed") || lowercased.contains("could not") { return "ERROR" }
        if lowercased.contains("warn") { return "WARN" }
        return "LOG"
    }

    private static func eventService(in raw: String, parts: [String], hasTimestamp: Bool) -> String {
        guard hasTimestamp else {
            return raw.lowercased().contains("container") ? "container" : "system"
        }
        let serviceIndex = hasTimestamp ? 2 : 1
        if parts.indices.contains(serviceIndex) {
            let candidate = parts[serviceIndex].trimmingCharacters(in: CharacterSet(charactersIn: "[]:"))
            if !candidate.isEmpty, candidate.count <= 40 {
                return candidate
            }
        }
        return raw.lowercased().contains("container") ? "container" : "system"
    }

    private static func mountType(in mount: [String: Any]) -> String {
        guard let value = mount["type"] ?? mount["Type"] else { return "-" }
        if let string = value as? String { return string }
        if let dictionary = value as? [String: Any], let key = dictionary.keys.sorted().first {
            return key
        }
        return "-"
    }

    private static func mountOptions(in mount: [String: Any]) -> [String] {
        guard let value = mount["options"] ?? mount["Options"] else { return [] }
        if let strings = value as? [String] { return strings }
        if let string = value as? String {
            return string.isEmpty ? [] : [string]
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().map { key in
                if let value = dictionary[key] {
                    return "\(key)=\(value)"
                }
                return key
            }
        }
        return []
    }

    private static func platforms(in object: [String: Any]) -> String {
        guard let variants = object["variants"] as? [[String: Any]] else {
            if let platform = string(in: object, keys: ["platform", "Platform"]) {
                return platform
            }
            return "-"
        }
        let values = variants.compactMap { variant -> String? in
            let os = nestedString(in: variant, path: ["platform", "os"])
                ?? nestedString(in: variant, path: ["config", "os"])
            let arch = nestedString(in: variant, path: ["platform", "architecture"])
                ?? nestedString(in: variant, path: ["config", "architecture"])
            if let os, let arch {
                return "\(os)/\(arch)"
            }
            return nil
        }
        return values.isEmpty ? "-" : Array(Set(values)).sorted().joined(separator: ", ")
    }

    private static func double(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let double = object[key] as? Double { return double }
            if let int = object[key] as? Int { return Double(int) }
            if let number = object[key] as? NSNumber { return number.doubleValue }
            if let string = object[key] as? String {
                let cleaned = string.replacingOccurrences(of: "%", with: "")
                if let value = Double(cleaned) { return value }
            }
        }
        return nil
    }

    private static func int64(in object: [String: Any], keys: [String]) -> Int64? {
        for key in keys {
            if let int = object[key] as? Int64 { return int }
            if let int = object[key] as? Int { return Int64(int) }
            if let double = object[key] as? Double { return Int64(double) }
            if let number = object[key] as? NSNumber { return number.int64Value }
            if let string = object[key] as? String {
                if let value = Int64(string) { return value }
                if let value = byteCount(string) { return value }
            }
        }
        return nil
    }

    private static func byteCount(_ string: String) -> Int64? {
        let cleaned = string
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^([0-9]+(?:\.[0-9]+)?)\s*([KMGTPE]?i?B?)?$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
            let valueRange = Range(match.range(at: 1), in: cleaned)
        else {
            return nil
        }

        let value = Double(cleaned[valueRange]) ?? 0
        let unit: String
        if let unitRange = Range(match.range(at: 2), in: cleaned) {
            unit = cleaned[unitRange].uppercased()
        } else {
            unit = "B"
        }

        let multiplier: Double
        switch unit {
        case "K", "KB": multiplier = 1_000
        case "M", "MB": multiplier = 1_000_000
        case "G", "GB": multiplier = 1_000_000_000
        case "T", "TB": multiplier = 1_000_000_000_000
        case "KI", "KIB": multiplier = 1_024
        case "MI", "MIB": multiplier = 1_048_576
        case "GI", "GIB": multiplier = 1_073_741_824
        case "TI", "TIB": multiplier = 1_099_511_627_776
        default: multiplier = 1
        }
        return Int64(value * multiplier)
    }

    private static func prettyJSON(_ data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        else { return nil }
        return String(data: prettyData, encoding: .utf8)
    }
}
