import Foundation
import BudsProtocol
import IOBluetooth

/// Thin IOBluetooth wrapper around the earbuds' RFCOMM control channel.
/// Delegate callbacks are hopped to the main thread with `onMain`; all state is touched on the main thread.
final class RFCOMMTransport: NSObject, IOBluetoothRFCOMMChannelDelegate {
    enum Event {
        case opened
        case closed
        case data([UInt8])
        case failed(String)
    }

    /// Custom service UUID advertised by the earbuds next to the "miwear" SDP service name.
    static let serviceUUID = "df21fe2c-2515-4fdb-8886-f12c4d67927c"
    static let serviceName = "miwear"
    static let fallbackChannelID: BluetoothRFCOMMChannelID = 28

    var onEvent: ((Event) -> Void)?

    private(set) var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var sdpTimeout: Timer?
    private(set) var isOpening = false

    var isOpen: Bool { channel != nil && !isOpening }

    /// Paired devices whose name looks like a REDMI Buds model, with their connection state.
    static func pairedBuds() -> [(device: IOBluetoothDevice, candidate: DeviceCandidate)] {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return devices.compactMap { device in
            guard let name = device.name, BudsModel.isRedmiBuds(name: name) else { return nil }
            return (device, DeviceCandidate(id: device.addressString ?? name, name: name, isConnected: device.isConnected()))
        }
    }

    func connect(to device: IOBluetoothDevice) {
        guard !isOpening, channel == nil else { return }
        self.device = device
        isOpening = true
        Log.transport.info("Looking up SDP records for \(device.name ?? "?", privacy: .public)")

        let status = device.performSDPQuery(self)
        if status != kIOReturnSuccess {
            Log.transport.error("SDP query failed to start (\(status)); using channel \(Self.fallbackChannelID)")
            openChannel(Self.fallbackChannelID)
            return
        }
        sdpTimeout?.invalidate()
        sdpTimeout = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            guard let self, self.isOpening, self.channel == nil else { return }
            Log.transport.error("SDP query timed out; using channel \(Self.fallbackChannelID)")
            self.openChannel(Self.fallbackChannelID)
        }
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        onMain { [self] in handleSDPComplete(device, status: status) }
    }

    private func handleSDPComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard isOpening, channel == nil else { return }
        sdpTimeout?.invalidate()
        var channelID = Self.fallbackChannelID
        if status == kIOReturnSuccess, let id = Self.controlChannelID(in: device) {
            channelID = id
        } else {
            Log.transport.error("SDP lookup yielded no control channel (status \(status)); using fallback")
        }
        openChannel(channelID)
    }

    private static func controlChannelID(in device: IOBluetoothDevice) -> BluetoothRFCOMMChannelID? {
        let uuidBytes = UUID(uuidString: serviceUUID).map { u -> [UInt8] in
            withUnsafeBytes(of: u.uuid) { Array($0) }
        } ?? []
        let uuid = uuidBytes.withUnsafeBufferPointer {
            IOBluetoothSDPUUID(bytes: $0.baseAddress, length: $0.count)
        }
        let records = (device.services as? [IOBluetoothSDPServiceRecord]) ?? []
        for record in records {
            Log.transport.debug("SDP service: \(record.getServiceName() ?? "<unnamed>", privacy: .public)")
        }
        let match = records.first { $0.getServiceName() == serviceName }
            ?? records.first { $0.hasService(from: [uuid]) }
        guard let match else { return nil }
        var id: BluetoothRFCOMMChannelID = 0
        guard match.getRFCOMMChannelID(&id) == kIOReturnSuccess, id != 0 else { return nil }
        Log.transport.info("SDP resolved control channel \(id)")
        return id
    }

    private func openChannel(_ id: BluetoothRFCOMMChannelID) {
        guard let device else { return }
        var newChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelAsync(&newChannel, withChannelID: id, delegate: self)
        if status != kIOReturnSuccess || newChannel == nil {
            isOpening = false
            Log.transport.error("openRFCOMMChannelAsync failed: \(status)")
            onEvent?(.failed("Could not open channel \(id) (IOReturn \(status))"))
            return
        }
        channel = newChannel
        Log.transport.info("Opening RFCOMM channel \(id)")
    }

    func disconnect() {
        sdpTimeout?.invalidate()
        isOpening = false
        if let channel {
            self.channel = nil
            channel.setDelegate(nil)
            _ = channel.close()
        }
    }

    @discardableResult
    func write(_ frame: [UInt8]) -> Bool {
        guard let channel, !isOpening else { return false }
        var bytes = frame
        let status = bytes.withUnsafeMutableBytes { raw in
            channel.writeSync(raw.baseAddress, length: UInt16(raw.count))
        }
        if status != kIOReturnSuccess {
            Log.transport.error("Write failed: \(status)")
            return false
        }
        return true
    }

    // MARK: IOBluetoothRFCOMMChannelDelegate

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        onMain { [self] in handleOpenComplete(status: error) }
    }

    private func handleOpenComplete(status error: IOReturn) {
        isOpening = false
        if error == kIOReturnSuccess {
            Log.transport.info("RFCOMM channel open")
            onEvent?(.opened)
        } else {
            Log.transport.error("RFCOMM open failed: \(error)")
            channel = nil
            onEvent?(.failed("RFCOMM open failed (IOReturn \(error))"))
        }
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        // Copy now: the buffer is only valid during the callback.
        let bytes = [UInt8](UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength))
        onMain { [self] in onEvent?(.data(bytes)) }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        onMain { [self] in
            Log.transport.info("RFCOMM channel closed")
            channel = nil
            isOpening = false
            onEvent?(.closed)
        }
    }
}
