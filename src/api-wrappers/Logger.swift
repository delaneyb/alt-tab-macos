import SwiftyBeaver
import Foundation

class Logger {
    private static let logger = SwiftyBeaver.self
    static let flag = "--logs="
    static let disableModulesFlag = "--disable-modules="
    static let longDateTimeFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    static let shortDateTimeFormat = "h:mm:ss.SSS"  // 12-hour with single digit, no AM/PM

    private static var lastLoggedTime: CFAbsoluteTime?
    // Lock for thread-safe access to lastLoggedTime (ensures serialized delta calculations across threads)
    private static let logTimeLock = NSLock()
    private static var consoleDestination: ConsoleDestination?

    // MARK: - Module Filtering Configuration
    // Configure which modules to exclude from logging output via command line arguments.
    // Module names are extracted from Swift file names (e.g., "SystemPermissions" from "SystemPermissions.swift")
    // Usage: --disable-modules=Module1,Module2

    /// Runtime module filters (initialized from command line args only)
    private static var disabledModules: Set<String> = []

    // Performance timing utilities (like console.time/timeEnd in JavaScript)
    private static var timers = [String: CFAbsoluteTime]()
    private static var expectedMaxDurations = [String: Double]()

    static func initialize() {
        // Parse command line arguments for module filtering
        parseModuleFilters()

        let console = ConsoleDestination()
        // Set synchronous logging (asynchronously = false) for our delta timing feature.
        // This removes the possibility of logs appearing out of order and ensures delta calculations
        // reflect the actual execution flow rather than async dispatch timing.
        console.asynchronously = false
        console.useTerminalColors = true
        
        // Override default terminal colors (256-color ANSI codes)
        console.levelColor.verbose = "250m"  // light gray (dimmed but readable)
        console.levelColor.debug = "250m"  // light gray (dimmed but readable)
        console.levelColor.info = "231m"  // white (brightest white in 256-color palette)
        console.levelColor.warning = "214m"  // orange
        console.levelColor.error = "196m"  // bright red

        console.levelString.verbose = "VERB"
        console.levelString.debug = "DEBG"
        console.levelString.info = "INFO"
        console.levelString.warning = "WARN"
        console.levelString.error = "ERRO"
        
        // SwiftyBeaver format tokens:
        // $D....$d = date with format inside
        // $L = level string (DEBG/INFO/WARN/ERRO) - not used, severity shown via colors only
        // $C....$c = color wrapper for level
        // $n = filename (we prepend delta+format to it)
        // $M = message

        // Format: [level_color]timestamp delta+filename:line message[color_end]
        // Entire line is colored based on severity level (Option B)
        console.format = "$C$D\(shortDateTimeFormat)$d $n $M$c"
        console.minLevel = decideLevel()
        logger.addDestination(console)
        consoleDestination = console

        // Output warning if modules are disabled
        if !disabledModules.isEmpty {
            let patternsList = disabledModules.sorted().joined(separator: ", ")
            let yellowColor = "\u{001b}[38;5;214m"  // Orange/yellow (same as warning level)
            let resetColor = "\u{001b}[0m"
            Swift.print(
                "\(yellowColor)⚠️  Logger: Filtering out logs from modules matching: \(patternsList)\(resetColor)"
            )
        }
    }

    static func decideLevel() -> SwiftyBeaver.Level {
        if let level = (CommandLine.arguments.first { $0.starts(with: flag) })?.dropFirst(flag.count) {
            switch level {
                case "verbose": return .verbose
                case "debug": return .debug
                case "info": return .info
                case "warning": return .warning
                case "error": return .error
                default: break
            }
        }
        return .error
    }
    
    /// Parses command line arguments for module filtering flags.
    /// Format: --disable-modules=Module1,Module2
    /// Comma-separated module names. If not specified, no filtering is applied.
    private static func parseModuleFilters() {
        // Parse --disable-modules= flag
        if let disabledArg = CommandLine.arguments.first(where: {
            $0.starts(with: disableModulesFlag)
        }) {
            let modulesString = String(disabledArg.dropFirst(disableModulesFlag.count))
            if !modulesString.isEmpty {
                disabledModules = Set(
                    modulesString.split(separator: ",").map {
                        String($0).trimmingCharacters(in: .whitespaces)
                    })
            } else {
                disabledModules = []
            }
        } else {
            disabledModules = []
        }
    }

    // Public logging methods - all delegate to custom() with their respective log levels
    static func verbose(
        _ items: Any?..., file: String = #file, function: String = #function, line: Int = #line,
        context: Any? = nil
    ) {
        custom(.verbose, items, file: file, function: function, line: line, context: context)
    }

