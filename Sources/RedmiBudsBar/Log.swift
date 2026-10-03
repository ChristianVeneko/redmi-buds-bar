import os

enum Log {
    static let subsystem = "io.github.redmibudsbar.RedmiBudsBar"
    static let transport = Logger(subsystem: subsystem, category: "transport")
    static let protocolLog = Logger(subsystem: subsystem, category: "protocol")
    static let app = Logger(subsystem: subsystem, category: "app")
}
