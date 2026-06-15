import Foundation

struct ProcessResult: Equatable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

enum ProcessRunnerError: Error, Equatable, LocalizedError {
    case missingExecutable(String)
    case launchFailed(String)
    case nonZeroExit(command: String, code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let executable):
            return "\(executable) was not found in PATH."
        case .launchFailed(let message):
            return message
        case .nonZeroExit(let command, let code, let stderr):
            return "\(command) exited with code \(code): \(stderr)"
        }
    }
}

protocol CommandRunning {
    func run(_ executable: String, arguments: [String]) throws -> ProcessResult
}

struct ProcessRunner: CommandRunning {
    func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        let resolvedExecutable = try resolveExecutable(executable)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedExecutable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        let result = ProcessResult(exitCode: process.terminationStatus, stdout: output, stderr: errorOutput)

        if result.exitCode != 0 {
            throw ProcessRunnerError.nonZeroExit(
                command: ([executable] + arguments).joined(separator: " "),
                code: result.exitCode,
                stderr: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return result
    }

    private func resolveExecutable(_ executable: String) throws -> String {
        if executable.contains("/") {
            guard FileManager.default.isExecutableFile(atPath: executable) else {
                throw ProcessRunnerError.missingExecutable(executable)
            }
            return executable
        }

        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin")
            .split(separator: ":")
            .map(String.init)

        for path in paths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(executable).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        throw ProcessRunnerError.missingExecutable(executable)
    }
}