    static func debug(_ items: Any?..., file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(.debug, items, file: file, function: function, line: line, context: context)
    }

    static func info(_ items: Any?..., file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(.info, items, file: file, function: function, line: line, context: context)
    }

    static func warning(_ items: Any?..., file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(.warning, items, file: file, function: function, line: line, context: context)
    }

    static func error(_ items: Any?..., file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(.error, items, file: file, function: function, line: line, context: context)
    }

    /// Wrapper around SwiftyBeaver's `custom` logging method.
    ///
    /// All public logging methods (debug, info, warning, error) delegate to this function,
    /// which adds disabled module filtering and delta timing before calling SwiftyBeaver's own
    /// `custom` method (via `logger.custom()`) to handle the actual output.
    private static func custom(_ level: SwiftyBeaver.Level, _ items: [Any?], file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        // Module filtering - optimized with early returns
        let moduleName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent

        // Check disabled modules (blacklist)
        if !disabledModules.isEmpty {
            for pattern in disabledModules {
                if moduleName.contains(pattern) {
                    return  // Skip this log
                }
            }
        }

        let message = items.map { "\($0 ?? "nil")" }.joined(separator: " ")

        let shouldLog: Bool = {
            guard let consoleLevel = consoleDestination?.minLevel else { return true }
            return level.rawValue >= consoleLevel.rawValue
        }()

        // Message inherits color from SwiftyBeaver's $C wrapper (entire line same color)
        let coloredMessage = "[\(threadName())] \(message)"

        // Extract just the filename and format with line number to fixed width
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedLocation = formatFileLocation(fileName, line)

        // Serialize access to lastLoggedTime for thread-safe delta calculations
        logTimeLock.lock()
        defer { logTimeLock.unlock() }

        var deltaPrefix = String(repeating: " ", count: 7)  // 7-char delta: "+  1ms", "+ 1.1s", "+123.5s", "+  6.2h"
        var blankLinesToEmit = 0

        if shouldLog {
            let now = CFAbsoluteTimeGetCurrent()
            if let previous = lastLoggedTime {
                let deltaSeconds = now - previous
                deltaPrefix = deltaSeconds.formatted(padding: 7)
                blankLinesToEmit = blankLineCount(forDeltaSeconds: deltaSeconds)
            }
            lastLoggedTime = now
        }

        if blankLinesToEmit > 0 {
            emitBlankLines(blankLinesToEmit)
        }

        // Colorize delta prefix: blue for info/warning/error, dimmed blue for verbose/debug
        // After coloring the delta, restore the level color (not default terminal color)
        let levelColorCode: String
        switch level {
        case .verbose, .debug:
            levelColorCode = "\u{001b}[38;5;250m"  // light gray
        case .info:
            levelColorCode = "\u{001b}[38;5;231m"  // white
        case .warning:
            levelColorCode = "\u{001b}[38;5;214m"  // orange
        case .error:
            levelColorCode = "\u{001b}[38;5;196m"  // bright red
        }

        let coloredDeltaPrefix: String
        if level == .verbose || level == .debug {
            // Bright cyan-blue (color 75) for verbose/debug levels, then restore to level color
            coloredDeltaPrefix = "\u{001b}[38;5;75m\(deltaPrefix)\(levelColorCode)"
        } else {
            // Bright blue (color 39) for info/warning/error levels, then restore to level color
            coloredDeltaPrefix = "\u{001b}[38;5;39m\(deltaPrefix)\(levelColorCode)"
        }

        let fileWithDelta = "\(coloredDeltaPrefix) \(formattedLocation)"

        // Delegate to SwiftyBeaver's custom method for actual output
        logger.custom(
            level: level, message: coloredMessage, file: fileWithDelta, function: function, line: 0,
            context: context)
    }

    /// Start a performance timer. Optionally specify expectedMaxMs to automatically warn if duration exceeds threshold.
    /// Use message parameter to include additional context in the START log. Set logStart=false to start silently.
    static func time(
        _ label: String, expectedMaxMs: Double? = nil, _ message: String = "",
        logStart: Bool = true, file: String = #file, function: String = #function, line: Int = #line
    ) {
        timers[label] = CFAbsoluteTimeGetCurrent()
        if let max = expectedMaxMs {
            expectedMaxDurations[label] = max
        }
        if logStart {
            if message.isEmpty {
                info("⏱️", label, "START", file: file, function: function, line: line)
            } else {
                info("⏱️", label, "START -", message, file: file, function: function, line: line)
            }
        }
    }

