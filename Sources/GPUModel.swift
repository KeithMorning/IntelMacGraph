import Foundation

enum GPUMode: Int, CaseIterable {
    case integrated = 0, discrete = 1, automatic = 2

    var title: String {
        switch self {
        case .integrated: return "集成显卡"
        case .discrete: return "独立显卡"
        case .automatic: return "自动切换"
        }
    }

    var badge: String {
        switch self {
        case .integrated: return "集"
        case .discrete: return "独"
        case .automatic: return "自"
        }
    }

    var symbol: String {
        switch self {
        case .integrated: return "leaf"
        case .discrete: return "bolt"
        case .automatic: return "arrow.triangle.2.circlepath"
        }
    }

    var command: String { "/usr/bin/pmset -a gpuswitch \(rawValue)" }
}

enum GPUPolicy {
    case manual(GPUMode)
    case byPowerSource

    var command: String {
        switch self {
        case .manual(let mode): return mode.command
        case .byPowerSource: return "/usr/bin/pmset -b gpuswitch 0 -c gpuswitch 1"
        }
    }

    func matches(_ settings: GPUSettings) -> Bool {
        switch self {
        case .manual(let mode):
            return !settings.profiles.isEmpty && settings.profiles.values.allSatisfy { $0 == mode }
        case .byPowerSource:
            return settings.profiles["Battery Power"] == .integrated
                && settings.profiles["AC Power"] == .discrete
        }
    }
}

struct GPUSettings {
    let profiles: [String: GPUMode]

    init(_ output: String) {
        var values: [String: GPUMode] = [:]
        var profile: String?
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":"), !line.hasPrefix(" "), !line.hasPrefix("\t") {
                profile = String(trimmed.dropLast())
            }
            let fields = trimmed.split(whereSeparator: { $0.isWhitespace })
            if fields.count == 2, fields[0] == "gpuswitch",
               let value = Int(fields[1]), let mode = GPUMode(rawValue: value),
               let profile {
                values[profile] = mode
            }
        }
        profiles = values
    }

    func mode(for source: String?) -> GPUMode? {
        if let source, let mode = profiles[source] { return mode }
        // A uniform policy is unambiguous even if the power source is unavailable.
        let modes = Set(profiles.values.map(\.rawValue))
        return modes.count == 1 ? modes.first.flatMap(GPUMode.init(rawValue:)) : nil
    }

    static func powerSource(_ output: String) -> String? {
        guard let line = output.components(separatedBy: .newlines).first,
              line.hasPrefix("Now drawing from '") else { return nil }
        return line.components(separatedBy: "'").dropFirst().first
    }
}

enum Shell {
    static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "IntelMacGraph", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return output
    }
}
