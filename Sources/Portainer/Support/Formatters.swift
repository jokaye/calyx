import Foundation
import SwiftUI

enum ByteFormatter {
    static func memory(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }
        let mb = Double(bytes) / 1_000_000
        if mb >= 1000 {
            return String(format: "%.2f GB", mb / 1000)
        }
        return String(format: "%.1f MB", mb)
    }

    static func compact(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1000, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        return String(format: value >= 10 ? "%.0f %@" : "%.1f %@", value, units[index])
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        "\(compact(Int64(max(0, bytesPerSecond))))/s"
    }
}

extension Double {
    var percentText: String {
        if self == rounded() {
            return String(format: "%.0f%%", self)
        }
        return String(format: "%.1f%%", self)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
