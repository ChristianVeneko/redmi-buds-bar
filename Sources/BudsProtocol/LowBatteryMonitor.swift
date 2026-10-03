/// Decides when to warn about a low earbud battery: once per earbud per discharge, never while charging.
public struct LowBatteryMonitor: Sendable {
    public let threshold: Int
    /// The level must climb this far above the threshold before an earbud can alert again.
    public let hysteresis: Int
    private var alerted: Set<EarbudPosition> = []

    public init(threshold: Int = 15, hysteresis: Int = 5) {
        self.threshold = threshold
        self.hysteresis = hysteresis
    }

    /// Returns the earbuds that newly dropped below the threshold.
    public mutating func update(_ battery: BatteryStatus) -> [EarbudPosition] {
        var newlyLow: [EarbudPosition] = []
        for (position, level) in [(EarbudPosition.left, battery.left), (.right, battery.right)] {
            guard let level else { continue }
            if level.isCharging || level.percent >= threshold + hysteresis {
                alerted.remove(position)
            } else if level.percent < threshold, !alerted.contains(position) {
                alerted.insert(position)
                newlyLow.append(position)
            }
        }
        return newlyLow
    }
}
