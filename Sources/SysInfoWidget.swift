import AppKit
import Darwin

final class CPUMonitor {
    static let shared = CPUMonitor()
    private var last: (busy: Int, idle: Int)?

    func usage() -> Double {
        var numCPUs: natural_t = 0
        var info: processor_info_array_t?
        var count: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &info, &count) == KERN_SUCCESS,
              let info = info else { return -1 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        var busy = 0, idle = 0
        for c in 0..<Int(numCPUs) {
            let base = c * Int(CPU_STATE_MAX)
            busy += Int(info[base + Int(CPU_STATE_USER)]) + Int(info[base + Int(CPU_STATE_SYSTEM)])
                  + Int(info[base + Int(CPU_STATE_NICE)])
            idle += Int(info[base + Int(CPU_STATE_IDLE)])
        }
        guard let last = last else {
            self.last = (busy, idle)
            return -1
        }
        let dBusy = busy - last.busy, dIdle = idle - last.idle
        self.last = (busy, idle)
        let total = dBusy + dIdle
        return total > 0 ? Double(dBusy) / Double(total) : -1
    }
}

final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private var last: (rx: Int, tx: Int, at: Date)?

    func rates() -> (rxKBps: Double, txKBps: Double) {
        var rx = 0, tx = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let ifa = p.pointee
            if let data = ifa.ifa_data,
               ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let nd = data.assumingMemoryBound(to: if_data.self)
                rx += Int(nd.pointee.ifi_ibytes)
                tx += Int(nd.pointee.ifi_obytes)
            }
            ptr = ifa.ifa_next
        }
        let now = Date()
        defer { last = (rx, tx, now) }
        guard let last, now.timeIntervalSince(last.at) > 0.2 else { return (0, 0) }
        let dt = now.timeIntervalSince(last.at)
        return (Double(rx - last.rx) / dt / 1024, Double(tx - last.tx) / dt / 1024)
    }
}

final class SysInfoWidget: NSView, ToolboxWidget {
    let widgetTitle = "系统信息"
    let symbolName = "cpu"

    private let cpuLabel = Theme.makeLabel("CPU", size: 11, weight: .medium, color: .secondaryLabelColor)
    private let cpuValue = Theme.makeLabel("--%", size: 12, mono: true)
    private let cpuSpark = Sparkline()

    private let memLabel = Theme.makeLabel("内存", size: 11, weight: .medium, color: .secondaryLabelColor)
    private let memValue = Theme.makeLabel("--", size: 12, mono: true)
    private let memSpark = Sparkline()

    private let netLabel = Theme.makeLabel("网络", size: 11, weight: .medium, color: .secondaryLabelColor)
    private let netValue = Theme.makeLabel("↓0 ↑0", size: 12, mono: true)
    private let netSpark = Sparkline()
    private var netPeak: Double = 1024 * 128   // 自适应峰值，起步 128KB/s

    private let diskLabel = Theme.makeLabel("磁盘", size: 11, weight: .medium, color: .secondaryLabelColor)
    private let diskValue = Theme.makeLabel("--", size: 12, mono: true)
    private let diskBar = MiniBar(frame: NSRect(x: 0, y: 0, width: 100, height: 5))
    private let uptimeValue = Theme.makeLabel("--", size: 11, color: .tertiaryLabelColor, mono: true)
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        [cpuSpark, memSpark, netSpark].forEach {
            $0.heightAnchor.constraint(equalToConstant: 24).isActive = true
        }
        [cpuSpark, memSpark].forEach { $0.lineColor = .controlAccentColor }
        netSpark.lineColor = Theme.Palette.success
        diskBar.autoColor = true

        func statRow(_ label: NSTextField, _ value: NSTextField) -> NSView {
            let l = label; l.widthAnchor.constraint(equalToConstant: 34).isActive = true
            let v = value
            let spacer = NSView()
            spacer.setContentHuggingPriority(.init(1), for: .horizontal)
            return NSStackView(views: [l, v, spacer])
        }

        let cpuRow = statRow(cpuLabel, cpuValue)
        let memRow = statRow(memLabel, memValue)
        let netRow = statRow(netLabel, netValue)
        let diskRow: NSView = {
            let l = diskLabel; l.widthAnchor.constraint(equalToConstant: 34).isActive = true
            let bar = diskBar
            bar.widthAnchor.constraint(equalToConstant: 120).isActive = true
            bar.heightAnchor.constraint(equalToConstant: 5).isActive = true
            let spacer = NSView()
            spacer.setContentHuggingPriority(.init(1), for: .horizontal)
            return NSStackView(views: [l, bar, diskValue, spacer])
        }()
        let uptimeRow: NSView = {
            let l = Theme.makeLabel("开机", size: 11, weight: .medium, color: .secondaryLabelColor)
            l.widthAnchor.constraint(equalToConstant: 34).isActive = true
            let spacer = NSView()
            spacer.setContentHuggingPriority(.init(1), for: .horizontal)
            return NSStackView(views: [l, uptimeValue, spacer])
        }()

        let stack = NSStackView(views: [cpuRow, cpuSpark, memRow, memSpark, netRow, netSpark,
                                        diskRow, uptimeRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Theme.Metrics.sectionSpacing
        stack.pin(to: self, insets: NSEdgeInsets(top: 0, left: 2, bottom: 4, right: 4))
        [cpuRow, memRow, netRow, diskRow, uptimeRow].forEach {
            $0.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        }
        [cpuSpark, memSpark, netSpark].forEach {
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -6).isActive = true
        }

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { timer?.invalidate() }

    private func refresh() {
        // CPU
        let cpu = CPUMonitor.shared.usage()
        if cpu >= 0 {
            cpuValue.stringValue = String(format: "%.0f%%", cpu * 100)
            cpuSpark.push(cpu)
        }

        // 内存
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(UInt32(MemoryLayout<vm_statistics64_data_t>.size
            / MemoryLayout<integer_t>.size))
        if withUnsafeMutablePointer(to: &stats, {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }) == KERN_SUCCESS {
            let page = UInt64(vm_page_size)
            let total = ProcessInfo.processInfo.physicalMemory
            let used = page * (UInt64(stats.active_count) + UInt64(stats.wire_count)
                             + UInt64(stats.compressor_page_count))
            let ratio = total > 0 ? Double(used) / Double(total) : 0
            memValue.stringValue = String(format: "%.1f / %.0f GB",
                                          Double(used) / 1_073_741_824,
                                          Double(total) / 1_073_741_824)
            memSpark.push(ratio)
        }

        // 网络（归一化到自适应峰值）
        let (rx, tx) = NetworkMonitor.shared.rates()
        netValue.stringValue = String(format: "↓%.0f ↑%.0f KB/s", rx, tx)
        let total2 = rx + tx
        netPeak = max(netPeak * 0.995, total2, 64 * 1024)
        netSpark.push(min(1, total2 / netPeak))

        // 磁盘
        if let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: "/"),
           let total3 = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64 {
            let used3 = total3 - free
            let ratio = total3 > 0 ? Double(used3) / Double(total3) : 0
            diskValue.stringValue = String(format: "%.0f / %.0f GB",
                                           Double(used3) / 1_073_741_824,
                                           Double(total3) / 1_073_741_824)
            diskBar.ratio = CGFloat(ratio)
        }

        // 开机时长
        let up = ProcessInfo.processInfo.systemUptime
        let d = Int(up) / 86400, h = Int(up) % 86400 / 3600, m = Int(up) % 3600 / 60
        uptimeValue.stringValue = d > 0 ? "\(d) 天 \(h) 小时" : "\(h) 小时 \(m) 分"
    }
}