    /// End a performance timer. Automatically warns if duration exceeded expectedMaxMs set in time().
    static func timeEnd(
        _ label: String, _ context: String = "", file: String = #file, function: String = #function,
        line: Int = #line
    ) {
        guard let startTime = timers[label] else {
            warning(
                "⏱️", label, "END called but no start time found", file: file, function: function,
                line: line)
            return
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let elapsedStr = String(format: "%.0fms", elapsed)

        let expectedMax = expectedMaxDurations[label]
        let didExceed = expectedMax.map { elapsed > $0 } ?? false

        if didExceed, let max = expectedMax {
            let overage = elapsed - max
            let overageStr = String(format: "%.0fms", overage)
            let expectedStr = String(format: "%.0fms", max)
            warning(
                "⏱️", label, "END", elapsedStr,
                "⚠️ SLOW: +\(overageStr) over expected \(expectedStr)", context, file: file,
                function: function, line: line)
        } else {
            info("⏱️", label, "END", elapsedStr, context, file: file, function: function, line: line)
        }

        timers.removeValue(forKey: label)
        expectedMaxDurations.removeValue(forKey: label)
    }

    /// Mark an intermediate checkpoint. Automatically warns if elapsed time exceeded expectedMaxMs set in time().
    static func timeMark(
        _ label: String, _ message: String, file: String = #file, function: String = #function,
        line: Int = #line
    ) {
        guard let startTime = timers[label] else {
            warning(
                "⏱️", label, "mark:", message, "- no start time found", file: file,
                function: function, line: line)
            return
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let elapsedStr = String(format: "%.0fms", elapsed)

        let expectedMax = expectedMaxDurations[label]
        let didExceed = expectedMax.map { elapsed > $0 } ?? false

        if didExceed, let max = expectedMax {
            let overage = elapsed - max
            let overageStr = String(format: "%.0fms", overage)
            let expectedStr = String(format: "%.0fms", max)
            warning(
                "⏱️", label, message, elapsedStr,
                "⚠️ SLOW: +\(overageStr) over expected \(expectedStr)", file: file,
                function: function, line: line)
        } else {
            info("⏱️", label, message, elapsedStr, file: file, function: function, line: line)
        }
    }

    /// Calculates the number of blank lines to insert based on time delta between logs.
    private static func blankLineCount(forDeltaSeconds deltaSeconds: Double) -> Int {
        // Specific thresholds for visual separation
        if deltaSeconds >= 8.0 { return 5 }
        if deltaSeconds >= 1.0 { return 3 }
        if deltaSeconds >= 0.4 { return 2 }
        if deltaSeconds >= 0.15 { return 1 }
        return 0
    }

    /// Emits blank lines to the console for visual separation between log entries.
    private static func emitBlankLines(_ count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            Swift.print("")
        }
    }

    private static func threadName() -> String {
        if Thread.isMainThread {
            return "main"
        } else if let name = Thread.current.name, !name.isEmpty {
            return name
        } else {
            let name = __dispatch_queue_get_label(nil)
            return String(cString: name, encoding: .utf8) ?? Thread.current.description
        }
    }
    
    /// Format filename:line to exactly N characters with middle truncation if needed
    /// Right-aligned so line numbers align vertically
    private static func formatFileLocation(_ fileName: String, _ line: Int) -> String {
        let targetWidth = 24  // Increased from 22
        let lineStr = ":\(line)"
        let fileExt = ".swift"

        // Full string without truncation
        let full = "\(fileName)\(lineStr)"

        if full.count <= targetWidth {
            // Right-align: pad on the left with spaces
            let padding = String(repeating: " ", count: max(0, targetWidth - full.count))
            return "\(padding)\(full)"
        }

        // Need to truncate - preserve .swift extension and line number
        let baseName = fileName.dropLast(fileExt.count)  // Remove ".swift"
        let availableForBaseName = targetWidth - fileExt.count - lineStr.count

        if String(baseName).count <= availableForBaseName {
            // No truncation needed, just right-align
            let padding = String(repeating: " ", count: max(0, targetWidth - full.count))
            return "\(padding)\(full)"
        }

        // Truncate in middle with *
        let truncMarker = "*"
        let charsForName = availableForBaseName - truncMarker.count  // Space for actual name chars
        let leftChars = charsForName / 2
        let rightChars = charsForName - leftChars

        let baseStr = String(baseName)
        let left = baseStr.prefix(leftChars)
        let right = baseStr.suffix(rightChars)

        return "\(left)\(truncMarker)\(right)\(fileExt)\(lineStr)"
    }
}
