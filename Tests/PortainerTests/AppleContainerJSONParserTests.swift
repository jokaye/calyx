import XCTest
@testable import Portainer

final class AppleContainerJSONParserTests: XCTestCase {
    func testParsesContainerListArray() throws {
        let json = """
        [
          {
            "id": "web-app",
            "image": "nginx:1.25",
            "status": "running",
            "cpuPercent": 2.1,
            "memoryBytes": 128400000,
            "ipAddress": "192.168.64.17",
            "uptime": "2h 35m",
            "platform": "linux/arm64"
          }
        ]
        """

        let containers = try AppleContainerJSONParser.parseContainers(json)

        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers[0].id, "web-app")
        XCTAssertEqual(containers[0].status, .running)
        XCTAssertEqual(containers[0].memoryBytes, 128_400_000)
        XCTAssertEqual(containers[0].ipAddress, "192.168.64.17")
    }

    func testParsesItemsWrapper() throws {
        let json = """
        {
          "items": [
            {
              "name": "worker",
              "Image": "python:3.11-slim",
              "State": "exited"
            }
          ]
        }
        """

        let containers = try AppleContainerJSONParser.parseContainers(json)

        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers[0].name, "worker")
        XCTAssertEqual(containers[0].image, "python:3.11-slim")
        XCTAssertEqual(containers[0].status, .exited)
        XCTAssertEqual(containers[0].uptime, "-")
        XCTAssertEqual(containers[0].ipAddress, "-")
    }

    func testParsesAppleContainerListNestedStatusObject() throws {
        let json = """
        [
          {
            "configuration": {
              "image": {
                "reference": "docker.io/library/python:slim"
              },
              "platform": {
                "architecture": "arm64",
                "os": "linux"
              }
            },
            "id": "18b8b28d-d817-424e-9b5a-0c97ea4f4422",
            "status": {
              "networks": [
                {
                  "ipv4Address": "192.168.64.2/24"
                }
              ],
              "startedDate": "2026-06-15T07:32:24Z",
              "state": "running"
            }
          }
        ]
        """

        let containers = try AppleContainerJSONParser.parseContainers(json)

        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers[0].id, "18b8b28d-d817-424e-9b5a-0c97ea4f4422")
        XCTAssertEqual(containers[0].image, "docker.io/library/python:slim")
        XCTAssertEqual(containers[0].status, .running)
        XCTAssertEqual(containers[0].ipAddress, "192.168.64.2/24")
        XCTAssertEqual(containers[0].uptime, "2026-06-15T07:32:24Z")
        XCTAssertEqual(containers[0].platform, "linux/arm64")
    }

    func testParsesAppleContainerStatsFieldNames() throws {
        let json = """
        [
          {
            "id": "18b8b28d-d817-424e-9b5a-0c97ea4f4422",
            "cpuUsageUsec": 87159,
            "memoryUsageBytes": 32165888,
            "memoryLimitBytes": 1073741824,
            "networkRxBytes": 148326,
            "networkTxBytes": 602,
            "blockReadBytes": 13492224,
            "blockWriteBytes": 1884160,
            "numProcesses": 1
          }
        ]
        """

        let stats = try AppleContainerJSONParser.parseStats(json)
        let item = try XCTUnwrap(stats["18b8b28d-d817-424e-9b5a-0c97ea4f4422"])

        XCTAssertEqual(item.cpuUsageUsec, 87_159)
        XCTAssertEqual(item.memoryBytes, 32_165_888)
        XCTAssertEqual(item.memoryLimitBytes, 1_073_741_824)
        XCTAssertEqual(item.networkRxBytes, 148_326)
        XCTAssertEqual(item.networkTxBytes, 602)
        XCTAssertEqual(item.blockReadBytes, 13_492_224)
        XCTAssertEqual(item.blockWriteBytes, 1_884_160)
        XCTAssertEqual(item.processes, 1)
    }

    func testParsesInspectObject() throws {
        let json = """
        {
          "id": "kratos",
          "image": "docker.io/ory/kratos:v25.4.0",
          "runtime": "container-runtime-linux",
          "network": {
            "address": "192.168.64.17",
            "gateway": "192.168.64.1",
            "name": "default"
          }
        }
        """

        let detail = try AppleContainerJSONParser.parseDetail(json, fallbackID: "kratos")

        XCTAssertEqual(detail.containerID, "kratos")
        XCTAssertEqual(detail.imageReference, "docker.io/ory/kratos:v25.4.0")
        XCTAssertEqual(detail.address, "192.168.64.17/24")
        XCTAssertEqual(detail.gateway, "192.168.64.1")
    }

    func testParsesAppleInspectEnvironmentAndMounts() throws {
        let json = """
        {
          "id": "python",
          "configuration": {
            "image": {
              "reference": "docker.io/library/python:slim"
            },
            "initProcess": {
              "environment": [
                "PATH=/usr/local/bin:/usr/bin",
                "TOKEN=a=b=c",
                "EMPTY="
              ],
              "arguments": ["python3"],
              "terminal": true
            },
            "mounts": [
              {
                "source": "cache",
                "destination": "/data",
                "type": {
                  "virtiofs": {}
                },
                "options": ["ro", "nodev"]
              }
            ]
          }
        }
        """

        let detail = try AppleContainerJSONParser.parseDetail(json, fallbackID: "python")

        XCTAssertEqual(detail.environment.count, 3)
        XCTAssertEqual(detail.environment[1].name, "TOKEN")
        XCTAssertEqual(detail.environment[1].value, "a=b=c")
        XCTAssertEqual(detail.environment[2].value, "")
        XCTAssertEqual(detail.mounts.count, 1)
        XCTAssertEqual(detail.mounts[0].source, "cache")
        XCTAssertEqual(detail.mounts[0].destination, "/data")
        XCTAssertEqual(detail.mounts[0].type, "virtiofs")
        XCTAssertEqual(detail.mounts[0].options, ["ro", "nodev"])
        XCTAssertEqual(detail.terminal, "true")
        XCTAssertEqual(detail.arguments, "python3")
    }

    func testParsesAppleImageList() throws {
        let json = """
        [
          {
            "configuration": {
              "creationDate": "2026-06-11T01:08:45Z",
              "descriptor": {
                "digest": "sha256:44dd",
                "mediaType": "application/vnd.oci.image.index.v1+json",
                "size": 10365
              },
              "name": "docker.io/library/python:slim"
            },
            "id": "44dd",
            "variants": [
              {
                "digest": "sha256:3d78",
                "platform": {
                  "architecture": "arm64",
                  "os": "linux"
                },
                "size": 43676401
              }
            ]
          }
        ]
        """

        let images = try AppleContainerJSONParser.parseImages(json)

        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images[0].name, "docker.io/library/python:slim")
        XCTAssertEqual(images[0].digest, "sha256:44dd")
        XCTAssertEqual(images[0].mediaType, "application/vnd.oci.image.index.v1+json")
        XCTAssertEqual(images[0].sizeBytes, 43_676_401)
        XCTAssertEqual(images[0].platforms, "linux/arm64")
    }

    func testParsesVolumeList() throws {
        let json = """
        [
          {
            "name": "cache",
            "sizeInBytes": 4096,
            "creationDate": "2026-06-15T10:00:00Z",
            "containerCount": 2
          }
        ]
        """

        let volumes = try AppleContainerJSONParser.parseVolumes(json)

        XCTAssertEqual(volumes.count, 1)
        XCTAssertEqual(volumes[0].name, "cache")
        XCTAssertEqual(volumes[0].sizeBytes, 4096)
        XCTAssertEqual(volumes[0].createdAt, "2026-06-15T10:00:00Z")
        XCTAssertEqual(volumes[0].containerCount, 2)
    }

    func testMissingInspectFieldsDoNotUseSampleValues() throws {
        let detail = try AppleContainerJSONParser.parseDetail(#"{"id":"worker","image":"python:3.11"}"#, fallbackID: "worker")

        XCTAssertEqual(detail.hostname, "-")
        XCTAssertEqual(detail.address, "-")
        XCTAssertEqual(detail.gateway, "-")
        XCTAssertEqual(detail.network, "-")
        XCTAssertEqual(detail.domain, "-")
        XCTAssertEqual(detail.cpus, "-")
        XCTAssertEqual(detail.memory, "-")
        XCTAssertEqual(detail.user, "-")
        XCTAssertEqual(detail.environment, [])
        XCTAssertEqual(detail.mounts, [])
    }

    func testLogsWithoutTimestampDoNotUseSampleTimestamp() {
        let logs = AppleContainerJSONParser.parseLogs("""
        ready for connections
        2026-06-15T12:00:00Z INF service started
        """)

        XCTAssertEqual(logs[0].timestamp, "-")
        XCTAssertEqual(logs[0].level, "LOG")
        XCTAssertEqual(logs[0].message, "ready for connections")
        XCTAssertEqual(logs[1].timestamp, "2026-06-15T12:00:00Z")
        XCTAssertEqual(logs[1].level, "INF")
        XCTAssertEqual(logs[1].message, "service started")
    }

    func testParsesNetworkAttachmentsFromContainerList() throws {
        let json = """
        [
          {
            "configuration": {
              "id": "web",
              "networks": [
                {
                  "network": "default",
                  "options": {
                    "hostname": "web-host",
                    "mtu": 1280
                  }
                }
              ]
            },
            "id": "web",
            "status": {
              "state": "running",
              "networks": [
                {
                  "network": "default",
                  "ipv4Address": "192.168.64.4/24",
                  "ipv4Gateway": "192.168.64.1",
                  "hostname": "web-runtime",
                  "mtu": 1280
                }
              ]
            }
          }
        ]
        """

        let networks = try AppleContainerJSONParser.parseNetworkAttachments(json)

        XCTAssertEqual(networks.count, 1)
        XCTAssertEqual(networks[0].networkName, "default")
        XCTAssertEqual(networks[0].containerID, "web")
        XCTAssertEqual(networks[0].status, .running)
        XCTAssertEqual(networks[0].address, "192.168.64.4/24")
        XCTAssertEqual(networks[0].gateway, "192.168.64.1")
        XCTAssertEqual(networks[0].hostname, "web-runtime")
        XCTAssertEqual(networks[0].mtu, "1280")
    }

    func testParsesStoppedNetworkAttachmentWithoutRuntimeAddress() throws {
        let json = """
        [
          {
            "configuration": {
              "id": "worker",
              "networks": [
                {
                  "network": "default",
                  "options": {
                    "hostname": "worker",
                    "mtu": 1280
                  }
                }
              ]
            },
            "id": "worker",
            "status": {
              "state": "stopped",
              "networks": []
            }
          }
        ]
        """

        let networks = try AppleContainerJSONParser.parseNetworkAttachments(json)

        XCTAssertEqual(networks.count, 1)
        XCTAssertEqual(networks[0].status, .stopped)
        XCTAssertEqual(networks[0].address, "-")
        XCTAssertEqual(networks[0].gateway, "-")
        XCTAssertEqual(networks[0].hostname, "worker")
    }

    func testParsesDerivedConfigsAndMasksSecrets() throws {
        let json = """
        [
          {
            "configuration": {
              "id": "api",
              "initProcess": {
                "environment": [
                  "PATH=/usr/bin",
                  "API_TOKEN=should-not-display",
                  "PYTHON_SHA256=abc"
                ]
              },
              "labels": {
                "com.example.mode": "dev",
                "db.password": "should-not-display"
              }
            },
            "id": "api"
          }
        ]
        """

        let configs = try AppleContainerJSONParser.parseDerivedConfigs(json)
        let secrets = try AppleContainerJSONParser.parseDerivedSecrets(json)

        XCTAssertEqual(configs.map(\.key), ["PATH", "PYTHON_SHA256", "com.example.mode"])
        XCTAssertTrue(configs.contains { $0.key == "PATH" && $0.value == "/usr/bin" })
        XCTAssertFalse(configs.contains { $0.key == "API_TOKEN" })
        XCTAssertEqual(secrets.map(\.key), ["API_TOKEN", "db.password"])
    }

    func testParsesSystemEventLines() {
        let events = AppleContainerJSONParser.parseSystemEvents("""
        2026-06-15T10:00:00Z INFO containerd Started service
        log: Could not open local log store
        """)

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].timestamp, "2026-06-15T10:00:00Z")
        XCTAssertEqual(events[0].level, "INFO")
        XCTAssertEqual(events[0].service, "containerd")
        XCTAssertEqual(events[1].timestamp, "-")
        XCTAssertEqual(events[1].level, "ERROR")
        XCTAssertEqual(events[1].service, "system")
    }

    func testInvalidJSONFailsFast() {
        XCTAssertThrowsError(try AppleContainerJSONParser.parseContainers("not json")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unable to parse"))
        }
    }

    func testInvalidInspectJSONFailsFastWithParserError() {
        XCTAssertThrowsError(try AppleContainerJSONParser.parseDetail("not json", fallbackID: "web")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unable to parse"))
        }
    }

    func testOverviewOnlyCountsSupportedResources() async throws {
        let runner = MockCommandRunner(stubs: [
            "image list --format json": .success(ProcessResult(exitCode: 0, stdout: #"[{"name":"alpine"},{"name":"nginx"}]"#, stderr: "")),
            "volume list --format json": .success(ProcessResult(exitCode: 0, stdout: #"[{"name":"cache"}]"#, stderr: "")),
            "list --all --format json": .success(ProcessResult(exitCode: 0, stdout: #"[{"id":"web","configuration":{"networks":[{"network":"default"}]},"status":{"state":"running","networks":[{"network":"default"}]}}]"#, stderr: ""))
        ])
        let client = AppleContainerCLIClient(runner: runner)

        let overview = try await client.overview()

        XCTAssertEqual(overview.images, 2)
        XCTAssertEqual(overview.volumes, 1)
        XCTAssertEqual(overview.networks, 1)
        XCTAssertFalse(runner.calls.contains(["container", "network", "list", "--format", "json"]))
    }

    func testSystemEventsReturnsDiagnosticLinesFromCLIStderr() async throws {
        let runner = MockCommandRunner(stubs: [
            "system logs --last 5m": .failure(ProcessRunnerError.nonZeroExit(
                command: "container system logs --last 5m",
                code: 65,
                stderr: "log: Could not open local log store"
            ))
        ])
        let client = AppleContainerCLIClient(runner: runner)

        let events = try await client.systemEvents(last: "5m")

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].level, "ERROR")
        XCTAssertTrue(events[0].message.contains("Could not open local log store"))
    }

    func testSystemEventsRejectsInvalidWindowBeforeRunningCLI() async throws {
        let runner = MockCommandRunner(stubs: [:])
        let client = AppleContainerCLIClient(runner: runner)

        await XCTAssertThrowsErrorAsync({
            try await client.systemEvents(last: "all")
        }) { error in
            XCTAssertTrue(error.localizedDescription.contains("System log window"))
        }
        XCTAssertEqual(runner.calls, [])
    }

    func testListContainersPropagatesStatsParseFailure() async throws {
        let runner = MockCommandRunner(stubs: [
            "system status": .success(ProcessResult(exitCode: 0, stdout: "status running", stderr: "")),
            "list --all --format json": .success(ProcessResult(exitCode: 0, stdout: #"[{"id":"web","image":"nginx","status":"running"}]"#, stderr: "")),
            "stats --no-stream --format json": .success(ProcessResult(exitCode: 0, stdout: "not json", stderr: ""))
        ])
        let client = AppleContainerCLIClient(runner: runner)

        await XCTAssertThrowsErrorAsync({
            try await client.listContainers()
        }) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unable to parse"))
        }
    }

    func testLogsRejectsInvalidLineLimitBeforeRunningCLI() async throws {
        let runner = MockCommandRunner(stubs: [:])
        let client = AppleContainerCLIClient(runner: runner)

        await XCTAssertThrowsErrorAsync({
            try await client.logs(containerID: "web", lines: 0)
        }) { error in
            XCTAssertTrue(error.localizedDescription.contains("Log line limit"))
        }
        XCTAssertEqual(runner.calls, [])
    }

    func testInspectRejectsEmptyContainerIDBeforeRunningCLI() async throws {
        let runner = MockCommandRunner(stubs: [:])
        let client = AppleContainerCLIClient(runner: runner)

        await XCTAssertThrowsErrorAsync({
            try await client.inspect(containerID: "   ")
        }) { error in
            XCTAssertTrue(error.localizedDescription.contains("Container ID"))
        }
        XCTAssertEqual(runner.calls, [])
    }
}

private final class MockCommandRunner: CommandRunning {
    private let lock = NSLock()
    private var stubs: [String: Result<ProcessResult, Error>]
    private var recordedCalls: [[String]] = []

    init(stubs: [String: Result<ProcessResult, Error>]) {
        self.stubs = stubs
    }

    var calls: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }

    func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        let key = arguments.joined(separator: " ")

        lock.lock()
        recordedCalls.append([executable] + arguments)
        let result = stubs[key]
        lock.unlock()

        guard let result else {
            throw ProcessRunnerError.launchFailed("Unexpected command: \(key)")
        }
        return try result.get()
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: () async throws -> T,
    _ validation: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        validation(error)
    }
}
