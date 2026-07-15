import AppKit
import Combine
import CoreLocation
import CoreWLAN
import Darwin
import MapKit
import Network
import ServiceManagement
import SwiftUI
import SystemConfiguration

private enum LegacySettingsMigration {
    private static let completedKey = "migration-v1.pulse-bar-settings"
    private static let legacyBundleIdentifier = "local.codex.pulse-bar"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: completedKey) else { return }

        if let legacyValues = defaults.persistentDomain(forName: legacyBundleIdentifier) {
            for (key, value) in legacyValues where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: completedKey)
    }
}

private enum RetiredQuotaCleanup {
    private static let completedKey = "cleanup-v1.retired-mobile-quota"
    private static let removedKeys = [
        "daily-metered-v1.day",
        "daily-metered-v1.download",
        "daily-metered-v1.upload",
        "mobile-quota-v1.baseline-remaining",
        "mobile-quota-v1.used-since-update",
        "mobile-quota-v1.billing-start-day"
    ]

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: completedKey) else { return }
        removedKeys.forEach(defaults.removeObject(forKey:))
        defaults.set(true, forKey: completedKey)
    }
}

private enum RuntimeMode {
    static var isPreview: Bool {
        CommandLine.arguments.contains("--preview-window")
    }

    static var recordsMeasurements: Bool {
        allowsPersistentMeasurements(arguments: CommandLine.arguments)
    }

    static func allowsPersistentMeasurements(arguments: [String]) -> Bool {
        !arguments.contains("--preview-window")
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        if allowsPersistentMeasurements(arguments: ["Szlauch", "--preview-window"]) {
            failures.append("podgląd okna modyfikowałby historię transferu")
        }
        if !allowsPersistentMeasurements(arguments: ["Szlauch"]) {
            failures.append("zwykłe uruchomienie nie zapisywałoby pomiarów")
        }
        return failures
    }
}

private struct PulseTheme: Equatable {
    enum Variant: String, CaseIterable {
        case mech
        case zatoka
        case sliwka

        var label: String {
            switch self {
            case .mech: return "Mech"
            case .zatoka: return "Zatoka"
            case .sliwka: return "Śliwka"
            }
        }

        var foundation: Color {
            switch self {
            case .mech: return Color(hex: 0x111915)
            case .zatoka: return Color(hex: 0x0E171A)
            case .sliwka: return Color(hex: 0x17141C)
            }
        }

        var surface: Color {
            switch self {
            case .mech: return Color(hex: 0x17231D)
            case .zatoka: return Color(hex: 0x14252A)
            case .sliwka: return Color(hex: 0x241D2C)
            }
        }

        var edge: Color {
            switch self {
            case .mech: return Color(hex: 0x345344)
            case .zatoka: return Color(hex: 0x245461)
            case .sliwka: return Color(hex: 0x534263)
            }
        }

        var accent: Color {
            switch self {
            case .mech: return Color(hex: 0x33E982)
            case .zatoka: return Color(hex: 0x41D2C2)
            case .sliwka: return Color(hex: 0xB59AF7)
            }
        }

        var download: Color {
            switch self {
            case .mech: return Color(hex: 0x5DC9F2)
            case .zatoka: return Color(hex: 0x54C9F1)
            case .sliwka: return Color(hex: 0x61D1C6)
            }
        }

        var upload: Color {
            switch self {
            case .mech: return Color(hex: 0xF09A72)
            case .zatoka: return Color(hex: 0xF1AD72)
            case .sliwka: return Color(hex: 0xF2A36E)
            }
        }

        var next: Variant {
            let variants = Self.allCases
            guard let index = variants.firstIndex(of: self) else { return .mech }
            return variants[(index + 1) % variants.count]
        }
    }

    static let storageKey = "appearance-v2.palette"
    static let intensityStorageKey = "appearance-v2.intensity"
    static let opacityStorageKey = "appearance-v2.opacity"
    static let defaultIntensity = 0.65
    static let minimumIntensity = 0.18
    static let maximumIntensity = 1.0
    static let defaultOpacity = 1.0
    static let minimumOpacity = 0.62
    static let maximumOpacity = 1.0
    static let mech = PulseTheme(variant: .mech)
    static let sliwka = PulseTheme(variant: .sliwka)

    let variant: Variant
    let intensity: Double

    init(variant: Variant, intensity: Double = defaultIntensity) {
        self.variant = variant
        self.intensity = Self.clampedIntensity(intensity)
    }

    init?(storedValue: String, intensity: Double = defaultIntensity) {
        guard let variant = Variant(rawValue: storedValue) else { return nil }
        self.init(variant: variant, intensity: intensity)
    }

    static var selected: PulseTheme {
        let intensity = storedIntensity()
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return PulseTheme(storedValue: saved, intensity: intensity) ?? .sliwka.withIntensity(intensity)
    }

    static func storedIntensity() -> Double {
        clampedIntensity(storedDouble(forKey: intensityStorageKey, fallback: defaultIntensity))
    }

    static func clampedIntensity(_ intensity: Double) -> Double {
        min(max(intensity, minimumIntensity), maximumIntensity)
    }

    static func clampedOpacity(_ opacity: Double) -> Double {
        min(max(opacity, minimumOpacity), maximumOpacity)
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        let sequence = mech.cycled().cycled().cycled()
        if sequence.variant != .mech {
            failures.append("cykl palet nie wraca do Mechu po trzech kliknięciach")
        }
        if PulseTheme(storedValue: "zatoka")?.variant != .zatoka {
            failures.append("nazwana paleta nie jest poprawnie odczytywana")
        }
        if PulseTheme(storedValue: "z1-strong|z2-light|z3-cta") != nil {
            failures.append("stary losowy format palety nie powinien być używany")
        }
        return failures
    }

    private static func storedDouble(forKey key: String, fallback: Double) -> Double {
        let stored = UserDefaults.standard.object(forKey: key)
        if let value = stored as? NSNumber {
            return value.doubleValue
        }
        if let value = stored as? String, let number = Double(value) {
            return number
        }
        return fallback
    }

    var storedValue: String {
        variant.rawValue
    }

    func withIntensity(_ intensity: Double) -> PulseTheme {
        PulseTheme(variant: variant, intensity: intensity)
    }

    func cycled() -> PulseTheme {
        PulseTheme(variant: variant.next, intensity: intensity)
    }

    private var semanticIntensity: Double { max(intensity, 0.72) }

    var foundation: Color { variant.foundation }
    var main: Color { variant.surface.opacity(intensity) }
    var light: Color { variant.edge.opacity(max(intensity, 0.52)) }
    var cta: Color { variant.accent.opacity(semanticIntensity) }
    var inbound: Color { variant.download.opacity(semanticIntensity) }
    var outbound: Color { variant.upload.opacity(semanticIntensity) }
}

private enum AppearanceDefaultsMigration {
    private static let completedKey = "migration-v2.full-opacity-dark-panel"

    static func run(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completedKey) else { return }
        defaults.set(PulseTheme.defaultOpacity, forKey: PulseTheme.opacityStorageKey)
        defaults.set(true, forKey: completedKey)
    }

    static func selfTestFailures() -> [String] {
        let suiteName = "app.szlauch.macos.tests.appearance.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return ["nie udało się utworzyć izolowanych ustawień testowych"]
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(PulseTheme.minimumOpacity, forKey: PulseTheme.opacityStorageKey)
        run(defaults: defaults)
        if defaults.double(forKey: PulseTheme.opacityStorageKey) != PulseTheme.defaultOpacity {
            return ["pierwszy start nie przywraca pełnej opacity"]
        }

        defaults.set(0.78, forKey: PulseTheme.opacityStorageKey)
        run(defaults: defaults)
        if abs(defaults.double(forKey: PulseTheme.opacityStorageKey) - 0.78) > 0.001 {
            return ["kolejny start nadpisuje świadomie wybraną opacity"]
        }
        return []
    }
}

private enum Palette {
    static let background = Color.clear
    static var surface: Color { PulseTheme.selected.main.opacity(0.16) }
    static var soft: Color { PulseTheme.selected.cta.opacity(0.15) }
    static let ink = Color(hex: 0xF5F1FA)
    static let muted = Color(hex: 0xC1B9C9)
    static var line: Color { PulseTheme.selected.light.opacity(0.16) }
    static var strong: Color { PulseTheme.selected.cta }
    static var action: Color { PulseTheme.selected.cta }
    static var metric: Color { PulseTheme.selected.cta }
    static var inbound: Color { PulseTheme.selected.inbound }
    static var outbound: Color { PulseTheme.selected.outbound }
    static var warning: Color { Color(hex: 0xFFD06A).opacity(max(PulseTheme.selected.intensity, 0.78)) }
    static var danger: Color { Color(hex: 0xFF7B8F).opacity(max(PulseTheme.selected.intensity, 0.82)) }
}

private extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

private extension NSColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

private final class WindowOpacityView: NSView {
    var opacity: Double = PulseTheme.defaultOpacity {
        didSet { applyOpacity() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyOpacity()
    }

    private func applyOpacity() {
        window?.alphaValue = CGFloat(PulseTheme.clampedOpacity(opacity))
    }
}

private struct WindowOpacityController: NSViewRepresentable {
    let opacity: Double

    func makeNSView(context: Context) -> WindowOpacityView {
        let view = WindowOpacityView(frame: .zero)
        view.opacity = opacity
        return view
    }

    func updateNSView(_ view: WindowOpacityView, context: Context) {
        view.opacity = opacity
    }
}

private struct PulseThemeKey: EnvironmentKey {
    static let defaultValue = PulseTheme.sliwka
}

private extension EnvironmentValues {
    var pulseTheme: PulseTheme {
        get { self[PulseThemeKey.self] }
        set { self[PulseThemeKey.self] = newValue }
    }
}

private enum GlassTone {
    case light
    case main

    func tint(for theme: PulseTheme) -> Color {
        switch self {
        case .light:
            return theme.main.opacity(0.18)
        case .main:
            return theme.main.opacity(0.34)
        }
    }

    func backdrop(for theme: PulseTheme) -> LinearGradient {
        switch self {
        case .light:
            return LinearGradient(
                colors: [
                    theme.main.opacity(0.20),
                    theme.light.opacity(0.055),
                    theme.cta.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .main:
            return LinearGradient(
                colors: [
                    theme.main.opacity(0.40),
                    theme.main.opacity(0.25),
                    theme.cta.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    func edge(for theme: PulseTheme) -> Color {
        switch self {
        case .light:
            return theme.light.opacity(0.10)
        case .main:
            return theme.light.opacity(0.12)
        }
    }
}

private struct GlassSurface: ViewModifier {
    @Environment(\.pulseTheme) private var theme
    let radius: CGFloat
    let tone: GlassTone
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(
                    tone.backdrop(for: theme),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(tone.edge(for: theme), lineWidth: 0.7)
                }
                .glassEffect(
                    Glass.regular.tint(tone.tint(for: theme)).interactive(interactive),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
        } else {
            content
                .background(tone.backdrop(for: theme), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(tone.edge(for: theme), lineWidth: 0.7)
                }
        }
    }
}

private struct InstrumentSurface: ViewModifier {
    @Environment(\.pulseTheme) private var theme
    let radius: CGFloat

    private var backdrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(theme.foundation.opacity(0.78))

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.main.opacity(0.50),
                            theme.foundation.opacity(0.42),
                            theme.main.opacity(0.27)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [theme.inbound.opacity(0.12), .clear],
                center: .center,
                startRadius: 3,
                endRadius: 124
            )
            .frame(width: 226, height: 148)
            .offset(x: -62, y: -10)

            RadialGradient(
                colors: [theme.cta.opacity(0.10), .clear],
                center: .center,
                startRadius: 3,
                endRadius: 132
            )
            .frame(width: 220, height: 168)
            .offset(x: 74, y: 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(backdrop)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(theme.light.opacity(0.28), lineWidth: 0.7)
                }
                .glassEffect(
                    Glass.regular.tint(theme.main.opacity(0.17)),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
        } else {
            content
                .background(backdrop)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(theme.light.opacity(0.28), lineWidth: 0.7)
                }
        }
    }
}

private extension View {
    func pulseGlass(
        radius: CGFloat = 14,
        tone: GlassTone = .light,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassSurface(radius: radius, tone: tone, interactive: interactive))
    }

    func instrumentGlass(radius: CGFloat = 18) -> some View {
        modifier(InstrumentSurface(radius: radius))
    }
}

private struct PanelBackdrop: View {
    let theme: PulseTheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThickMaterial)

            Rectangle()
                .fill(theme.foundation.opacity(0.50))

            LinearGradient(
                colors: [
                    theme.main.opacity(0.60),
                    theme.main.opacity(0.33),
                    theme.main.opacity(0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [theme.cta.opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 6,
                endRadius: 240
            )

            RadialGradient(
                colors: [theme.light.opacity(0.10), .clear],
                center: .bottomTrailing,
                startRadius: 18,
                endRadius: 260
            )
        }
    }
}

private struct LinkCounter {
    let incomingBytes: UInt32
    let outgoingBytes: UInt32
}

private struct InterfaceCounter {
    let name: String
    let displayName: String
    let address: String
    let monitoredCounters: [String: LinkCounter]
    let timestamp: Date
}

private struct NetworkState {
    let interfaceName: String
    let monitoredInterfaces: [String]
    let displayName: String
    let address: String
    let upload: Double
    let download: Double
    let instantUpload: Double
    let instantDownload: Double
    let uploadHistory: [Double]
    let downloadHistory: [Double]
    let isConnected: Bool

    static let initial = NetworkState(
        interfaceName: "—",
        monitoredInterfaces: [],
        displayName: "Sprawdzam sieć",
        address: "—",
        upload: 0,
        download: 0,
        instantUpload: 0,
        instantDownload: 0,
        uploadHistory: [],
        downloadHistory: [],
        isConnected: false
    )
}

private struct WiFiState {
    enum Connection {
        case loading
        case unavailable
        case poweredOff
        case disconnected
        case connected
    }

    let connection: Connection
    let interfaceName: String?
    let networkName: String?
    let rssi: Int?

    static let initial = WiFiState(connection: .loading, interfaceName: nil, networkName: nil, rssi: nil)

    var symbolName: String {
        switch connection {
        case .connected where (rssi ?? 0) <= -75:
            return "wifi.exclamationmark"
        case .connected:
            return "wifi"
        case .loading, .unavailable, .poweredOff, .disconnected:
            return "wifi.slash"
        }
    }

    var isWeak: Bool {
        connection == .connected && (rssi ?? 0) <= -75
    }

    var toolTip: String {
        switch connection {
        case .loading:
            return "Wi-Fi: sprawdzam"
        case .unavailable:
            return "Wi-Fi: niedostępne"
        case .poweredOff:
            return "Wi-Fi: wyłączone"
        case .disconnected:
            return "Wi-Fi: brak połączenia"
        case .connected:
            let name = networkName.map { " · \($0)" } ?? ""
            let signal = rssi.map { " · \($0) dBm" } ?? ""
            return "Wi-Fi: połączono\(name)\(signal)"
        }
    }
}

private enum WiFiIdentity {
    static func matches(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = normalized(lhs), let rhs = normalized(rhs) else {
            return false
        }
        return lhs == rhs
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        if !matches("Domowa_5G", "Domowa_5G") {
            failures.append("identyczna nazwa aktywnej sieci nie została rozpoznana")
        }
        if !matches("Cafe\u{301}", "Café") {
            failures.append("kanonicznie równoważne nazwy Wi-Fi powinny być rozpoznane")
        }
        if matches("Biuro", "biuro") {
            failures.append("nazwy SSID pozostają rozróżniane wielkością liter")
        }
        if matches(nil, "Biuro") || matches("", "Biuro") {
            failures.append("brak nazwy nie może oznaczać aktywnej sieci")
        }
        return failures
    }

    private static func normalized(_ name: String?) -> String? {
        guard let name, !name.isEmpty else { return nil }
        return name.precomposedStringWithCanonicalMapping
    }
}

private enum WiFiSettingsDestination {
    static let destinations = [
        "x-apple.systempreferences:com.apple.wifi-settings-extension",
        "x-apple.systempreferences:com.apple.Network-Settings.extension",
        "x-apple.systempreferences:com.apple.preference.network"
    ]

    static func open() {
        for destination in destinations {
            guard let url = URL(string: destination) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func selfTestFailures() -> [String] {
        guard destinations.first == "x-apple.systempreferences:com.apple.wifi-settings-extension" else {
            return ["skrót nie prowadzi najpierw do panelu Wi-Fi macOS"]
        }
        if destinations.contains("x-apple.systempreferences:com.apple.WiFi-Settings.extension") {
            return ["lista nadal zawiera nieaktualny identyfikator panelu Wi-Fi"]
        }
        return []
    }
}

private struct CPUCounter {
    let active: UInt64
    let total: UInt64
}

private struct ProcessUsage: Identifiable {
    let id: String
    let name: String
    let cpu: Double
    let memoryBytes: UInt64
}

private struct SystemState {
    let cpuUsage: Double
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let coreUsages: [Double]
    let cpuProcesses: [ProcessUsage]
    let memoryProcesses: [ProcessUsage]

    static let initial = SystemState(
        cpuUsage: 0,
        memoryUsed: 0,
        memoryTotal: ProcessInfo.processInfo.physicalMemory,
        coreUsages: [],
        cpuProcesses: [],
        memoryProcesses: []
    )
}

private struct WiFiNetworkOption: Identifiable {
    let id: String
    let name: String
    let signal: Int
    let secured: Bool
    let network: CWNetwork

    var signalSymbol: String {
        signal <= -78 ? "wifi.exclamationmark" : "wifi"
    }
}

private struct WiFiScanResult {
    let networks: [WiFiNetworkOption]
    let namesAreRestricted: Bool
}

private enum PersonalHotspotStore {
    private static let nameKey = "wifi-v1.personal-hotspot.name"

    static func current() -> String? {
        normalizedName(UserDefaults.standard.string(forKey: nameKey) ?? "")
    }

    static func set(_ name: String?) {
        if let name = normalizedName(name ?? "") {
            UserDefaults.standard.set(name, forKey: nameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: nameKey)
        }
    }

    static func normalizedName(_ name: String) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        if normalizedName("  Mój iPhone \n") != "Mój iPhone" {
            failures.append("nazwa hotspotu nie usuwa zbędnych odstępów")
        }
        if normalizedName(" \n\t ") != nil {
            failures.append("pusta nazwa hotspotu powinna usuwać wybór")
        }
        return failures
    }
}

private enum ConnectionCost {
    case loading
    case metered
    case standard
    case offline

    var isMetered: Bool {
        self == .metered
    }

    var label: String {
        switch self {
        case .loading: return "Sprawdzam połączenie"
        case .metered: return "Aktywny teraz"
        case .standard: return "Teraz poza hotspotem"
        case .offline: return "Brak połączenia"
        }
    }
}

private enum TrafficRoute: String, Codable, Hashable {
    case wifi
    case hotspot
    case other
}

private struct TrafficTotals {
    var download: UInt64 = 0
    var upload: UInt64 = 0

    var total: UInt64 {
        download + upload
    }

    mutating func add(download: UInt64, upload: UInt64) {
        self.download += download
        self.upload += upload
    }
}

private struct TrafficBucket: Codable, Identifiable, Equatable {
    let minute: Date
    var wifiDownload: UInt64 = 0
    var wifiUpload: UInt64 = 0
    var hotspotDownload: UInt64 = 0
    var hotspotUpload: UInt64 = 0
    var otherDownload: UInt64 = 0
    var otherUpload: UInt64 = 0

    var id: Date { minute }

    var totalDownload: UInt64 {
        wifiDownload + hotspotDownload + otherDownload
    }

    var totalUpload: UInt64 {
        wifiUpload + hotspotUpload + otherUpload
    }

    mutating func add(download: UInt64, upload: UInt64, route: TrafficRoute) {
        switch route {
        case .wifi:
            wifiDownload += download
            wifiUpload += upload
        case .hotspot:
            hotspotDownload += download
            hotspotUpload += upload
        case .other:
            otherDownload += download
            otherUpload += upload
        }
    }

    func totals(for route: TrafficRoute?) -> TrafficTotals {
        switch route {
        case .wifi:
            return TrafficTotals(download: wifiDownload, upload: wifiUpload)
        case .hotspot:
            return TrafficTotals(download: hotspotDownload, upload: hotspotUpload)
        case .other:
            return TrafficTotals(download: otherDownload, upload: otherUpload)
        case nil:
            return TrafficTotals(download: totalDownload, upload: totalUpload)
        }
    }
}

private struct TrafficHistoryState {
    let buckets: [TrafficBucket]

    static let initial = TrafficHistoryState(buckets: [])

    func totals(
        for route: TrafficRoute? = nil,
        from start: Date? = nil,
        through end: Date? = nil
    ) -> TrafficTotals {
        buckets.reduce(into: TrafficTotals()) { result, bucket in
            if let start, bucket.minute < start { return }
            if let end, bucket.minute > end { return }
            let values = bucket.totals(for: route)
            result.add(download: values.download, upload: values.upload)
        }
    }

    func todayTotals(for route: TrafficRoute? = nil, now: Date = Date(), calendar: Calendar = .current) -> TrafficTotals {
        totals(for: route, from: calendar.startOfDay(for: now), through: now)
    }

    func hotspotDays(count: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> [HotspotDayUsage] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }
            return HotspotDayUsage(
                day: day,
                totals: totals(for: .hotspot, from: day, through: tomorrow.addingTimeInterval(-0.001))
            )
        }
    }
}

private struct HotspotDayUsage: Identifiable {
    let day: Date
    let totals: TrafficTotals

    var id: Date { day }
}

private struct TrafficRateSample: Codable, Identifiable {
    let timestamp: Date
    let download: Double
    let upload: Double

    var id: Date { timestamp }
}

private struct TrafficRateHistoryState {
    let samples: [TrafficRateSample]

    static let initial = TrafficRateHistoryState(samples: [])
}

private enum TrafficRange: String, CaseIterable, Identifiable {
    case quarterHour = "15 MIN"
    case hour = "1 H"
    case today = "DZIŚ"

    var id: String { rawValue }

    var bucketDuration: TimeInterval {
        switch self {
        case .quarterHour, .hour: return 60
        case .today: return 15 * 60
        }
    }

    func start(at date: Date) -> Date {
        switch self {
        case .quarterHour:
            return date.addingTimeInterval(-15 * 60)
        case .hour:
            return date.addingTimeInterval(-60 * 60)
        case .today:
            return Calendar.current.startOfDay(for: date)
        }
    }

    func plotCount(at date: Date) -> Int {
        switch self {
        case .quarterHour: return 15
        case .hour: return 60
        case .today:
            let elapsed = date.timeIntervalSince(start(at: date))
            return max(1, Int(ceil(elapsed / bucketDuration)))
        }
    }
}

private struct TrafficChartSample: Identifiable {
    let timestamp: Date
    let download: Double
    let upload: Double

    var id: Date { timestamp }
}

private struct TrafficWindow {
    let chartSamples: [TrafficChartSample]
    let start: Date
    let end: Date
    let totals: TrafficTotals
    let maximumDownload: Double
    let maximumUpload: Double
    let averageDownload: Double
    let averageUpload: Double

    static func make(
        from history: TrafficHistoryState,
        rateHistory: TrafficRateHistoryState,
        range: TrafficRange,
        now: Date = Date()
    ) -> TrafficWindow {
        let start = range.start(at: now)
        let matching = history.buckets.filter { $0.minute >= start && $0.minute <= now }
        var totals = TrafficTotals()

        for bucket in matching {
            totals.add(download: bucket.totalDownload, upload: bucket.totalUpload)
        }

        let chartSamples: [TrafficChartSample]
        if range == .today {
            let count = range.plotCount(at: now)
            var downloads = Array(repeating: 0.0, count: count)
            var uploads = Array(repeating: 0.0, count: count)
            // Earlier hotspot totals are migrated as a midnight seed: count them, but do not fake a spike.
            for bucket in matching where bucket.minute != start {
                let offset = max(0, bucket.minute.timeIntervalSince(start))
                let index = min(count - 1, Int(offset / range.bucketDuration))
                downloads[index] += Double(bucket.totalDownload) / range.bucketDuration
                uploads[index] += Double(bucket.totalUpload) / range.bucketDuration
            }
            chartSamples = (0..<count).map { index in
                TrafficChartSample(
                    timestamp: start.addingTimeInterval(Double(index) * range.bucketDuration),
                    download: downloads[index],
                    upload: uploads[index]
                )
            }
        } else {
            chartSamples = rateHistory.samples
                .filter { $0.timestamp >= start && $0.timestamp <= now }
                .map {
                    TrafficChartSample(
                        timestamp: $0.timestamp,
                        download: $0.download,
                        upload: $0.upload
                    )
                }
        }

        let averageDownload: Double
        let averageUpload: Double
        if range == .today {
            let elapsed = max(now.timeIntervalSince(start), 1)
            averageDownload = Double(totals.download) / elapsed
            averageUpload = Double(totals.upload) / elapsed
        } else {
            let sampleCount = max(Double(chartSamples.count), 1)
            averageDownload = chartSamples.map(\.download).reduce(0, +) / sampleCount
            averageUpload = chartSamples.map(\.upload).reduce(0, +) / sampleCount
        }
        return TrafficWindow(
            chartSamples: chartSamples,
            start: start,
            end: now,
            totals: totals,
            maximumDownload: chartSamples.map(\.download).max() ?? 0,
            maximumUpload: chartSamples.map(\.upload).max() ?? 0,
            averageDownload: averageDownload,
            averageUpload: averageUpload
        )
    }
}

private struct ForecastHour: Identifiable {
    let id = UUID()
    let time: String
    let date: Date?
    let temperature: Double
    let precipitationProbability: Int?
    let precipitation: Double?
    let windSpeed: Double
    let windGusts: Double?
    let weatherCode: Int

    var shortTime: String {
        String(time.suffix(5))
    }
}

private struct RainNotice {
    let compactText: String
    let detailText: String
}

private struct AirQualitySnapshot {
    let europeanAQI: Int?
    let pm25: Double?
    let pm10: Double?
    let uvIndex: Double?

    var qualityLabel: String {
        guard let europeanAQI else { return "czekam" }
        switch europeanAQI {
        case ...20: return "dobre"
        case 21...40: return "OK"
        case 41...60: return "średnie"
        case 61...80: return "słabe"
        case 81...100: return "złe"
        default: return "bardzo złe"
        }
    }

    var detailText: String {
        var parts: [String] = []
        if let europeanAQI {
            parts.append("AQI \(europeanAQI)")
        }
        if let pm25 {
            parts.append("PM2.5 \(WeatherDisplay.micrograms(pm25))")
        }
        return parts.isEmpty ? "Open-Meteo AQI" : parts.joined(separator: " · ")
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        let sample = AirQualitySnapshot(
            europeanAQI: 26,
            pm25: 8.7,
            pm10: 11.4,
            uvIndex: 0
        )
        if sample.qualityLabel != "OK" {
            failures.append("AQI 26 powinien być opisany jako OK")
        }
        if !sample.detailText.contains("PM2.5 8,7 µg/m³") {
            failures.append("PM2.5 powinno mieć polski przecinek i jednostkę")
        }
        let poor = AirQualitySnapshot(
            europeanAQI: 82,
            pm25: nil,
            pm10: nil,
            uvIndex: nil
        )
        if poor.qualityLabel != "złe" {
            failures.append("AQI 82 powinien być opisany jako złe")
        }
        return failures
    }
}

private struct WeatherPlace {
    let name: String
    let latitude: Double
    let longitude: Double
    let usesDeviceLocation: Bool
}

private enum WeatherSource: String {
    case openMeteo
    case icon
    case metNo

    var label: String {
        switch self {
        case .openMeteo: return "Open-Meteo AUTO"
        case .icon: return "DWD ICON"
        case .metNo: return "MET Norway"
        }
    }

    var shortLabel: String {
        switch self {
        case .openMeteo: return "AUTO"
        case .icon: return "ICON"
        case .metNo: return "MET.no"
        }
    }
}

private enum ForecastRange: String, CaseIterable, Identifiable {
    case fourHours = "4 H"
    case twelveHours = "12 H"
    case day = "24 H"

    var id: String { rawValue }

    var hourCount: Int {
        switch self {
        case .fourHours: return 4
        case .twelveHours: return 12
        case .day: return 24
        }
    }

    var sampleStride: Int {
        switch self {
        case .fourHours: return 1
        case .twelveHours: return 3
        case .day: return 6
        }
    }
}

private enum WeatherMode {
    case loading
    case needsLocation
    case ready
    case notFound
    case failure
}

private struct WeatherState {
    let mode: WeatherMode
    let place: WeatherPlace?
    let temperature: Double?
    let apparentTemperature: Double?
    let weatherCode: Int?
    let windSpeed: Double?
    let windGusts: Double?
    let precipitation: Double?
    let hours: [ForecastHour]
    let outlook: String
    let source: WeatherSource
    var fallbackFrom: WeatherSource? = nil

    static func loading(source: WeatherSource, place: WeatherPlace? = nil) -> WeatherState {
        WeatherState(
            mode: .loading,
            place: place,
            temperature: nil,
            apparentTemperature: nil,
            weatherCode: nil,
            windSpeed: nil,
            windGusts: nil,
            precipitation: nil,
            hours: [],
            outlook: "Pobieram prognozę",
            source: source
        )
    }

    static let needsLocation = WeatherState(
        mode: .needsLocation,
        place: nil,
        temperature: nil,
        apparentTemperature: nil,
        weatherCode: nil,
        windSpeed: nil,
        windGusts: nil,
        precipitation: nil,
        hours: [],
        outlook: "Włącz lokalizację lub wpisz miejscowość",
        source: .openMeteo
    )

    static func locationFailure(source: WeatherSource) -> WeatherState {
        WeatherState(
            mode: .needsLocation,
            place: nil,
            temperature: nil,
            apparentTemperature: nil,
            weatherCode: nil,
            windSpeed: nil,
            windGusts: nil,
            precipitation: nil,
            hours: [],
            outlook: "Nie dostałem lokalizacji. Wpisz miejscowość lub sprawdź zgodę.",
            source: source
        )
    }

    func replacingPlace(_ updatedPlace: WeatherPlace) -> WeatherState {
        WeatherState(
            mode: mode,
            place: updatedPlace,
            temperature: temperature,
            apparentTemperature: apparentTemperature,
            weatherCode: weatherCode,
            windSpeed: windSpeed,
            windGusts: windGusts,
            precipitation: precipitation,
            hours: hours,
            outlook: outlook,
            source: source,
            fallbackFrom: fallbackFrom
        )
    }
}

private enum SleepMode {
    case loading
    case enabled
    case disabled
    case unknown
    case failure

    var isPreventingSleep: Bool {
        self == .enabled
    }

    var label: String {
        switch self {
        case .loading: return "Sprawdzam stan"
        case .enabled: return "Aktywne"
        case .disabled: return "Wyłączone"
        case .unknown: return "Stan nieznany"
        case .failure: return "Brak odczytu"
        }
    }
}

private struct SleepState {
    let mode: SleepMode
    let configured: Bool

    static let loading = SleepState(mode: .loading, configured: false)
}

private enum VPNMode {
    case loading
    case connected
    case connecting
    case disconnected
    case disconnecting
    case selectionRequired
    case unavailable
    case failure

    var isActive: Bool {
        self == .connected || self == .connecting
    }

    var isToggleable: Bool {
        self != .loading && self != .selectionRequired && self != .unavailable && self != .failure
    }

    var label: String {
        switch self {
        case .loading: return "Sprawdzam stan"
        case .connected: return "Połączony"
        case .connecting: return "Łączenie"
        case .disconnected: return "Rozłączony"
        case .disconnecting: return "Rozłączanie"
        case .selectionRequired: return "Połącz raz w WireGuard"
        case .unavailable: return "Nie znaleziono tunelu"
        case .failure: return "Brak odczytu"
        }
    }
}

private struct VPNState {
    let mode: VPNMode
    let serviceID: String?
    let serviceName: String?

    static let loading = VPNState(mode: .loading, serviceID: nil, serviceName: nil)

    var title: String {
        "VPN lokalny"
    }

    var subtitle: String {
        guard let serviceName else { return mode.label }
        return "\(mode.label) · \(serviceName)"
    }
}

private struct MessageBanner {
    enum Kind {
        case success
        case error
    }

    let kind: Kind
    let text: String
}

private struct CommandOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

private enum ActionResult {
    case success
    case cancelled
    case failure(String)
}

private enum CommandRunner {
    static func run(_ executable: String, _ arguments: [String]) -> CommandOutput {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
            process.waitUntilExit()
            return CommandOutput(
                stdout: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
                stderr: String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
                exitCode: process.terminationStatus
            )
        } catch {
            return CommandOutput(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
    }
}

private enum NetworkProbe {
    static func capture(reusing previous: InterfaceCounter? = nil, refreshMetadata: Bool = false) -> InterfaceCounter? {
        let monitoredCounters = externalCounters()
        guard !monitoredCounters.isEmpty,
              let interfaceName = preferredInterfaceName(in: monitoredCounters) else {
            return nil
        }
        let interfaceDisplayName: String
        let address: String
        if !refreshMetadata, let previous, previous.name == interfaceName {
            interfaceDisplayName = previous.displayName
            address = previous.address
        } else {
            interfaceDisplayName = displayName(for: interfaceName)
            address = ipv4Address(for: interfaceName) ?? "Brak adresu IPv4"
        }
        return InterfaceCounter(
            name: interfaceName,
            displayName: interfaceDisplayName,
            address: address,
            monitoredCounters: monitoredCounters,
            timestamp: Date()
        )
    }

    private static func preferredInterfaceName(in counters: [String: LinkCounter]) -> String? {
        if let primary = primaryInterfaceName(), counters[primary] != nil {
            return primary
        }
        return counters.keys.sorted().first
    }

    private static func primaryInterfaceName() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Szlauch" as CFString, nil, nil),
              let state = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)
                as? [String: Any],
              let name = state["PrimaryInterface"] as? String else {
            return nil
        }
        return name
    }

    private static func externalCounters() -> [String: LinkCounter] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return [:]
        }
        defer { freeifaddrs(pointer) }

        var networkInterfaces = Set<String>()
        var linkCounters: [String: LinkCounter] = [:]
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let entryPointer = current {
            let entry = entryPointer.pointee
            let name = String(cString: entry.ifa_name)
            if isExternalDataInterface(name), let address = entry.ifa_addr {
                let family = Int32(address.pointee.sa_family)
                if family == AF_INET || family == AF_INET6 {
                    networkInterfaces.insert(name)
                } else if family == AF_LINK,
                          let data = entry.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                    linkCounters[name] = LinkCounter(
                        incomingBytes: data.ifi_ibytes,
                        outgoingBytes: data.ifi_obytes
                    )
                }
            }
            current = entry.ifa_next
        }
        return linkCounters.filter { networkInterfaces.contains($0.key) }
    }

    private static func isExternalDataInterface(_ name: String) -> Bool {
        if name.hasPrefix("pdp_ip") {
            return true
        }
        return name.range(of: #"^en[0-9]+$"#, options: .regularExpression) != nil
    }

    private static func ipv4Address(for interfaceName: String) -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return nil
        }
        defer { freeifaddrs(pointer) }

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let entryPointer = current {
            let entry = entryPointer.pointee
            if String(cString: entry.ifa_name) == interfaceName,
               let address = entry.ifa_addr,
               Int32(address.pointee.sa_family) == AF_INET {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    address,
                    socklen_t(address.pointee.sa_len),
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    return String(cString: host)
                }
            }
            current = entry.ifa_next
        }
        return nil
    }

    private static func displayName(for interfaceName: String) -> String {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return interfaceName
        }
        for item in interfaces {
            if SCNetworkInterfaceGetBSDName(item) as String? == interfaceName {
                return SCNetworkInterfaceGetLocalizedDisplayName(item) as String? ?? interfaceName
            }
        }
        return interfaceName
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        func check(_ condition: @autoclosure () -> Bool, _ text: String) {
            if !condition() { failures.append(text) }
        }

        check(isExternalDataInterface("en0"), "Wi-Fi powinno być liczone jako łącze zewnętrzne.")
        check(isExternalDataInterface("en8"), "USB LAN powinno być liczone jako łącze zewnętrzne.")
        check(!isExternalDataInterface("utun3"), "Tunel VPN nie może być doliczany drugi raz.")
        check(!isExternalDataInterface("awdl0"), "Interfejs lokalny Apple Wireless Direct Link nie powinien zawyżać Internetu.")
        check(counterDelta(15, after: UInt32.max - 4) == 20, "Licznik powinien przetrwać rollover 32-bitowy.")
        return failures
    }
}

private enum WiFiProbe {
    static func capture() -> WiFiState {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiState(connection: .unavailable, interfaceName: nil, networkName: nil, rssi: nil)
        }
        guard interface.powerOn() else {
            return WiFiState(
                connection: .poweredOff,
                interfaceName: interface.interfaceName,
                networkName: nil,
                rssi: nil
            )
        }

        let rssi = interface.rssiValue()
        guard rssi != 0 else {
            return WiFiState(
                connection: .disconnected,
                interfaceName: interface.interfaceName,
                networkName: nil,
                rssi: nil
            )
        }
        return WiFiState(
            connection: .connected,
            interfaceName: interface.interfaceName,
            networkName: interface.ssid(),
            rssi: rssi
        )
    }

    static func networks(named name: String? = nil, includeHidden: Bool = false) throws -> WiFiScanResult {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiScanResult(networks: [], namesAreRestricted: false)
        }
        let networks = try interface.scanForNetworks(withName: name, includeHidden: includeHidden)
        var strongestByName: [String: CWNetwork] = [:]
        for network in networks {
            guard let name = network.ssid, !name.isEmpty else { continue }
            if let existing = strongestByName[name], existing.rssiValue >= network.rssiValue {
                continue
            }
            strongestByName[name] = network
        }
        let options = strongestByName.values.map { network in
            WiFiNetworkOption(
                id: network.ssid ?? UUID().uuidString,
                name: network.ssid ?? "Sieć ukryta",
                signal: network.rssiValue,
                secured: !network.supportsSecurity(.none),
                network: network
            )
        }
        .sorted { lhs, rhs in
            if lhs.signal != rhs.signal { return lhs.signal > rhs.signal }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return WiFiScanResult(
            networks: options,
            namesAreRestricted: !networks.isEmpty && options.isEmpty
        )
    }

    static func connectSavedNetwork(named name: String) -> ActionResult {
        guard let interfaceName = CWWiFiClient.shared().interface()?.interfaceName else {
            return .failure("Interfejs Wi-Fi jest niedostępny.")
        }
        let result = CommandRunner.run(
            "/usr/sbin/networksetup",
            ["-setairportnetwork", interfaceName, name]
        )
        guard result.exitCode == 0 else {
            return .failure(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .success
    }

    static func connect(to option: WiFiNetworkOption, password: String?) -> ActionResult {
        guard let interface = CWWiFiClient.shared().interface() else {
            return .failure("Interfejs Wi-Fi jest niedostępny.")
        }
        do {
            try interface.associate(to: option.network, password: password)
            return .success
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

private enum SystemProbe {
    static func cpuCounter() -> CPUCounter? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let active = user + system + nice
        return CPUCounter(active: active, total: active + idle)
    }

    static func coreCounters() -> [CPUCounter]? {
        var processorCount: natural_t = 0
        var information: processor_info_array_t?
        var informationCount: mach_msg_type_number_t = 0
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &information,
            &informationCount
        )
        guard result == KERN_SUCCESS, let information else { return nil }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: information),
                vm_size_t(informationCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let values = UnsafeBufferPointer(start: information, count: Int(informationCount))
        return (0..<Int(processorCount)).map { index in
            let offset = index * Int(CPU_STATE_MAX)
            let user = UInt64(values[offset])
            let system = UInt64(values[offset + 1])
            let idle = UInt64(values[offset + 2])
            let nice = UInt64(values[offset + 3])
            let active = user + system + nice
            return CPUCounter(active: active, total: active + idle)
        }
    }

    static func memory() -> (used: UInt64, total: UInt64)? {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        let total = ProcessInfo.processInfo.physicalMemory
        let usedPages = UInt64(info.active_count)
            + UInt64(info.wire_count)
            + UInt64(info.compressor_page_count)
        let used = min(total, usedPages * UInt64(pageSize))
        return (used, total)
    }

    static func applicationUsage() -> (cpu: [ProcessUsage], memory: [ProcessUsage]) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,%cpu=,rss=,comm="]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ([], [])
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else {
            return ([], [])
        }
        var applications: [String: ProcessUsage] = [:]
        for line in text.components(separatedBy: .newlines) {
            let fields = line.split(
                maxSplits: 3,
                omittingEmptySubsequences: true,
                whereSeparator: \.isWhitespace
            )
            guard fields.count == 4,
                  let cpu = Double(fields[1]),
                  let memoryKB = UInt64(fields[2]),
                  let name = applicationName(from: String(fields[3])) else {
                continue
            }
            let existing = applications[name]
            applications[name] = ProcessUsage(
                id: name,
                name: name,
                cpu: (existing?.cpu ?? 0) + cpu,
                memoryBytes: (existing?.memoryBytes ?? 0) + memoryKB * 1024
            )
        }
        let items = Array(applications.values)
        return (
            cpu: items.sorted { $0.cpu > $1.cpu }.prefix(8).map { $0 },
            memory: items.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(8).map { $0 }
        )
    }

    private static func applicationName(from command: String) -> String? {
        guard let range = command.range(of: ".app/") else { return nil }
        let bundleEnd = command.index(range.lowerBound, offsetBy: 4)
        let bundlePath = String(command[..<bundleEnd])
        let name = URL(fileURLWithPath: bundlePath)
            .deletingPathExtension()
            .lastPathComponent
        return name.isEmpty ? nil : name
    }
}

private enum RateDisplayUnit: String, CaseIterable, Identifiable {
    case megabytes = "MB/s"
    case megabits = "Mb/s"
    case kilobytes = "KB/s"

    static let storageKey = "transfer-v1.display-unit"
    var id: String { rawValue }

    var description: String {
        switch self {
        case .megabytes: return "megabajty"
        case .megabits: return "megabity"
        case .kilobytes: return "kilobajty"
        }
    }

    static func current() -> RateDisplayUnit {
        guard let stored = UserDefaults.standard.string(forKey: storageKey),
              let unit = RateDisplayUnit(rawValue: stored) else {
            return .megabytes
        }
        return unit
    }
}

private enum RateFormatter {
    private static let kilobyte = 1024.0
    private static let megabyte = kilobyte * 1024

    private static let detailedNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let wholeNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let megabyteNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static func menu(_ bytesPerSecond: Double, unit: RateDisplayUnit) -> String {
        switch unit {
        case .kilobytes:
            return "\(whole(bytesPerSecond / kilobyte)) \(unit.rawValue)"
        case .megabytes:
            return "\(megabytes(bytesPerSecond / megabyte)) \(unit.rawValue)"
        case .megabits:
            return "\(megabytes(bytesPerSecond * 8 / megabyte)) \(unit.rawValue)"
        }
    }

    static func detailed(_ bytesPerSecond: Double, unit: RateDisplayUnit) -> String {
        switch unit {
        case .kilobytes:
            return "\(number(bytesPerSecond / kilobyte)) \(unit.rawValue)"
        case .megabytes:
            return "\(megabytes(bytesPerSecond / megabyte)) \(unit.rawValue)"
        case .megabits:
            return "\(megabytes(bytesPerSecond * 8 / megabyte)) \(unit.rawValue)"
        }
    }

    static func axisValue(_ bytesPerSecond: Double, unit: RateDisplayUnit) -> String {
        if bytesPerSecond < 1 {
            return "0"
        }
        switch unit {
        case .kilobytes:
            return number(bytesPerSecond / kilobyte)
        case .megabytes:
            return megabytes(bytesPerSecond / megabyte)
        case .megabits:
            return megabytes(bytesPerSecond * 8 / megabyte)
        }
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        if detailed(0, unit: .kilobytes) != "0 KB/s" {
            failures.append("zerowy odczyt KB/s zmienił format")
        }
        if !detailed(1_024 * 1_024, unit: .kilobytes).hasSuffix(" KB/s") {
            failures.append("tryb KB/s dynamicznie zmienił jednostkę")
        }
        if !detailed(2_048, unit: .megabytes).hasSuffix(" MB/s") {
            failures.append("tryb MB/s dynamicznie zmienił jednostkę")
        }
        if detailed(megabyte, unit: .megabits) != "8,00 Mb/s" {
            failures.append("przeliczenie megabajtów na megabity jest niepoprawne")
        }
        return failures
    }

    private static func number(_ value: Double) -> String {
        detailedNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func whole(_ value: Double) -> String {
        wholeNumber.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }

    private static func megabytes(_ value: Double) -> String {
        megabyteNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private enum MetricFormatter {
    private static let gibibyte = 1024.0 * 1024 * 1024

    static func percent(_ ratio: Double) -> String {
        "\(Int((max(0, min(ratio, 1)) * 100).rounded()))%"
    }

    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / gibibyte)
            .replacingOccurrences(of: ".", with: ",") + " GB"
    }

    static func mobileData(_ bytes: UInt64) -> String {
        let kilobyte = 1_000.0
        let megabyte = 1_000_000.0
        let gigabyte = 1_000_000_000.0
        if bytes < UInt64(megabyte) {
            return "\(Int((Double(bytes) / kilobyte).rounded())) KB"
        }
        if bytes < UInt64(gigabyte) {
            return "\(Int((Double(bytes) / megabyte).rounded())) MB"
        }
        return String(format: "%.2f", Double(bytes) / gigabyte)
            .replacingOccurrences(of: ".", with: ",") + " GB"
    }

    static func applicationMemory(_ bytes: UInt64) -> String {
        let megabyte = 1024.0 * 1024
        let gigabyte = megabyte * 1024
        if bytes < UInt64(gigabyte) {
            return "\(Int((Double(bytes) / megabyte).rounded())) MB"
        }
        return String(format: "%.1f", Double(bytes) / gigabyte)
            .replacingOccurrences(of: ".", with: ",") + " GB"
    }
}

private enum WeatherDisplay {
    static func temperature(_ value: Double?) -> String {
        guard let value else { return "--°C" }
        return "\(Int(value.rounded()))°C"
    }

    static func symbol(for code: Int?) -> String {
        guard let code else { return "cloud.sun.fill" }
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int?) -> String {
        guard let code else { return "Brak danych" }
        switch code {
        case 0: return "Bezchmurnie"
        case 1, 2: return "Częściowe zachmurzenie"
        case 3: return "Pochmurno"
        case 45, 48: return "Mgła"
        case 51, 53, 55, 56, 57: return "Mżawka"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "Deszcz"
        case 71, 73, 75, 77, 85, 86: return "Śnieg"
        case 95, 96, 99: return "Burza"
        default: return "Zmienna pogoda"
        }
    }

    static func wind(_ value: Double?) -> String {
        guard let value else { return "-- km/h" }
        return "\(Int(value.rounded())) km/h"
    }

    static func rainfall(_ value: Double?) -> String {
        guard let value else { return "-- mm" }
        return String(format: "%.1f mm", value).replacingOccurrences(of: ".", with: ",")
    }

    static func micrograms(_ value: Double?) -> String {
        guard let value else { return "-- µg/m³" }
        return String(format: "%.1f µg/m³", value).replacingOccurrences(of: ".", with: ",")
    }

    static func precipitationLabel(for hour: ForecastHour) -> String {
        if let probability = hour.precipitationProbability {
            return "\(probability)%"
        }
        guard let precipitation = hour.precipitation else { return "--" }
        if precipitation < 0.1 {
            return "0 mm"
        }
        return rainfall(precipitation)
    }

    static func secondarySymbolColor(for code: Int?) -> Color {
        guard let code else { return Color(hex: 0xFFF5D9).opacity(0.92) }
        switch code {
        case 0, 1, 2:
            return Color(hex: 0xFFF5D9).opacity(0.96)
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return Color(hex: 0x00A5FF).opacity(0.96)
        case 71, 73, 75, 77, 85, 86:
            return Color(hex: 0xE2F1FF).opacity(0.98)
        case 95, 96, 99:
            return Color(hex: 0xD857FF).opacity(0.92)
        default:
            return Color.secondary.opacity(0.8)
        }
    }
}

private struct WeatherGlyph: View {
    let code: Int?
    let size: CGFloat

    var body: some View {
        Image(systemName: WeatherDisplay.symbol(for: code))
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                Color.primary.opacity(0.94),
                WeatherDisplay.secondarySymbolColor(for: code)
            )
    }
}

private enum SleepService {
    static let sudoersFile = "/private/etc/sudoers.d/szlauch-pmset"
    private static let legacySudoersFiles = [
        "/private/etc/sudoers.d/pulse-bar-pmset",
        "/private/etc/sudoers.d/sleep-toggle-pmset"
    ]

    static func readState() -> SleepState {
        let output = CommandRunner.run("/usr/bin/pmset", ["-g"])
        guard output.exitCode == 0 else {
            return SleepState(mode: .failure, configured: hasPermission())
        }
        for line in output.stdout.components(separatedBy: .newlines) {
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.count > 1, fields[0] == "SleepDisabled" else { continue }
            if fields[1] == "1" {
                return SleepState(mode: .enabled, configured: hasPermission())
            }
            if fields[1] == "0" {
                return SleepState(mode: .disabled, configured: hasPermission())
            }
        }
        return SleepState(mode: .unknown, configured: hasPermission())
    }

    static func hasPermission() -> Bool {
        FileManager.default.fileExists(atPath: sudoersFile)
            || legacySudoersFiles.contains(where: FileManager.default.fileExists(atPath:))
    }

    static func setPrevention(_ enabled: Bool) -> ActionResult {
        let result = CommandRunner.run(
            "/usr/bin/sudo",
            ["-n", "/usr/bin/pmset", "-a", "disablesleep", enabled ? "1" : "0"]
        )
        guard result.exitCode == 0 else {
            return .failure("Nie udało się zmienić blokady uśpienia.")
        }
        return .success
    }

    static func installPermission() -> ActionResult {
        let user = CommandRunner.run("/usr/bin/id", ["-un"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            return .failure("Nie mogę bezpiecznie rozpoznać użytkownika tego Maca.")
        }

        let script = """
        set -eu
        user=\(shellQuote(user))
        file=\(shellQuote(sudoersFile))
        tmp=$(/usr/bin/mktemp /tmp/szlauch-sudoers.XXXXXX)
        trap '/bin/rm -f "$tmp"' EXIT
        /bin/chmod 0440 "$tmp"
        /usr/sbin/chown root:wheel "$tmp"
        { /bin/echo "# Created for Szlauch. Allows only this user to toggle disablesleep without another password prompt."; /bin/echo "$user ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"; } > "$tmp"
        /usr/sbin/visudo -cf "$tmp" >/dev/null
        /bin/mv "$tmp" "$file"
        /bin/chmod 0440 "$file"
        /usr/sbin/chown root:wheel "$file"
        /usr/sbin/visudo -cf /private/etc/sudoers >/dev/null
        """
        return runAdministrativeScript(
            script,
            verifies: hasPermission,
            failureText: "Nie udało się nadać jednorazowej zgody."
        )
    }

    static func removePermission() -> ActionResult {
        let files = ([sudoersFile] + legacySudoersFiles)
            .map(shellQuote)
            .joined(separator: " ")
        let script = """
        set -eu
        /usr/bin/pmset -a disablesleep 0
        /bin/rm -f \(files)
        """
        return runAdministrativeScript(
            script,
            verifies: { !hasPermission() },
            failureText: "Nie udało się usunąć zgody do blokady uśpienia."
        )
    }

    static func selfTestFailures() -> [String] {
        var failures: [String] = []
        if !isUserCancellation("0:163: execution error: User cancelled. (-128)") {
            failures.append("anulowanie po angielsku nie zostało rozpoznane")
        }
        if !isUserCancellation("execution error: Anulowano przez użytkownika. (-128)") {
            failures.append("kod anulowania -128 nie został rozpoznany")
        }
        if isUserCancellation("execution error: Permission denied. (-1743)") {
            failures.append("rzeczywisty błąd został uznany za anulowanie")
        }
        return failures
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func runAdministrativeScript(
        _ script: String,
        verifies: () -> Bool,
        failureText: String
    ) -> ActionResult {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("szlauch-sleep-\(UUID().uuidString).sh")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o700)],
                ofItemAtPath: url.path
            )
        } catch {
            return .failure("Nie udało się przygotować konfiguracji.")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let command = "/bin/zsh " + shellQuote(url.path)
        let osaCommand = "do shell script \(appleScriptLiteral(command)) with administrator privileges"
        let result = CommandRunner.run("/usr/bin/osascript", ["-e", osaCommand])
        guard result.exitCode == 0, verifies() else {
            let text = (result.stderr + result.stdout).trimmingCharacters(in: .whitespacesAndNewlines)
            if isUserCancellation(text) {
                return .cancelled
            }
            return .failure(failureText)
        }
        return .success
    }

    private static func appleScriptLiteral(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func isUserCancellation(_ text: String) -> Bool {
        text.contains("(-128)")
            || text.localizedCaseInsensitiveContains("user cancelled")
            || text.localizedCaseInsensitiveContains("user canceled")
    }
}

private enum VPNService {
    private struct Service: Equatable {
        let id: String
        let name: String
        let connected: Bool
    }

    private static let selectedServiceKey = "vpn-v1.selected-service-id"

    static func readState() -> VPNState {
        let services = availableServices()
        guard !services.isEmpty else {
            return VPNState(mode: .unavailable, serviceID: nil, serviceName: nil)
        }
        guard let service = selectedService(in: services) else {
            return VPNState(mode: .selectionRequired, serviceID: nil, serviceName: nil)
        }
        let result = CommandRunner.run("/usr/sbin/scutil", ["--nc", "status", service.id])
        guard result.exitCode == 0,
              let line = result.stdout.components(separatedBy: .newlines).first else {
            return VPNState(mode: .failure, serviceID: service.id, serviceName: service.name)
        }

        let mode: VPNMode
        switch line.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Connected": mode = .connected
        case "Connecting": mode = .connecting
        case "Disconnected": mode = .disconnected
        case "Disconnecting": mode = .disconnecting
        default: mode = .failure
        }
        return VPNState(mode: mode, serviceID: service.id, serviceName: service.name)
    }

    static func setConnected(_ enabled: Bool, serviceID: String?) -> ActionResult {
        guard let serviceID = serviceID ?? selectedService(in: availableServices())?.id else {
            return .failure("Nie wybrano tunelu WireGuard.")
        }
        let command = enabled ? "start" : "stop"
        let result = CommandRunner.run("/usr/sbin/scutil", ["--nc", command, serviceID])
        guard result.exitCode == 0 else {
            let text = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(text.isEmpty ? "Nie udało się zmienić stanu VPN." : text)
        }
        return .success
    }

    private static func availableServices() -> [Service] {
        let result = CommandRunner.run("/usr/sbin/scutil", ["--nc", "list"])
        guard result.exitCode == 0 else { return [] }
        return parseServices(from: result.stdout)
    }

    private static func parseServices(from output: String) -> [Service] {
        output.components(separatedBy: .newlines).compactMap { line in
            guard line.localizedCaseInsensitiveContains("com.wireguard.macos"),
                  let idMatch = line.range(
                of: #"[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}"#,
                options: [.regularExpression, .caseInsensitive]
                  ),
                  let openingQuote = line.firstIndex(of: "\"") else {
                return nil
            }
            let nameStart = line.index(after: openingQuote)
            let remainder = line[nameStart...]
            let nameEnd = remainder.firstIndex(of: "\"")
                ?? remainder.range(of: " [VPN:")?.lowerBound
                ?? line.endIndex
            return Service(
                id: String(line[idMatch]),
                name: String(line[nameStart..<nameEnd]),
                connected: line.contains("(Connected)")
            )
        }
    }

    private static func selectedService(in services: [Service]) -> Service? {
        let savedID = UserDefaults.standard.string(forKey: selectedServiceKey)
        guard let selection = resolvedService(in: services, savedID: savedID) else {
            return nil
        }
        if selection.connected || savedID == nil || !services.contains(where: { $0.id == savedID }) {
            remember(selection)
        }
        return selection
    }

    private static func resolvedService(in services: [Service], savedID: String?) -> Service? {
        if let connected = services.first(where: \.connected) {
            return connected
        }
        if let savedID,
           let saved = services.first(where: { $0.id == savedID }) {
            return saved
        }
        if services.count == 1, let only = services.first {
            return only
        }
        return nil
    }

    private static func remember(_ service: Service) {
        UserDefaults.standard.set(service.id, forKey: selectedServiceKey)
    }

    static func selfTestFailures() -> [String] {
        let savedID = "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB"
        let activeID = "CCCCCCCC-4444-5555-6666-DDDDDDDDDDDD"
        let travelID = "EEEEEEEE-7777-8888-9999-FFFFFFFFFFFF"
        let fixture = """
        Available network connection services in the current set (*=enabled):
        * (Disconnected)   \(savedID) VPN (com.wireguard.macos) "Home Tunnel" [VPN:com.wireguard.macos]
        * (Connected)      \(activeID) VPN (com.wireguard.macos) "Work Tunnel" [VPN:com.wireguard.macos]
        * (Disconnected)   \(travelID) VPN (com.wireguard.macos) "Travel Tunnel" [VPN:com.wireguard.macos]
        * (Connected)      11111111-1111-1111-1111-111111111111 PPP --> Modem "Nie VPN" [PPP:Modem]
        """
        var failures: [String] = []
        func check(_ condition: @autoclosure () -> Bool, _ description: String) {
            if !condition() {
                failures.append(description)
            }
        }

        let parsed = parseServices(from: fixture)
        check(parsed.count == 3, "Parser powinien zachować wyłącznie trzy profile WireGuard.")
        check(parsed.first(where: { $0.id == activeID })?.name == "Work Tunnel", "Parser powinien odczytać nazwę aktywnego profilu.")
        check(resolvedService(in: parsed, savedID: savedID)?.id == activeID, "Aktywny profil powinien mieć pierwszeństwo przed zapamiętanym profilem.")

        let disconnected = parsed.map { Service(id: $0.id, name: $0.name, connected: false) }
        check(resolvedService(in: disconnected, savedID: travelID)?.id == travelID, "Zapamiętany profil powinien działać po rozłączeniu.")
        check(resolvedService(in: disconnected, savedID: nil) == nil, "Przy wielu nowych profilach aplikacja nie może zgadywać tunelu.")
        let oneProfile = [Service(id: activeID, name: "Work Tunnel", connected: false)]
        check(resolvedService(in: oneProfile, savedID: nil)?.id == activeID, "Jedyny dostępny profil powinien być wybrany automatycznie.")
        let unclosedOutput = "* (Connected)      \(travelID) VPN (com.wireguard.macos) \"Travel Tunnel [VPN:com.wireguard.macos]"
        check(parseServices(from: unclosedOutput).first?.name == "Travel Tunnel", "Parser powinien obsłużyć linię usługi bez zamykającego cudzysłowu.")
        return failures
    }
}

private enum TrafficHistoryStore {
    private static let bucketsKey = "traffic-history-v1.buckets"
    private static let savedAtKey = "traffic-history-v1.saved-at"
    private static let saveInterval: TimeInterval = 5
    private static let retentionDays = 31

    static func current(now: Date = Date(), persisting: Bool = true) -> TrafficHistoryState {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: bucketsKey),
              let decoded = try? JSONDecoder().decode([TrafficBucket].self, from: data) else {
            return .initial
        }
        let buckets = retainedBuckets(decoded, now: now)
        if persisting, buckets != decoded {
            save(buckets)
        }
        return TrafficHistoryState(buckets: buckets)
    }

    static func record(
        download: UInt64,
        upload: UInt64,
        route: TrafficRoute,
        in history: TrafficHistoryState,
        now: Date = Date()
    ) -> TrafficHistoryState {
        var buckets = retainedBuckets(history.buckets, now: now)
        let calendar = Calendar.current
        let minute = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        if let index = buckets.lastIndex(where: { $0.minute == minute }) {
            buckets[index].add(download: download, upload: upload, route: route)
        } else {
            var bucket = TrafficBucket(minute: minute)
            bucket.add(download: download, upload: upload, route: route)
            buckets.append(bucket)
        }
        let updated = TrafficHistoryState(buckets: buckets)
        let defaults = UserDefaults.standard
        let savedAt = defaults.object(forKey: savedAtKey) as? Date ?? .distantPast
        if now.timeIntervalSince(savedAt) >= saveInterval {
            persist(updated, now: now)
        }
        return updated
    }

    static func clearHotspot(in history: TrafficHistoryState, now: Date = Date()) -> TrafficHistoryState {
        let updated = removingHotspot(from: history, now: now)
        persist(updated, now: now)
        return updated
    }

    static func persist(_ history: TrafficHistoryState, now: Date = Date()) {
        save(retainedBuckets(history.buckets, now: now))
        UserDefaults.standard.set(now, forKey: savedAtKey)
    }

    static func selfTestFailures() -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        func date(_ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
        }
        var today = TrafficBucket(minute: date(3))
        today.add(download: 720_000_000, upload: 41_000_000, route: .hotspot)
        today.add(download: 2_000_000, upload: 3_000_000, route: .wifi)
        var yesterday = TrafficBucket(minute: date(2))
        yesterday.add(download: 1_300_000_000, upload: 90_000_000, route: .hotspot)
        var yesterdayLater = TrafficBucket(minute: date(2, 17))
        yesterdayLater.add(download: 200_000_000, upload: 10_000_000, route: .hotspot)
        var expired = TrafficBucket(minute: date(1).addingTimeInterval(-32 * 24 * 60 * 60))
        expired.add(download: 99, upload: 99, route: .hotspot)
        let history = TrafficHistoryState(buckets: [expired, yesterday, yesterdayLater, today])
        let days = history.hotspotDays(count: 2, now: date(3, 18), calendar: calendar)
        var failures: [String] = []
        if days.first?.totals.download != 720_000_000 || days.last?.totals.download != 1_500_000_000 {
            failures.append("dzienna historia hotspotu nie rozdziela dni")
        }
        let retained = retainedBuckets(history.buckets, now: date(3, 18), calendar: calendar)
        if retained.count != 2 || retained.first?.minute != calendar.startOfDay(for: date(2)) {
            failures.append("historia hotspotu nie kompaktuje starych dni ani nie usuwa danych po 31 dniach")
        }
        let cleared = removingHotspot(from: history, now: date(3, 18), calendar: calendar)
        if cleared.totals(for: .hotspot).total != 0 || cleared.totals(for: .wifi).total != 5_000_000 {
            failures.append("reset hotspotu narusza dane całego ruchu")
        }
        return failures
    }

    private static func removingHotspot(
        from history: TrafficHistoryState,
        now: Date,
        calendar: Calendar = .current
    ) -> TrafficHistoryState {
        let buckets = retainedBuckets(history.buckets, now: now, calendar: calendar).map { bucket in
            var cleared = bucket
            cleared.hotspotDownload = 0
            cleared.hotspotUpload = 0
            return cleared
        }
        return TrafficHistoryState(buckets: buckets)
    }

    private static func retainedBuckets(
        _ buckets: [TrafficBucket],
        now: Date,
        calendar: Calendar = .current
    ) -> [TrafficBucket] {
        let today = calendar.startOfDay(for: now)
        let cutoff = calendar.date(byAdding: .day, value: -(retentionDays - 1), to: today) ?? today
        let candidates = buckets.filter { $0.minute >= cutoff && $0.minute <= now }
        var daily: [Date: TrafficBucket] = [:]
        var currentDay: [TrafficBucket] = []
        for bucket in candidates {
            guard bucket.minute < today else {
                currentDay.append(bucket)
                continue
            }
            let day = calendar.startOfDay(for: bucket.minute)
            var aggregate = daily[day] ?? TrafficBucket(minute: day)
            for route in [TrafficRoute.wifi, .hotspot, .other] {
                let values = bucket.totals(for: route)
                aggregate.add(download: values.download, upload: values.upload, route: route)
            }
            daily[day] = aggregate
        }
        return daily.values.sorted(by: { $0.minute < $1.minute })
            + currentDay.sorted(by: { $0.minute < $1.minute })
    }

    private static func save(_ buckets: [TrafficBucket]) {
        guard let data = try? JSONEncoder().encode(buckets) else { return }
        UserDefaults.standard.set(data, forKey: bucketsKey)
    }
}

private enum TrafficRateHistoryStore {
    private static let samplesKey = "traffic-rate-history-v1.samples"
    private static let savedAtKey = "traffic-rate-history-v1.saved-at"
    private static let retention: TimeInterval = 60 * 60 + 60
    private static let saveInterval: TimeInterval = 30

    static func current(now: Date = Date(), persisting: Bool = true) -> TrafficRateHistoryState {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: samplesKey),
              let decoded = try? JSONDecoder().decode([TrafficRateSample].self, from: data) else {
            return .initial
        }
        let cutoff = now.addingTimeInterval(-retention)
        let samples = decoded.filter { $0.timestamp >= cutoff && $0.timestamp <= now }
        if persisting, samples.count != decoded.count {
            save(samples)
        }
        return TrafficRateHistoryState(samples: samples)
    }

    static func record(
        download: Double,
        upload: Double,
        in history: TrafficRateHistoryState,
        now: Date = Date()
    ) -> TrafficRateHistoryState {
        let cutoff = now.addingTimeInterval(-retention)
        var samples = history.samples.filter { $0.timestamp >= cutoff && $0.timestamp <= now }
        samples.append(TrafficRateSample(timestamp: now, download: download, upload: upload))
        let defaults = UserDefaults.standard
        let savedAt = defaults.object(forKey: savedAtKey) as? Date ?? .distantPast
        if now.timeIntervalSince(savedAt) >= saveInterval {
            save(samples)
            defaults.set(now, forKey: savedAtKey)
        }
        return TrafficRateHistoryState(samples: samples)
    }

    private static func save(_ samples: [TrafficRateSample]) {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        UserDefaults.standard.set(data, forKey: samplesKey)
    }
}

private enum WeatherSourceStore {
    private static let sourceKey = "weather-v1.source"

    static func current() -> WeatherSource {
        guard let value = UserDefaults.standard.string(forKey: sourceKey),
              let source = WeatherSource(rawValue: value) else {
            return .openMeteo
        }
        return source
    }

    static func set(_ source: WeatherSource) {
        UserDefaults.standard.set(source.rawValue, forKey: sourceKey)
    }
}

private enum WeatherPlaceStore {
    private static let nameKey = "weather-v1.device-place.name"
    private static let latitudeKey = "weather-v1.device-place.latitude"
    private static let longitudeKey = "weather-v1.device-place.longitude"

    static func deviceLocation() -> WeatherPlace? {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: nameKey),
              defaults.object(forKey: latitudeKey) != nil,
              defaults.object(forKey: longitudeKey) != nil else {
            return nil
        }
        return WeatherPlace(
            name: name,
            latitude: defaults.double(forKey: latitudeKey),
            longitude: defaults.double(forKey: longitudeKey),
            usesDeviceLocation: true
        )
    }

    static func setDeviceLocation(_ place: WeatherPlace) {
        guard place.usesDeviceLocation else { return }
        let defaults = UserDefaults.standard
        defaults.set(place.name, forKey: nameKey)
        defaults.set(place.latitude, forKey: latitudeKey)
        defaults.set(place.longitude, forKey: longitudeKey)
    }
}

private enum WeatherService {
    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let precipitation: Double
            let wind_speed_10m: Double
            let wind_gusts_10m: Double
        }

        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let precipitation_probability: [Int]
            let precipitation: [Double]
            let weather_code: [Int]
            let wind_speed_10m: [Double]
            let wind_gusts_10m: [Double]
        }

        let current: Current
        let hourly: Hourly
        let timezone: String?
    }

    private struct MetNoResponse: Decodable {
        struct Properties: Decodable {
            let timeseries: [Moment]
        }

        struct Moment: Decodable {
            struct DataPoint: Decodable {
                struct Instant: Decodable {
                    struct Details: Decodable {
                        let air_temperature: Double
                        let wind_speed: Double
                        let wind_speed_of_gust: Double?
                        let cloud_area_fraction: Double?
                    }

                    let details: Details
                }

                struct Period: Decodable {
                    struct Summary: Decodable {
                        let symbol_code: String?
                    }
                    struct Details: Decodable {
                        let precipitation_amount: Double?
                    }

                    let summary: Summary?
                    let details: Details?
                }

                let instant: Instant
                let next_1_hours: Period?
            }

            let time: String
            let data: DataPoint
        }

        let properties: Properties
    }

    private struct AirQualityResponse: Decodable {
        struct Current: Decodable {
            let european_aqi: Int?
            let pm2_5: Double?
            let pm10: Double?
            let uv_index: Double?
        }

        let current: Current?
    }

    private struct GeocodingResponse: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let admin1: String?
            let country: String?
        }

        let results: [Result]?
    }

    static func fetchAirQuality(
        for place: WeatherPlace,
        retriesRemaining: Int = 1,
        completion: @escaping (AirQualitySnapshot?) -> Void
    ) {
        var components = URLComponents(
            string: "https://air-quality-api.open-meteo.com/v1/air-quality"
        )
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: "\(place.latitude)"),
            URLQueryItem(name: "longitude", value: "\(place.longitude)"),
            URLQueryItem(name: "current", value: "european_aqi,pm2_5,pm10,uv_index"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let response = try? JSONDecoder().decode(AirQualityResponse.self, from: data),
                  let current = response.current else {
                guard retriesRemaining > 0 else {
                    completion(nil)
                    return
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.7) {
                    fetchAirQuality(
                        for: place,
                        retriesRemaining: retriesRemaining - 1,
                        completion: completion
                    )
                }
                return
            }
            completion(
                AirQualitySnapshot(
                    europeanAQI: current.european_aqi,
                    pm25: current.pm2_5,
                    pm10: current.pm10,
                    uvIndex: current.uv_index
                )
            )
        }.resume()
    }

    static func findPlace(named query: String, completion: @escaping (WeatherPlace?) -> Void) {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "pl"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let response = try? JSONDecoder().decode(GeocodingResponse.self, from: data),
                  let result = response.results?.first else {
                completion(nil)
                return
            }
            let qualifier = result.admin1 ?? result.country
            let name = qualifier.map { "\(result.name), \($0)" } ?? result.name
            completion(
                WeatherPlace(
                    name: name,
                    latitude: result.latitude,
                    longitude: result.longitude,
                    usesDeviceLocation: false
                )
            )
        }.resume()
    }

    static func fetch(
        for place: WeatherPlace,
        source: WeatherSource,
        completion: @escaping (WeatherState?) -> Void
    ) {
        switch source {
        case .openMeteo, .icon:
            fetchOpenMeteo(
                for: place,
                source: source,
                retriesRemaining: 1,
                completion: completion
            )
        case .metNo:
            fetchMetNo(for: place, retriesRemaining: 1, completion: completion)
        }
    }

    private static func fetchOpenMeteo(
        for place: WeatherPlace,
        source: WeatherSource,
        retriesRemaining: Int,
        completion: @escaping (WeatherState?) -> Void
    ) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: "\(place.latitude)"),
            URLQueryItem(name: "longitude", value: "\(place.longitude)"),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,weather_code,precipitation,wind_speed_10m,wind_gusts_10m"
            ),
            URLQueryItem(
                name: "hourly",
                value: "temperature_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m,wind_gusts_10m"
            ),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        if source == .icon {
            components?.queryItems?.append(URLQueryItem(name: "models", value: "icon_seamless"))
        }
        guard let url = components?.url else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let response = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
                retryOpenMeteo(
                    for: place,
                    source: source,
                    retriesRemaining: retriesRemaining,
                    completion: completion
                )
                return
            }

            let startIndex = response.hourly.time.firstIndex {
                $0 >= response.current.time
            } ?? 0
            let lastIndex = min(startIndex + 24, response.hourly.time.count)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            dateFormatter.timeZone = response.timezone.flatMap(TimeZone.init(identifier:))
                ?? .autoupdatingCurrent
            let hours = (startIndex..<lastIndex).compactMap { index -> ForecastHour? in
                guard response.hourly.temperature_2m.indices.contains(index),
                      response.hourly.precipitation_probability.indices.contains(index),
                      response.hourly.precipitation.indices.contains(index),
                      response.hourly.weather_code.indices.contains(index),
                      response.hourly.wind_speed_10m.indices.contains(index),
                      response.hourly.wind_gusts_10m.indices.contains(index) else {
                    return nil
                }
                return ForecastHour(
                    time: response.hourly.time[index],
                    date: dateFormatter.date(from: response.hourly.time[index]),
                    temperature: response.hourly.temperature_2m[index],
                    precipitationProbability: response.hourly.precipitation_probability[index],
                    precipitation: response.hourly.precipitation[index],
                    windSpeed: response.hourly.wind_speed_10m[index],
                    windGusts: response.hourly.wind_gusts_10m[index],
                    weatherCode: response.hourly.weather_code[index]
                )
            }
            completion(
                WeatherState(
                    mode: .ready,
                    place: place,
                    temperature: response.current.temperature_2m,
                    apparentTemperature: response.current.apparent_temperature,
                    weatherCode: response.current.weather_code,
                    windSpeed: response.current.wind_speed_10m,
                    windGusts: response.current.wind_gusts_10m,
                    precipitation: response.current.precipitation,
                    hours: hours,
                    outlook: outlook(for: hours, source: source),
                    source: source
                )
            )
        }.resume()
    }

    private static func retryOpenMeteo(
        for place: WeatherPlace,
        source: WeatherSource,
        retriesRemaining: Int,
        completion: @escaping (WeatherState?) -> Void
    ) {
        guard retriesRemaining > 0 else {
            completion(nil)
            return
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.7) {
            fetchOpenMeteo(
                for: place,
                source: source,
                retriesRemaining: retriesRemaining - 1,
                completion: completion
            )
        }
    }

    private static func fetchMetNo(
        for place: WeatherPlace,
        retriesRemaining: Int,
        completion: @escaping (WeatherState?) -> Void
    ) {
        var components = URLComponents(
            string: "https://api.met.no/weatherapi/locationforecast/2.0/compact"
        )
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", place.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", place.longitude))
        ]
        guard let url = components?.url else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Szlauch/0.1 (app.szlauch.macos)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data,
                  let result = try? JSONDecoder().decode(MetNoResponse.self, from: data) else {
                guard retriesRemaining > 0 else {
                    completion(nil)
                    return
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.7) {
                    fetchMetNo(
                        for: place,
                        retriesRemaining: retriesRemaining - 1,
                        completion: completion
                    )
                }
                return
            }

            let now = Date().addingTimeInterval(-3600)
            let isoFormatter = ISO8601DateFormatter()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pl_PL")
            formatter.dateFormat = "HH:mm"
            let hours = result.properties.timeseries.compactMap { moment -> ForecastHour? in
                guard let date = isoFormatter.date(from: moment.time),
                      date >= now,
                      let period = moment.data.next_1_hours else {
                    return nil
                }
                return ForecastHour(
                    time: formatter.string(from: date),
                    date: date,
                    temperature: moment.data.instant.details.air_temperature,
                    precipitationProbability: nil,
                    precipitation: period.details?.precipitation_amount,
                    windSpeed: moment.data.instant.details.wind_speed * 3.6,
                    windGusts: moment.data.instant.details.wind_speed_of_gust.map { $0 * 3.6 },
                    weatherCode: metNoWeatherCode(
                        symbol: period.summary?.symbol_code,
                        cloudCoverage: moment.data.instant.details.cloud_area_fraction
                    )
                )
            }.prefix(24).map { $0 }
            guard let current = hours.first else {
                completion(nil)
                return
            }
            completion(
                WeatherState(
                    mode: .ready,
                    place: place,
                    temperature: current.temperature,
                    apparentTemperature: nil,
                    weatherCode: current.weatherCode,
                    windSpeed: current.windSpeed,
                    windGusts: current.windGusts,
                    precipitation: current.precipitation,
                    hours: hours,
                    outlook: outlook(for: hours, source: .metNo),
                    source: .metNo
                )
            )
        }.resume()
    }

    private static func metNoWeatherCode(symbol: String?, cloudCoverage: Double?) -> Int {
        let value = symbol ?? ""
        if value.contains("thunder") { return 95 }
        if value.contains("snow") || value.contains("sleet") { return 73 }
        if value.contains("rain") { return 61 }
        if value.contains("fog") { return 45 }
        if value.contains("cloudy") && !value.contains("partly") { return 3 }
        if value.contains("partlycloudy") || value.contains("fair") { return 2 }
        if value.contains("clearsky") { return 0 }
        if (cloudCoverage ?? 0) > 70 { return 3 }
        if (cloudCoverage ?? 0) > 20 { return 2 }
        return 0
    }

    static func rainNotice(for hours: [ForecastHour]) -> RainNotice? {
        let horizon = Array(hours.prefix(24))
        guard let firstPossible = horizon.first(where: hasPossibleRainEvidence) else {
            return nil
        }

        let firstExpected = horizon.first(where: hasExpectedRainEvidence)
        let alertHour = firstExpected ?? firstPossible
        let expected = firstExpected != nil
        let timing = timingText(for: alertHour)
        let compactText = expected
            ? "Deszcz \(timing)"
            : "Możliwy deszcz \(timing)"
        let relevantHours = horizon.filter(hasPossibleRainEvidence)
        let peakProbability = relevantHours.compactMap(\.precipitationProbability).max()
        let totalRain = relevantHours.compactMap(\.precipitation).reduce(0, +)
        let lastPossible = relevantHours.last ?? firstPossible
        let hourRange = firstPossible.time == lastPossible.time
            ? firstPossible.shortTime
            : "\(firstPossible.shortTime)-\(lastPossible.shortTime)"
        var details = ["\(expected ? "Opady" : "Możliwe opady") \(hourRange)"]
        if totalRain >= 0.1 {
            details.append(WeatherDisplay.rainfall(totalRain))
        }
        if let peakProbability {
            details.append("max \(peakProbability)%")
        }
        return RainNotice(
            compactText: compactText,
            detailText: details.joined(separator: " · ")
        )
    }

    private static func hasPossibleRainEvidence(_ hour: ForecastHour) -> Bool {
        hasExpectedRainEvidence(hour) || (hour.precipitationProbability ?? 0) >= 35
    }

    private static func hasExpectedRainEvidence(_ hour: ForecastHour) -> Bool {
        (hour.precipitation ?? 0) >= 0.1
            || (hour.precipitationProbability ?? 0) >= 60
            || rainCodes.contains(hour.weatherCode)
    }

    private static let rainCodes: Set<Int> = [
        51, 53, 55, 56, 57,
        61, 63, 65, 66, 67,
        80, 81, 82,
        95, 96, 99
    ]

    private static func timingText(for hour: ForecastHour) -> String {
        guard let date = hour.date else {
            return "od \(hour.shortTime)"
        }
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) {
            return "dziś od \(hour.shortTime)"
        }
        if calendar.isDateInTomorrow(date) {
            return "jutro od \(hour.shortTime)"
        }
        return "od \(hour.shortTime)"
    }

    static func outlook(for hours: [ForecastHour], source: WeatherSource) -> String {
        guard !hours.isEmpty else { return "Brak prognozy godzinowej." }
        if let notice = rainNotice(for: hours) {
            return notice.detailText
        }
        let low = hours.map(\.temperature).min() ?? 0
        let high = hours.map(\.temperature).max() ?? 0
        let wind = hours.map(\.windSpeed).max() ?? 0
        let rainText: String
        if source == .metNo {
            let precipitation = hours.compactMap(\.precipitation).max() ?? 0
            if precipitation >= 1 {
                rainText = "Opad do \(WeatherDisplay.rainfall(precipitation))"
            } else {
                rainText = "Bez istotnego opadu"
            }
        } else {
            let precipitation = hours.compactMap(\.precipitationProbability).max() ?? 0
            if precipitation >= 60 {
                rainText = "Deszcz do \(precipitation)%"
            } else if precipitation >= 30 {
                rainText = "Możliwy deszcz do \(precipitation)%"
            } else {
                rainText = "Raczej bez deszczu"
            }
        }
        let temperatureText =
            " · \(Int(low.rounded()))-\(Int(high.rounded()))°C"
        let windText = wind >= 30
            ? " · Wiatr do \(Int(wind.rounded())) km/h"
            : ""
        return rainText + temperatureText + windText
    }
}

private final class DeviceLocationProvider: NSObject, CLLocationManagerDelegate {
    var didLocate: ((CLLocation) -> Void)?
    var didFail: (() -> Void)?
    var didChangeAuthorization: ((Bool) -> Void)?
    private let manager = CLLocationManager()
    private var timeoutWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    var canRequestAuthorization: Bool {
        manager.authorizationStatus == .notDetermined
    }

    func requestAuthorization() {
        if canRequestAuthorization {
            manager.requestWhenInUseAuthorization()
        } else {
            didChangeAuthorization?(isAuthorized)
        }
    }

    func request() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            beginLocationRequest()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            finishWithFailure()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        didChangeAuthorization?(isAuthorized)
        if isAuthorized {
            beginLocationRequest()
        } else if manager.authorizationStatus != .notDetermined {
            finishWithFailure()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finishWithFailure()
            return
        }
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        didLocate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finishWithFailure()
    }

    private func beginLocationRequest() {
        scheduleTimeout()
        manager.requestLocation()
    }

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.finishWithFailure()
        }
        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: item)
    }

    private func finishWithFailure() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        didFail?()
    }
}

private final class PulseModel: ObservableObject {
    private static let displayWindowSamples = 5
    private static let chartWindowSamples = 30
    private static let detailedChartSampleSeconds: TimeInterval = 5

    @Published private(set) var network = NetworkState.initial
    @Published private(set) var wifi = WiFiState.initial
    @Published private(set) var wifiNetworks: [WiFiNetworkOption] = []
    @Published private(set) var wifiScanInProgress = false
    @Published private(set) var wifiNeedsLocationAccess = false
    @Published private(set) var wifiAwaitingLocationAccess = false
    @Published private(set) var wifiConnectingName: String?
    @Published private(set) var wifiConnectionError: String?
    @Published var wifiPasswordRequest: WiFiNetworkOption?
    @Published private(set) var personalHotspotName = PersonalHotspotStore.current()
    @Published private(set) var system = SystemState.initial
    @Published private(set) var connectionCost = ConnectionCost.loading
    @Published private(set) var trafficHistory = TrafficHistoryStore.current(persisting: RuntimeMode.recordsMeasurements)
    @Published private(set) var trafficRateHistory = TrafficRateHistoryStore.current(persisting: RuntimeMode.recordsMeasurements)
    @Published private(set) var rateUnit = RateDisplayUnit.current()
    @Published private(set) var weather: WeatherState
    @Published private(set) var weatherSource: WeatherSource
    @Published private(set) var airQuality: AirQualitySnapshot?
    @Published var weatherDetailsShown = false
    @Published var trafficDetailsShown = false
    @Published var wifiDetailsShown = false
    @Published var systemDetailsShown = false
    @Published var hotspotDetailsShown = false
    @Published var sleepPermissionPromptShown = false
    @Published private(set) var sleep = SleepState.loading
    @Published private(set) var vpn = VPNState.loading
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginNeedsApproval = false
    @Published var banner: MessageBanner?
    @Published private(set) var isWorking = false

    private var priorCounter: InterfaceCounter?
    private var priorCPUCounter: CPUCounter?
    private var priorCoreCounters: [CPUCounter]?
    private var recentRates: [(upload: Double, download: Double)] = []
    private var detailedRateStartedAt: Date?
    private var detailedRateDownloadBytes: UInt64 = 0
    private var detailedRateUploadBytes: UInt64 = 0
    private var timer: Timer?
    private var secondsSinceVPNRefresh = 0
    private var secondsSinceWeatherRefresh = 0
    private var secondsSinceProcessRefresh = 0
    private var secondsSinceWiFiRefresh = 0
    private var secondsSinceSystemRefresh = 0
    private var panelVisible = false
    private var wifiRefreshInProgress = false
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "app.szlauch.macos.path")
    private let locationProvider = DeviceLocationProvider()
    private var activeGeocodingRequest: AnyObject?
    private var weatherRevision = 0
    private var pendingLocationRevision: Int?
    private var wifiAuthorizationFallback: DispatchWorkItem?

    init() {
        let source = WeatherSourceStore.current()
        weatherSource = source
        weather = .loading(source: source)
    }

    static func navigationSelfTestFailures() -> [String] {
        var failures: [String] = []
        let trafficModel = PulseModel()
        trafficModel.trafficDetailsShown = true
        trafficModel.returnFromPassiveDetailTap()
        if trafficModel.trafficDetailsShown {
            failures.append("pasywne kliknięcie nie zamyka szczegółów transferu")
        }

        let systemModel = PulseModel()
        systemModel.systemDetailsShown = true
        systemModel.returnFromPassiveDetailTap()
        if systemModel.systemDetailsShown {
            failures.append("pasywne kliknięcie nie zamyka szczegółów systemu")
        }

        let weatherModel = PulseModel()
        weatherModel.weatherDetailsShown = true
        weatherModel.returnFromPassiveDetailTap()
        if !weatherModel.weatherDetailsShown {
            failures.append("pasywne kliknięcie nie może zamknąć pogody")
        }
        return failures
    }

    func start() {
        configureLocationProvider()
        monitorConnectionCost()
        refreshWiFi()
        sampleNetwork(refreshMetadata: true)
        if WeatherPlaceStore.deviceLocation() != nil || locationProvider.isAuthorized {
            useDeviceLocation()
        } else {
            weather = .needsLocation
        }
        refreshLaunchAtLogin()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sampleNetwork()
            self.secondsSinceWiFiRefresh += 1
            let wifiInterval = self.panelVisible ? 5 : 30
            if self.secondsSinceWiFiRefresh >= wifiInterval {
                self.secondsSinceWiFiRefresh = 0
                self.refreshWiFi()
            }
            if self.panelVisible {
                self.secondsSinceSystemRefresh += 1
                if self.secondsSinceSystemRefresh >= 2 {
                    self.secondsSinceSystemRefresh = 0
                    self.sampleSystem()
                }
            }
            if self.systemDetailsShown {
                self.secondsSinceProcessRefresh += 1
                if self.secondsSinceProcessRefresh >= 5 {
                    self.secondsSinceProcessRefresh = 0
                    self.refreshProcessDetails()
                }
            }
            if self.panelVisible {
                self.secondsSinceVPNRefresh += 1
                if self.secondsSinceVPNRefresh >= 5 {
                    self.secondsSinceVPNRefresh = 0
                    self.refreshVPN()
                }
            }
            self.secondsSinceWeatherRefresh += 1
            if self.secondsSinceWeatherRefresh >= 900 {
                self.secondsSinceWeatherRefresh = 0
                self.refreshWeather()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    deinit {
        timer?.invalidate()
        pathMonitor.cancel()
    }

    func panelDidOpen() {
        panelVisible = true
        secondsSinceWiFiRefresh = 0
        secondsSinceSystemRefresh = 0
        secondsSinceVPNRefresh = 0
        refreshWiFi()
        sampleNetwork(refreshMetadata: true)
        sampleSystem()
        refreshSleep()
        refreshVPN()
        refreshLaunchAtLogin()
    }

    func panelDidClose() {
        panelVisible = false
        secondsSinceProcessRefresh = 0
    }

    func toggleWeatherDetails() {
        weatherDetailsShown.toggle()
        if weatherDetailsShown {
            sleepPermissionPromptShown = false
            trafficDetailsShown = false
            wifiDetailsShown = false
            systemDetailsShown = false
            hotspotDetailsShown = false
        }
    }

    func toggleTrafficDetails() {
        trafficDetailsShown.toggle()
        if trafficDetailsShown {
            sleepPermissionPromptShown = false
            weatherDetailsShown = false
            wifiDetailsShown = false
            systemDetailsShown = false
            hotspotDetailsShown = false
        }
    }

    func toggleWiFiDetails() {
        wifiDetailsShown.toggle()
        if wifiDetailsShown {
            sleepPermissionPromptShown = false
            weatherDetailsShown = false
            trafficDetailsShown = false
            systemDetailsShown = false
            hotspotDetailsShown = false
            wifiPasswordRequest = nil
            wifiConnectionError = nil
            prepareWiFiNetworks()
        } else {
            wifiPasswordRequest = nil
            wifiConnectionError = nil
            wifiAwaitingLocationAccess = false
            wifiAuthorizationFallback?.cancel()
            wifiAuthorizationFallback = nil
        }
    }

    func toggleSystemDetails() {
        systemDetailsShown.toggle()
        if systemDetailsShown {
            sleepPermissionPromptShown = false
            weatherDetailsShown = false
            trafficDetailsShown = false
            wifiDetailsShown = false
            hotspotDetailsShown = false
            secondsSinceProcessRefresh = 0
            refreshProcessDetails()
        }
    }

    func toggleHotspotDetails() {
        hotspotDetailsShown.toggle()
        if hotspotDetailsShown {
            sleepPermissionPromptShown = false
            weatherDetailsShown = false
            trafficDetailsShown = false
            wifiDetailsShown = false
            systemDetailsShown = false
        }
    }

    func returnFromPassiveDetailTap() {
        guard !weatherDetailsShown,
              trafficDetailsShown || wifiDetailsShown || systemDetailsShown || hotspotDetailsShown else {
            return
        }
        trafficDetailsShown = false
        systemDetailsShown = false
        hotspotDetailsShown = false
        if wifiDetailsShown {
            wifiDetailsShown = false
            wifiPasswordRequest = nil
            wifiConnectionError = nil
            wifiAwaitingLocationAccess = false
            wifiAuthorizationFallback?.cancel()
            wifiAuthorizationFallback = nil
        }
    }

    func scanWiFiNetworks() {
        guard !wifiScanInProgress else { return }
        wifiScanInProgress = true
        wifiConnectionError = nil
        DispatchQueue.global(qos: .utility).async {
            let result: Result<WiFiScanResult, Error>
            do {
                result = .success(try WiFiProbe.networks())
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                self.wifiScanInProgress = false
                switch result {
                case .success(let scan):
                    self.wifiNetworks = scan.networks
                    self.wifiNeedsLocationAccess = scan.namesAreRestricted
                    if !scan.namesAreRestricted {
                        self.wifiAwaitingLocationAccess = false
                    }
                    if scan.namesAreRestricted,
                       self.wifiDetailsShown,
                       self.locationProvider.canRequestAuthorization {
                        self.wifiAwaitingLocationAccess = true
                        self.locationProvider.requestAuthorization()
                        self.scheduleWiFiAuthorizationFallback()
                    }
                case .failure:
                    self.wifiAwaitingLocationAccess = false
                    self.wifiConnectionError = "Nie udało się wyszukać sieci."
                }
            }
        }
    }

    private func prepareWiFiNetworks() {
        wifiNeedsLocationAccess = false
        if locationProvider.isAuthorized {
            scanWiFiNetworks()
        } else if locationProvider.canRequestAuthorization {
            wifiAwaitingLocationAccess = true
            locationProvider.requestAuthorization()
            scheduleWiFiAuthorizationFallback()
        } else {
            wifiNeedsLocationAccess = true
        }
    }

    func openWiFiLocationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openWiFiSettings() {
        WiFiSettingsDestination.open()
    }

    private func scheduleWiFiAuthorizationFallback() {
        wifiAuthorizationFallback?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.wifiDetailsShown,
                  self.wifiAwaitingLocationAccess,
                  !self.locationProvider.isAuthorized else {
                return
            }
            self.wifiAwaitingLocationAccess = false
            self.wifiNeedsLocationAccess = true
        }
        wifiAuthorizationFallback = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    func connectWiFi(_ option: WiFiNetworkOption, password: String? = nil) {
        guard wifiConnectingName == nil else { return }
        if wifi.connection == .connected,
           WiFiIdentity.matches(wifi.networkName, option.name) {
            wifiPasswordRequest = nil
            wifiConnectionError = nil
            return
        }
        wifiConnectingName = option.name
        wifiConnectionError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result: ActionResult
            if password == nil {
                let savedResult = WiFiProbe.connectSavedNetwork(named: option.name)
                if case .success = savedResult {
                    result = savedResult
                } else {
                    result = WiFiProbe.connect(to: option, password: nil)
                }
            } else {
                result = WiFiProbe.connect(to: option, password: password)
            }
            let currentWiFi = WiFiProbe.capture()
            DispatchQueue.main.async {
                self.wifiConnectingName = nil
                self.wifi = currentWiFi
                switch result {
                case .success:
                    self.wifiPasswordRequest = nil
                    self.wifiDetailsShown = false
                    self.refreshWiFi()
                    self.sampleNetwork(refreshMetadata: true)
                case .cancelled:
                    self.wifiPasswordRequest = nil
                case .failure(let text):
                    if currentWiFi.connection == .connected,
                       WiFiIdentity.matches(currentWiFi.networkName, option.name) {
                        self.wifiPasswordRequest = nil
                        self.wifiConnectionError = nil
                    } else if option.secured, password == nil {
                        self.wifiPasswordRequest = option
                    } else {
                        self.wifiConnectionError = text.isEmpty
                            ? "Nie udało się połączyć z siecią."
                            : text
                    }
                }
            }
        }
    }

    func setPersonalHotspotName(_ rawName: String) {
        personalHotspotName = PersonalHotspotStore.normalizedName(rawName)
        PersonalHotspotStore.set(personalHotspotName)
        wifiConnectionError = nil
    }

    func connectPersonalHotspot() {
        guard let hotspotName = personalHotspotName, wifiConnectingName == nil else { return }
        wifiConnectingName = hotspotName
        wifiPasswordRequest = nil
        wifiConnectionError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let savedConnection = WiFiProbe.connectSavedNetwork(named: hotspotName)
            if case .success = savedConnection {
                DispatchQueue.main.async {
                    self.completeWiFiConnection()
                }
                return
            }

            let option = try? WiFiProbe.networks(named: hotspotName, includeHidden: true)
                .networks
                .first(where: { $0.name == hotspotName })

            DispatchQueue.main.async {
                self.wifiConnectingName = nil
                if let option {
                    self.connectWiFi(option)
                } else {
                    self.wifiConnectionError =
                        "Telefon nie udostępnia teraz hotspotu. Włącz Hotspot osobisty na telefonie i spróbuj ponownie."
                }
            }
        }
    }

    private func completeWiFiConnection() {
        wifiConnectingName = nil
        wifiPasswordRequest = nil
        wifiDetailsShown = false
        refreshWiFi()
        sampleNetwork(refreshMetadata: true)
    }

    func refreshSleep() {
        if CommandLine.arguments.contains("--preview-sleep-unconfigured") {
            sleep = SleepState(mode: .disabled, configured: false)
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let state = SleepService.readState()
            DispatchQueue.main.async {
                self.sleep = state
            }
        }
    }

    func toggleSleep() {
        guard !isWorking, sleep.configured else { return }
        let newValue = !sleep.mode.isPreventingSleep
        isWorking = true
        banner = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SleepService.setPrevention(newValue)
            let current = SleepService.readState()
            DispatchQueue.main.async {
                self.sleep = current
                self.isWorking = false
                switch result {
                case .success:
                    self.banner = nil
                case .cancelled:
                    self.banner = nil
                case .failure(let text):
                    self.banner = MessageBanner(kind: .error, text: text)
                }
            }
        }
    }

    func requestSleepConfiguration() {
        guard !isWorking else { return }
        banner = nil
        sleepPermissionPromptShown = true
    }

    func cancelSleepConfiguration() {
        banner = nil
        sleepPermissionPromptShown = false
    }

    func confirmSleepConfiguration() {
        sleepPermissionPromptShown = false
        configureSleep()
    }

    private func configureSleep() {
        guard !isWorking else { return }
        isWorking = true
        banner = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SleepService.installPermission()
            let current = SleepService.readState()
            DispatchQueue.main.async {
                self.sleep = current
                self.isWorking = false
                switch result {
                case .success:
                    self.banner = nil
                case .cancelled:
                    self.banner = nil
                case .failure(let text):
                    self.banner = MessageBanner(kind: .error, text: text)
                }
            }
        }
    }

    func removeSleepConfiguration() {
        guard !isWorking, sleep.configured else { return }
        isWorking = true
        banner = nil
        sleepPermissionPromptShown = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SleepService.removePermission()
            let current = SleepService.readState()
            DispatchQueue.main.async {
                self.sleep = current
                self.isWorking = false
                switch result {
                case .success, .cancelled:
                    self.banner = nil
                case .failure(let text):
                    self.banner = MessageBanner(kind: .error, text: text)
                }
            }
        }
    }

    func refreshVPN() {
        DispatchQueue.global(qos: .utility).async {
            let state = VPNService.readState()
            DispatchQueue.main.async {
                self.vpn = state
            }
        }
    }

    func toggleVPN() {
        guard !isWorking, vpn.mode.isToggleable else { return }
        let newValue = !vpn.mode.isActive
        let serviceID = vpn.serviceID
        isWorking = true
        banner = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = VPNService.setConnected(newValue, serviceID: serviceID)
            let current = VPNService.readState()
            DispatchQueue.main.async {
                self.vpn = current
                self.isWorking = false
                switch result {
                case .success:
                    self.banner = nil
                case .cancelled:
                    self.banner = nil
                case .failure(let text):
                    self.banner = MessageBanner(kind: .error, text: text)
                }
            }
        }
    }

    func resetHotspotHistory() {
        trafficHistory = TrafficHistoryStore.clearHotspot(in: trafficHistory)
    }

    func setRateUnit(_ unit: RateDisplayUnit) {
        guard rateUnit != unit else { return }
        rateUnit = unit
        UserDefaults.standard.set(unit.rawValue, forKey: RateDisplayUnit.storageKey)
    }

    func useDeviceLocation() {
        let revision = beginWeatherIntent(needsLocation: true)
        if let devicePlace = WeatherPlaceStore.deviceLocation() {
            weather = .loading(source: weatherSource, place: devicePlace)
            fetchWeather(for: devicePlace, revision: revision)
        } else {
            weather = .loading(source: weatherSource)
        }
        locationProvider.request()
    }

    func searchWeather(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            useDeviceLocation()
            return
        }
        let revision = beginWeatherIntent()
        weather = .loading(source: weatherSource)
        WeatherService.findPlace(named: text) { [weak self] place in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.weatherRevision == revision else { return }
                guard let place else {
                    self.weather = WeatherState(
                        mode: .notFound,
                        place: nil,
                        temperature: nil,
                        apparentTemperature: nil,
                        weatherCode: nil,
                        windSpeed: nil,
                        windGusts: nil,
                        precipitation: nil,
                        hours: [],
                        outlook: "Nie znalazłem tej miejscowości",
                        source: self.weatherSource
                    )
                    return
                }
                self.fetchWeather(for: place, revision: revision)
            }
        }
    }

    func refreshWeather() {
        if weather.place?.usesDeviceLocation == true {
            useDeviceLocation()
        } else if let place = weather.place {
            let revision = beginWeatherIntent()
            fetchWeather(for: place, revision: revision)
        } else {
            useDeviceLocation()
        }
    }

    func selectWeatherSource(_ source: WeatherSource) {
        weatherSource = source
        WeatherSourceStore.set(source)
        refreshWeather()
    }

    func openWeatherApp() {
        let url = URL(fileURLWithPath: "/System/Applications/Weather.app")
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        loginNeedsApproval = status == .requiresApproval
    }

    func toggleLaunchAtLogin() {
        banner = nil
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                guard !isRunningFromReadOnlyVolume else {
                    banner = MessageBanner(
                        kind: .error,
                        text: "Najpierw przenieś Szlauch do Applications."
                    )
                    return
                }
                try SMAppService.mainApp.register()
            }
            refreshLaunchAtLogin()
        } catch {
            banner = MessageBanner(kind: .error, text: "Nie udało się zmienić startu przy logowaniu.")
            refreshLaunchAtLogin()
        }
    }

    private var isRunningFromReadOnlyVolume: Bool {
        let values = try? Bundle.main.bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey])
        return values?.volumeIsReadOnly == true
    }

    private func sampleNetwork(refreshMetadata: Bool = false) {
        guard let counter = NetworkProbe.capture(
            reusing: priorCounter,
            refreshMetadata: refreshMetadata
        ) else {
            network = NetworkState(
                interfaceName: "—",
                monitoredInterfaces: [],
                displayName: "Brak połączenia",
                address: "—",
                upload: 0,
                download: 0,
                instantUpload: 0,
                instantDownload: 0,
                uploadHistory: [],
                downloadHistory: [],
                isConnected: false
            )
            priorCounter = nil
            recentRates.removeAll()
            resetDetailedRateSample()
            return
        }

        var upload = 0.0
        var download = 0.0
        var uploadBytes: UInt64 = 0
        var downloadBytes: UInt64 = 0
        var routeTotals: [TrafficRoute: TrafficTotals] = [:]
        if let prior = priorCounter {
            let seconds = max(counter.timestamp.timeIntervalSince(prior.timestamp), 0.1)
            for (interfaceName, current) in counter.monitoredCounters {
                guard let previous = prior.monitoredCounters[interfaceName] else { continue }
                let route = trafficRoute(for: interfaceName, primaryInterface: counter.name)
                let interfaceDownload = counterDelta(current.incomingBytes, after: previous.incomingBytes)
                let interfaceUpload = counterDelta(current.outgoingBytes, after: previous.outgoingBytes)
                routeTotals[route, default: TrafficTotals()].add(
                    download: interfaceDownload,
                    upload: interfaceUpload
                )
                downloadBytes += interfaceDownload
                uploadBytes += interfaceUpload
            }
            download = Double(downloadBytes) / seconds
            upload = Double(uploadBytes) / seconds
        }
        priorCounter = counter
        if RuntimeMode.recordsMeasurements {
            for route in [TrafficRoute.wifi, .hotspot, .other] {
                guard let totals = routeTotals[route], totals.total > 0 else { continue }
                trafficHistory = TrafficHistoryStore.record(
                    download: totals.download,
                    upload: totals.upload,
                    route: route,
                    in: trafficHistory
                )
            }
            recordDetailedRateSample(
                downloadBytes: downloadBytes,
                uploadBytes: uploadBytes,
                timestamp: counter.timestamp
            )
        }

        recentRates.append((upload: upload, download: download))
        if recentRates.count > Self.chartWindowSamples {
            recentRates.removeFirst(recentRates.count - Self.chartWindowSamples)
        }
        let displayRates = recentRates.suffix(Self.displayWindowSamples)
        let displayCount = Double(max(displayRates.count, 1))
        let displayUpload = displayRates.map(\.upload).reduce(0, +) / displayCount
        let displayDownload = displayRates.map(\.download).reduce(0, +) / displayCount
        network = NetworkState(
            interfaceName: counter.name,
            monitoredInterfaces: counter.monitoredCounters.keys.sorted(),
            displayName: counter.displayName,
            address: counter.address,
            upload: displayUpload,
            download: displayDownload,
            instantUpload: upload,
            instantDownload: download,
            uploadHistory: recentRates.map(\.upload),
            downloadHistory: recentRates.map(\.download),
            isConnected: true
        )
    }

    private func recordDetailedRateSample(
        downloadBytes: UInt64,
        uploadBytes: UInt64,
        timestamp: Date
    ) {
        if detailedRateStartedAt == nil {
            detailedRateStartedAt = timestamp
        }
        detailedRateDownloadBytes += downloadBytes
        detailedRateUploadBytes += uploadBytes
        guard let startedAt = detailedRateStartedAt else { return }
        let elapsed = timestamp.timeIntervalSince(startedAt)
        guard elapsed >= Self.detailedChartSampleSeconds else { return }
        trafficRateHistory = TrafficRateHistoryStore.record(
            download: Double(detailedRateDownloadBytes) / elapsed,
            upload: Double(detailedRateUploadBytes) / elapsed,
            in: trafficRateHistory,
            now: timestamp
        )
        detailedRateStartedAt = timestamp
        detailedRateDownloadBytes = 0
        detailedRateUploadBytes = 0
    }

    private func resetDetailedRateSample() {
        detailedRateStartedAt = nil
        detailedRateDownloadBytes = 0
        detailedRateUploadBytes = 0
    }

    private func refreshWiFi() {
        guard !wifiRefreshInProgress else { return }
        wifiRefreshInProgress = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let state = WiFiProbe.capture()
            DispatchQueue.main.async {
                guard let self else { return }
                self.wifi = state
                if let requestedNetwork = self.wifiPasswordRequest,
                   state.connection == .connected,
                   WiFiIdentity.matches(state.networkName, requestedNetwork.name) {
                    self.wifiPasswordRequest = nil
                    self.wifiConnectionError = nil
                }
                self.wifiRefreshInProgress = false
                self.rememberMeteredWiFiIfNeeded()
            }
        }
    }

    private func rememberMeteredWiFiIfNeeded() {
        guard personalHotspotName == nil,
              connectionCost.isMetered,
              wifi.connection == .connected,
              let networkName = wifi.networkName,
              !networkName.isEmpty else {
            return
        }
        personalHotspotName = networkName
        PersonalHotspotStore.set(networkName)
    }

    var activeTrafficRoute: TrafficRoute {
        if connectionCost.isMetered {
            return .hotspot
        }
        if wifi.connection == .connected, wifi.interfaceName == network.interfaceName {
            return .wifi
        }
        return .other
    }

    private func trafficRoute(for interfaceName: String, primaryInterface: String) -> TrafficRoute {
        if connectionCost.isMetered, interfaceName == primaryInterface {
            return .hotspot
        }
        if wifi.connection == .connected, wifi.interfaceName == interfaceName {
            return .wifi
        }
        return .other
    }

    private func sampleSystem() {
        if let counters = SystemProbe.cpuCounter() {
            var cpuUsage = system.cpuUsage
            if let prior = priorCPUCounter, counters.total > prior.total {
                let activeDelta = counters.active - prior.active
                let totalDelta = counters.total - prior.total
                cpuUsage = Double(activeDelta) / Double(totalDelta)
            }
            priorCPUCounter = counters
            var coreUsages = system.coreUsages
            if let coreCounters = SystemProbe.coreCounters() {
                if let previous = priorCoreCounters, previous.count == coreCounters.count {
                    coreUsages = zip(previous, coreCounters).map { prior, current in
                        guard current.total > prior.total else { return 0 }
                        return Double(current.active - prior.active)
                            / Double(current.total - prior.total)
                    }
                }
                priorCoreCounters = coreCounters
            }
            if let memory = SystemProbe.memory() {
                system = SystemState(
                    cpuUsage: cpuUsage,
                    memoryUsed: memory.used,
                    memoryTotal: memory.total,
                    coreUsages: coreUsages,
                    cpuProcesses: system.cpuProcesses,
                    memoryProcesses: system.memoryProcesses
                )
            }
        }
    }

    private func refreshProcessDetails() {
        DispatchQueue.global(qos: .utility).async {
            let applications = SystemProbe.applicationUsage()
            DispatchQueue.main.async {
                guard self.systemDetailsShown else { return }
                self.system = SystemState(
                    cpuUsage: self.system.cpuUsage,
                    memoryUsed: self.system.memoryUsed,
                    memoryTotal: self.system.memoryTotal,
                    coreUsages: self.system.coreUsages,
                    cpuProcesses: applications.cpu,
                    memoryProcesses: applications.memory
                )
            }
        }
    }

    private func monitorConnectionCost() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let cost: ConnectionCost
            if path.status != .satisfied {
                cost = .offline
            } else if path.isExpensive {
                cost = .metered
            } else {
                cost = .standard
            }
            DispatchQueue.main.async {
                self?.connectionCost = cost
                self?.rememberMeteredWiFiIfNeeded()
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    func prepareForTermination() {
        if RuntimeMode.recordsMeasurements {
            TrafficHistoryStore.persist(trafficHistory)
        }
    }

    private func configureLocationProvider() {
        locationProvider.didChangeAuthorization = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.wifiDetailsShown else { return }
                self.wifiAuthorizationFallback?.cancel()
                self.wifiAuthorizationFallback = nil
                self.wifiAwaitingLocationAccess = false
                if self.locationProvider.isAuthorized {
                    self.wifiNeedsLocationAccess = false
                    self.scanWiFiNetworks()
                } else if !self.locationProvider.canRequestAuthorization {
                    self.wifiNeedsLocationAccess = true
                }
            }
        }
        locationProvider.didLocate = { [weak self] location in
            guard let self else { return }
            guard let pendingRevision = self.pendingLocationRevision,
                  pendingRevision == self.weatherRevision else {
                return
            }
            let previousName = WeatherPlaceStore.deviceLocation()?.name ?? "Moja lokalizacja"
            let revision = self.beginWeatherIntent()
            let provisionalPlace = WeatherPlace(
                name: previousName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                usesDeviceLocation: true
            )
            if self.weather.mode != .ready {
                self.weather = .loading(source: self.weatherSource, place: provisionalPlace)
            }
            self.fetchWeather(for: provisionalPlace, revision: revision)
            self.resolveLocationName(location) { name in
                DispatchQueue.main.async {
                    guard revision == self.weatherRevision else { return }
                    let place = WeatherPlace(
                        name: name,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        usesDeviceLocation: true
                    )
                    WeatherPlaceStore.setDeviceLocation(place)
                    if self.weather.place?.usesDeviceLocation == true {
                        self.weather = self.weather.replacingPlace(place)
                    }
                    if self.wifiDetailsShown {
                        self.scanWiFiNetworks()
                    }
                }
            }
        }
        locationProvider.didFail = { [weak self] in
            DispatchQueue.main.async {
                guard let self,
                      let revision = self.pendingLocationRevision,
                      revision == self.weatherRevision else {
                    return
                }
                self.pendingLocationRevision = nil
                if self.weather.place?.usesDeviceLocation != true {
                    self.weather = .locationFailure(source: self.weatherSource)
                }
            }
        }
    }

    private func resolveLocationName(
        _ location: CLLocation,
        completion: @escaping (String) -> Void
    ) {
        if #available(macOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                completion("Moja lokalizacja")
                return
            }
            request.preferredLocale = Locale(identifier: "pl_PL")
            activeGeocodingRequest = request
            request.getMapItems { [weak self] mapItems, _ in
                self?.activeGeocodingRequest = nil
                completion(mapItems?.first?.addressRepresentations?.cityName ?? "Moja lokalizacja")
            }
        } else {
            resolveLegacyLocationName(location, completion: completion)
        }
    }

    @available(macOS, introduced: 10.8, deprecated: 26.0)
    private func resolveLegacyLocationName(
        _ location: CLLocation,
        completion: @escaping (String) -> Void
    ) {
        let geocoder = CLGeocoder()
        activeGeocodingRequest = geocoder
        geocoder.reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "pl_PL")
        ) { [weak self] placemarks, _ in
            self?.activeGeocodingRequest = nil
            let placemark = placemarks?.first
            completion(
                placemark?.locality
                    ?? placemark?.subAdministrativeArea
                    ?? placemark?.administrativeArea
                    ?? "Moja lokalizacja"
            )
        }
    }

    private func beginWeatherIntent(needsLocation: Bool = false) -> Int {
        weatherRevision += 1
        pendingLocationRevision = needsLocation ? weatherRevision : nil
        airQuality = nil
        return weatherRevision
    }

    private func fetchWeather(for place: WeatherPlace, revision: Int) {
        let source = weatherSource
        WeatherService.fetch(
            for: place,
            source: source
        ) { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                guard revision == self.weatherRevision else { return }
                if let state {
                    self.weather = state
                    self.fetchAirQuality(for: place, revision: revision)
                    return
                }
                let fallbackSource: WeatherSource = source == .openMeteo ? .metNo : .openMeteo
                self.fetchWeatherFallback(
                    for: place,
                    failedSource: source,
                    fallbackSource: fallbackSource,
                    revision: revision
                )
            }
        }
    }

    private func fetchWeatherFallback(
        for place: WeatherPlace,
        failedSource: WeatherSource,
        fallbackSource: WeatherSource,
        revision: Int
    ) {
        WeatherService.fetch(for: place, source: fallbackSource) { [weak self] state in
            DispatchQueue.main.async {
                guard let self, revision == self.weatherRevision else { return }
                guard var state else {
                    self.setWeatherFailure(for: place, source: failedSource)
                    return
                }
                state.fallbackFrom = failedSource
                self.weather = state
                self.fetchAirQuality(for: place, revision: revision)
            }
        }
    }

    private func fetchAirQuality(for place: WeatherPlace, revision: Int) {
        WeatherService.fetchAirQuality(for: place) { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self, revision == self.weatherRevision else { return }
                self.airQuality = snapshot
            }
        }
    }

    private func setWeatherFailure(for place: WeatherPlace, source: WeatherSource) {
        weather = WeatherState(
            mode: .failure,
            place: place,
            temperature: nil,
            apparentTemperature: nil,
            weatherCode: nil,
            windSpeed: nil,
            windGusts: nil,
            precipitation: nil,
            hours: [],
            outlook: "Nie udało się pobrać prognozy z \(source.label).",
            source: source
        )
    }

}

private func counterDelta(_ current: UInt32, after previous: UInt32) -> UInt64 {
    // getifaddrs exposes 32-bit byte counters on macOS; preserve traffic across rollover.
    if current >= previous {
        return UInt64(current - previous)
    }
    return UInt64(UInt32.max - previous) + UInt64(current) + 1
}

private enum PanelMotion {
    static let navigation = Animation.timingCurve(0.22, 0.86, 0.24, 1.0, duration: 0.22)
    static let selection = Animation.easeOut(duration: 0.16)

    // Mode switches should dissolve calmly; the popover itself stays still.
    static let surfaceTransition = AnyTransition.opacity
}

private enum PanelLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 420
    static let detailViewportHeight: CGFloat = height - 45
    static let popoverSize = NSSize(width: width, height: height)
}

private struct SzlauchPanel: View {
    private enum AppearanceDragAxis {
        case colorIntensity
        case windowOpacity
    }

    @ObservedObject var model: PulseModel
    @AppStorage(PulseTheme.storageKey) private var selectedTheme = PulseTheme.sliwka.storedValue
    @AppStorage(PulseTheme.intensityStorageKey) private var selectedIntensity = PulseTheme.defaultIntensity
    @AppStorage(PulseTheme.opacityStorageKey) private var selectedOpacity = PulseTheme.defaultOpacity
    @State private var intensityDragOrigin: Double?
    @State private var opacityDragOrigin: Double?
    @State private var appearanceDragAxis: AppearanceDragAxis?

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                mainPanel
            }
            .environment(\.pulseTheme, theme)
            .environment(\.colorScheme, .dark)
            .background(PanelBackdrop(theme: theme))
            .background(WindowOpacityController(opacity: selectedOpacity).frame(width: 0, height: 0))
            .id(selectedTheme)
        } else {
            mainPanel
                .environment(\.pulseTheme, theme)
                .environment(\.colorScheme, .dark)
                .background(PanelBackdrop(theme: theme))
                .background(WindowOpacityController(opacity: selectedOpacity).frame(width: 0, height: 0))
                .id(selectedTheme)
        }
    }

    private var showsCompactDashboard: Bool {
        !model.weatherDetailsShown
            && !model.trafficDetailsShown
            && !model.wifiDetailsShown
            && !model.systemDetailsShown
            && !model.hotspotDetailsShown
            && !model.sleepPermissionPromptShown
            && model.banner == nil
    }

    private var mainPanel: some View {
        ZStack(alignment: .top) {
            if showsCompactDashboard {
                compactDashboard
                    .transition(PanelMotion.surfaceTransition)
            } else {
                detailPanel
                    .transition(PanelMotion.surfaceTransition)
            }
        }
        .animation(PanelMotion.navigation, value: showsCompactDashboard)
        .frame(width: PanelLayout.width, height: PanelLayout.height, alignment: .top)
        .clipped()
    }

    private var compactDashboard: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 4)
            WeatherSummary(model: model)
            InstrumentDivider()
            compactDashboardNetworkSection
            InstrumentDivider()
            compactDashboardSystemSection
            InstrumentDivider()
            compactControlsContent
            Spacer(minLength: 0)
        }
        .frame(height: PanelLayout.height - 14)
        .instrumentGlass(radius: 18)
        .padding(7)
        .frame(width: PanelLayout.width, height: PanelLayout.height)
        .tint(theme.cta)
    }

    private var detailPanel: some View {
        VStack(spacing: 6) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    if model.weatherDetailsShown {
                        WeatherSummary(model: model)
                            .pulseGlass(tone: .light)
                            .transition(PanelMotion.surfaceTransition)
                    } else {
                        if model.systemDetailsShown {
                            compactTransferShortcut
                                .pulseGlass(tone: .main)
                                .transition(PanelMotion.surfaceTransition)
                        } else {
                            networkSection
                                .pulseGlass(tone: .main)
                                .transition(PanelMotion.surfaceTransition)
                        }
                        if !model.trafficDetailsShown && !model.wifiDetailsShown {
                            if model.sleepPermissionPromptShown && !model.systemDetailsShown {
                                SleepPermissionPrompt(model: model)
                                    .pulseGlass(tone: .light)
                                    .transition(PanelMotion.surfaceTransition)
                            } else {
                                compactSystemSection
                                    .pulseGlass(tone: .main)
                                    .transition(PanelMotion.surfaceTransition)
                            }
                            if !model.systemDetailsShown && !model.hotspotDetailsShown {
                                compactControls
                                    .transition(PanelMotion.surfaceTransition)

                                if let banner = model.banner {
                                    BannerView(banner: banner)
                                        .pulseGlass(radius: 12, tone: .light)
                                        .transition(PanelMotion.surfaceTransition)
                                }
                            }
                        } else if model.trafficDetailsShown {
                            compactSystemShortcut
                                .pulseGlass(tone: .main)
                                .transition(PanelMotion.surfaceTransition)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: PanelLayout.detailViewportHeight, alignment: .top)
            .clipped()
        }
        .padding(7)
        .frame(width: PanelLayout.width, height: PanelLayout.height, alignment: .top)
        .tint(theme.cta)
        .animation(PanelMotion.navigation, value: model.weatherDetailsShown)
        .animation(PanelMotion.navigation, value: model.trafficDetailsShown)
        .animation(PanelMotion.navigation, value: model.wifiDetailsShown)
        .animation(PanelMotion.navigation, value: model.systemDetailsShown)
        .animation(PanelMotion.navigation, value: model.hotspotDetailsShown)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(PanelMotion.navigation) {
                model.returnFromPassiveDetailTap()
            }
        }
    }

    private var header: some View {
        HStack {
            Label("Szlauch", systemImage: "waveform.path.ecg")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .contentShape(Rectangle())
                .gesture(appearanceGesture)
                .help("Paleta: \(theme.variant.label). Kliknij: następna paleta. Przeciągnij: lewo/prawo kolor, góra/dół przezroczystość.")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    cycleTheme()
                }
            Spacer()
            Text("ODCZYT CO 1 S")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Palette.muted)
            Menu {
                Toggle(
                    "Start przy logowaniu",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { _ in model.toggleLaunchAtLogin() }
                    )
                )
                Divider()
                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    Label("Zakończ Szlauch", systemImage: "power")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 19, height: 19)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Opcje Szlaucha")
            .accessibilityLabel("Opcje Szlaucha")
        }
        .padding(.horizontal, 9)
        .frame(height: 25)
    }

    private var theme: PulseTheme {
        PulseTheme(storedValue: selectedTheme, intensity: selectedIntensity)
            ?? .sliwka.withIntensity(selectedIntensity)
    }

    private var appearanceGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if intensityDragOrigin == nil {
                    intensityDragOrigin = theme.intensity
                    opacityDragOrigin = PulseTheme.clampedOpacity(selectedOpacity)
                }
                let translation = value.translation
                if appearanceDragAxis == nil {
                    let horizontal = abs(translation.width)
                    let vertical = abs(translation.height)
                    guard max(horizontal, vertical) > 5 else { return }
                    appearanceDragAxis = horizontal > vertical ? .colorIntensity : .windowOpacity
                }
                switch appearanceDragAxis {
                case .colorIntensity:
                    let origin = intensityDragOrigin ?? PulseTheme.defaultIntensity
                    selectedIntensity = PulseTheme.clampedIntensity(
                        origin + Double(translation.width / 150)
                    )
                case .windowOpacity:
                    let origin = opacityDragOrigin ?? PulseTheme.defaultOpacity
                    selectedOpacity = PulseTheme.clampedOpacity(
                        origin - Double(translation.height / 180)
                    )
                case .none:
                    break
                }
            }
            .onEnded { value in
                let translation = value.translation
                let moved = hypot(translation.width, translation.height) > 5
                let adjusted = appearanceDragAxis != nil
                intensityDragOrigin = nil
                opacityDragOrigin = nil
                appearanceDragAxis = nil
                if !moved && !adjusted {
                    cycleTheme()
                }
            }
    }

    private func cycleTheme() {
        withAnimation(PanelMotion.navigation) {
            selectedTheme = theme.cycled().storedValue
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.openWiFiSettings()
                } label: {
                    Image(systemName: model.wifi.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(model.wifi.isWeak ? Palette.warning : Palette.strong)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Otwórz ustawienia Wi-Fi")
                .accessibilityLabel("Otwórz ustawienia Wi-Fi")
                Text("Wi-Fi")
                    .font(.system(size: 13).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text(wifiSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                Spacer()
                Button {
                    withAnimation(PanelMotion.navigation) {
                        model.toggleWiFiDetails()
                    }
                } label: {
                    InlineNavigationLabel(
                        title: model.wifiDetailsShown ? "WRÓĆ" : "SIECI",
                        backwards: model.wifiDetailsShown
                    )
                }
                .buttonStyle(InlineActionButtonStyle())
            }

            if model.wifiDetailsShown {
                WiFiNetworkPicker(model: model)
            } else {
                HStack {
                    Text("TRANSFER · CAŁY MAC")
                        .font(.system(size: 8.5).weight(.bold))
                        .tracking(0.55)
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Text(transferSourceSubtitle)
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }

                if model.trafficDetailsShown {
                    detailTransferReadouts
                } else {
                    Button {
                        withAnimation(PanelMotion.navigation) {
                            model.toggleTrafficDetails()
                        }
                    } label: {
                        detailTransferReadouts
                    }
                    .buttonStyle(.plain)
                    .help("Pokaż historię transferu")
                    .accessibilityLabel(
                        "Transfer całego Maca. Pobieranie \(RateFormatter.detailed(model.network.instantDownload, unit: model.rateUnit)), wysyłanie \(RateFormatter.detailed(model.network.instantUpload, unit: model.rateUnit))."
                    )
                }

                if model.trafficDetailsShown {
                    TrafficDetails(model: model)
                        .transition(PanelMotion.surfaceTransition)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var detailTransferReadouts: some View {
        HStack(spacing: 8) {
            CompactRateReadout(
                label: "DOWNLOAD",
                symbol: "arrow.down",
                value: RateFormatter.detailed(model.network.instantDownload, unit: model.rateUnit),
                color: Palette.inbound
            )
            Rectangle()
                .fill(Palette.line)
                .frame(width: 1, height: 35)
            CompactRateReadout(
                label: "UPLOAD",
                symbol: "arrow.up",
                value: RateFormatter.detailed(model.network.instantUpload, unit: model.rateUnit),
                color: Palette.outbound
            )
        }
    }

    private var compactDashboardNetworkSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Button {
                    model.openWiFiSettings()
                } label: {
                    Image(systemName: model.wifi.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(model.wifi.isWeak ? Palette.warning : Palette.strong)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Otwórz ustawienia Wi-Fi")
                .accessibilityLabel("Otwórz ustawienia Wi-Fi")
                Text("Wi-Fi")
                    .font(.system(size: 13).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text(wifiSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                Spacer()
                Button {
                    withAnimation(PanelMotion.navigation) {
                        model.toggleWiFiDetails()
                    }
                } label: {
                    InlineNavigationLabel(title: "SIECI")
                }
                .buttonStyle(InlineActionButtonStyle())
            }

            HStack {
                Text("TRANSFER · CAŁY MAC")
                    .font(.system(size: 8.5).weight(.bold))
                    .tracking(0.75)
                    .foregroundStyle(Palette.strong)
                Spacer()
                Text(transferSourceSubtitle)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }

            Button {
                withAnimation(PanelMotion.navigation) {
                    model.toggleTrafficDetails()
                }
            } label: {
                CompactTransferHero(
                    downloadValue: RateFormatter.detailed(model.network.instantDownload, unit: model.rateUnit),
                    uploadValue: RateFormatter.detailed(model.network.instantUpload, unit: model.rateUnit),
                    downloadSamples: model.network.downloadHistory,
                    uploadSamples: model.network.uploadHistory
                )
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .help("Pokaż historię transferu")
            .accessibilityLabel(
                "Transfer całego Maca. Pobieranie \(RateFormatter.detailed(model.network.instantDownload, unit: model.rateUnit)), wysyłanie \(RateFormatter.detailed(model.network.instantUpload, unit: model.rateUnit))."
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var wifiSubtitle: String {
        switch model.wifi.connection {
        case .loading: return "sprawdzam"
        case .unavailable: return "niedostępne"
        case .poweredOff: return "wyłączone"
        case .disconnected: return "niepołączone"
        case .connected: return model.wifi.networkName ?? "połączono"
        }
    }

    private var transferSourceSubtitle: String {
        guard !model.network.monitoredInterfaces.isEmpty else { return "brak łącza" }
        return model.network.monitoredInterfaces.joined(separator: " + ")
    }

    private var memoryUsage: Double {
        guard model.system.memoryTotal > 0 else { return 0 }
        return Double(model.system.memoryUsed) / Double(model.system.memoryTotal)
    }

    private var compactSystemSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(PanelMotion.navigation) {
                    model.toggleSystemDetails()
                }
            } label: {
                HStack(spacing: 8) {
                    CompactMetric(
                        title: "CPU",
                        value: MetricFormatter.percent(model.system.cpuUsage),
                        progress: model.system.cpuUsage
                    )
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 1, height: 28)
                    CompactMetric(
                        title: "RAM",
                        value: MetricFormatter.percent(
                            model.system.memoryTotal == 0
                                ? 0
                                : Double(model.system.memoryUsed) / Double(model.system.memoryTotal)
                        ),
                        progress: model.system.memoryTotal == 0
                            ? 0
                            : Double(model.system.memoryUsed) / Double(model.system.memoryTotal)
                    )
                }
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .help(model.systemDetailsShown ? "Ukryj szczegóły systemu" : "Pokaż szczegóły systemu")

            if model.systemDetailsShown {
                SystemDetails(model: model)
                    .transition(PanelMotion.surfaceTransition)
            } else {
                CompactHotspotRow(
                    history: model.trafficHistory,
                    connectionCost: model.connectionCost,
                    expanded: model.hotspotDetailsShown,
                    onToggle: model.toggleHotspotDetails,
                    onReset: model.resetHotspotHistory
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var compactDashboardSystemSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(PanelMotion.navigation) {
                    model.toggleSystemDetails()
                }
            } label: {
                HStack(spacing: 8) {
                    CompactMetric(
                        title: "CPU",
                        value: MetricFormatter.percent(model.system.cpuUsage),
                        progress: model.system.cpuUsage,
                        color: Palette.inbound
                    )
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 1, height: 28)
                    CompactMetric(
                        title: "RAM",
                        value: MetricFormatter.percent(
                            model.system.memoryTotal == 0
                                ? 0
                                : Double(model.system.memoryUsed) / Double(model.system.memoryTotal)
                        ),
                        progress: model.system.memoryTotal == 0
                            ? 0
                            : Double(model.system.memoryUsed) / Double(model.system.memoryTotal),
                        color: Palette.inbound
                    )
                }
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .help("Pokaż szczegóły systemu")

            CompactHotspotRow(
                history: model.trafficHistory,
                connectionCost: model.connectionCost,
                expanded: false,
                onToggle: model.toggleHotspotDetails,
                onReset: model.resetHotspotHistory
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var compactTransferShortcut: some View {
        Button {
            withAnimation(PanelMotion.navigation) {
                model.toggleTrafficDetails()
            }
        } label: {
            HStack(spacing: 9) {
                Text("TRANSFER")
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.65)
                    .foregroundStyle(Palette.muted)
                Text("↓ \(RateFormatter.detailed(model.network.instantDownload, unit: model.rateUnit))")
                    .foregroundStyle(Palette.inbound)
                Text("↑ \(RateFormatter.detailed(model.network.instantUpload, unit: model.rateUnit))")
                    .foregroundStyle(Palette.outbound)
                Spacer(minLength: 0)
                InlineNavigationLabel(title: "WYKRES")
            }
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .help("Otwórz szczegóły pobierania i wysyłania")
        .accessibilityLabel(
            "Otwórz wykres transferu. Pobieranie \(RateFormatter.detailed(model.network.instantDownload, unit: model.rateUnit)), wysyłanie \(RateFormatter.detailed(model.network.instantUpload, unit: model.rateUnit))."
        )
    }

    private var compactSystemShortcut: some View {
        Button {
            withAnimation(PanelMotion.navigation) {
                model.toggleSystemDetails()
            }
        } label: {
            HStack(spacing: 10) {
                Text("SYSTEM")
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.65)
                    .foregroundStyle(Palette.muted)
                Text("CPU \(MetricFormatter.percent(model.system.cpuUsage))")
                Text("RAM \(MetricFormatter.percent(memoryUsage))")
                Spacer(minLength: 0)
                InlineNavigationLabel(title: "PROCESY")
            }
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.inbound)
            .monospacedDigit()
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .help("Otwórz procesy CPU i RAM")
        .accessibilityLabel("Otwórz szczegóły użycia procesora i pamięci.")
    }

    private var compactControlsContent: some View {
        HStack(spacing: 0) {
            CompactToggleCard(
                title: model.vpn.title,
                subtitle: model.vpn.subtitle,
                symbol: "shield.lefthalf.filled",
                isOn: model.vpn.mode.isActive,
                disabled: model.isWorking || !model.vpn.mode.isToggleable,
                action: model.toggleVPN
            )

            Rectangle()
                .fill(Palette.line)
                .frame(width: 1, height: 30)

            if model.sleep.configured {
                CompactSleepCard(model: model)
            } else {
                CompactConfigureSleepCard(model: model)
            }
        }
        .frame(height: 48)
    }

    private var compactControls: some View {
        compactControlsContent
        .pulseGlass(radius: 13, tone: .main, interactive: true)
    }

}

private struct WeatherSummary: View {
    @ObservedObject var model: PulseModel
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Button(action: model.openWeatherApp) {
                    HStack(spacing: 7) {
                        WeatherGlyph(code: model.weather.weatherCode, size: 15)
                        Text(WeatherDisplay.temperature(model.weather.temperature))
                            .font(.system(size: 19).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.18), value: model.weather.temperature)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 7)
                .frame(height: 32)
                .help("Otwórz aplikację Pogoda")

                VStack(alignment: .leading, spacing: 2) {
                    Text(summaryDescription)
                        .font(.system(size: 11).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text(model.weather.place?.name ?? model.weather.outlook)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(PanelMotion.navigation) {
                        model.toggleWeatherDetails()
                    }
                } label: {
                    InlineNavigationLabel(
                        title: model.weatherDetailsShown ? "WRÓĆ" : "WIĘCEJ",
                        backwards: model.weatherDetailsShown
                    )
                }
                .buttonStyle(InlineActionButtonStyle())
            }

            if model.weatherDetailsShown {
                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)
                    .padding(.top, 2)

                WeatherDetails(model: model, query: $query)
                    .transition(PanelMotion.surfaceTransition)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var summaryDescription: String {
        WeatherService.rainNotice(for: model.weather.hours)?.compactText
            ?? WeatherDisplay.description(for: model.weather.weatherCode)
    }
}

private struct WeatherDetails: View {
    @ObservedObject var model: PulseModel
    @Binding var query: String
    @AppStorage("weather-v1.range") private var storedRange = ForecastRange.fourHours.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    if query.isEmpty {
                        Text("Inna miejscowość")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.muted)
                            .padding(.leading, 8)
                    }
                    TextField("", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 8)
                        .onSubmit { model.searchWeather(query) }
                }
                .frame(height: 25)
                .pulseGlass(radius: 9, interactive: true)
                Button("Pokaż") {
                    model.searchWeather(query)
                }
                .buttonStyle(PanelButtonStyle())
                Button {
                    query = ""
                    model.useDeviceLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 19, height: 19)
                }
                .buttonStyle(PanelButtonStyle())
                .help("Moja lokalizacja")
            }

            HStack(alignment: .top, spacing: 7) {
                Text(outlookText)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Picker("Zakres prognozy", selection: rangeSelection) {
                    ForEach(ForecastRange.allCases) { item in
                        Text(item.rawValue)
                            .tag(item)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 66)
                .help("Zakres prognozy godzinowej")
            }

            HStack(spacing: 5) {
                ForEach(displayedHours) { hour in
                    WeatherHourTile(hour: hour)
                }
            }
            .frame(height: 62)

            WeatherConditionsSection(
                weather: model.weather,
                hours: visibleHours,
                range: range,
                airQuality: model.airQuality
            )

            HStack(spacing: 8) {
                WeatherSourceMenu(model: model)
                Spacer(minLength: 0)
                Text("AQI: Open-Meteo")
                    .font(.system(size: 8.5).weight(.medium))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private var visibleHours: [ForecastHour] {
        Array(model.weather.hours.prefix(range.hourCount))
    }

    private var displayedHours: [ForecastHour] {
        let stride = range.sampleStride
        return visibleHours.enumerated()
            .filter { $0.offset % stride == 0 }
            .prefix(4)
            .map(\.element)
    }

    private var range: ForecastRange {
        ForecastRange(rawValue: storedRange) ?? .fourHours
    }

    private var rangeSelection: Binding<ForecastRange> {
        Binding(
            get: { range },
            set: { storedRange = $0.rawValue }
        )
    }

    private var outlookText: String {
        let outlook = rangeSummaryText
        guard let fallbackFrom = model.weather.fallbackFrom else {
            return outlook
        }
        return "\(fallbackFrom.shortLabel) chwilowo niedostępne. \(outlook)"
    }

    private var rangeSummaryText: String {
        guard !visibleHours.isEmpty else { return model.weather.outlook }
        let low = visibleHours.map(\.temperature).min() ?? 0
        let high = visibleHours.map(\.temperature).max() ?? 0
        return "\(range.rawValue) · \(Int(low.rounded()))-\(Int(high.rounded()))°C"
    }
}

private struct WeatherSourceMenu: View {
    @ObservedObject var model: PulseModel

    var body: some View {
        Menu {
            ForEach([WeatherSource.openMeteo, .icon, .metNo], id: \.rawValue) { source in
                Button {
                    model.selectWeatherSource(source)
                } label: {
                    if source == model.weatherSource {
                        Label(source.label, systemImage: "checkmark")
                    } else {
                        Text(source.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text("ŹRÓDŁO")
                    .font(.system(size: 8.5).weight(.bold))
                    .tracking(0.45)
                    .foregroundStyle(Palette.muted)
                Text(model.weatherSource.shortLabel)
                    .font(.system(size: 9).weight(.bold))
                    .foregroundStyle(Palette.strong)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Model prognozy pogody")
    }
}

private struct WeatherConditionsSection: View {
    let weather: WeatherState
    let hours: [ForecastHour]
    let range: ForecastRange
    let airQuality: AirQualitySnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("WARUNKI")
                .font(.system(size: 8.5).weight(.bold))
                .tracking(0.55)
                .foregroundStyle(Palette.muted)

            if shouldShowApparentTemperature {
                WeatherConditionRow(
                    title: "Odczuwalna",
                    value: WeatherDisplay.temperature(weather.apparentTemperature),
                    detail: "teraz",
                    color: Palette.ink
                )
            }

            WeatherConditionRow(
                title: "Wiatr",
                value: WeatherDisplay.wind(weather.windSpeed),
                detail: windDetail,
                color: windColor
            )
            WeatherConditionRow(
                title: "Opad",
                value: rainValue,
                detail: rainDetail,
                color: rainColor
            )
            WeatherConditionRow(
                title: "Powietrze",
                value: airQuality?.qualityLabel ?? "czekam",
                detail: airQuality?.detailText ?? "Open-Meteo AQI",
                color: airQualityColor
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var shouldShowApparentTemperature: Bool {
        guard let apparent = weather.apparentTemperature,
              let temperature = weather.temperature else {
            return false
        }
        return abs(apparent - temperature) >= 2
    }

    private var windDetail: String {
        guard let gusts = weather.windGusts else { return "porywy --" }
        return "porywy \(WeatherDisplay.wind(gusts))"
    }

    private var rainValue: String {
        let total = hours.compactMap(\.precipitation).reduce(0, +)
        if total >= 0.1 {
            return WeatherDisplay.rainfall(total)
        }
        guard let probability = maxRainProbability else { return "0 mm" }
        return "\(probability)%"
    }

    private var rainDetail: String {
        var parts: [String] = []
        if let probability = maxRainProbability {
            parts.append("max \(probability)%")
        }
        parts.append(range.rawValue)
        return parts.joined(separator: " · ")
    }

    private var maxRainProbability: Int? {
        hours.compactMap(\.precipitationProbability).max()
    }

    private var windColor: Color {
        if (weather.windGusts ?? 0) >= 40 || (weather.windSpeed ?? 0) >= 30 {
            return Palette.warning
        }
        return Palette.ink
    }

    private var rainColor: Color {
        let total = hours.compactMap(\.precipitation).reduce(0, +)
        if total >= 2 || (maxRainProbability ?? 0) >= 60 {
            return Palette.inbound
        }
        return Palette.ink
    }

    private var airQualityColor: Color {
        guard let aqi = airQuality?.europeanAQI else { return Palette.muted }
        if aqi >= 81 { return Palette.danger }
        if aqi >= 61 { return Palette.warning }
        return Palette.ink
    }
}

private struct WeatherConditionRow: View {
    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 9).weight(.semibold))
                .foregroundStyle(Palette.muted)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(size: 10).weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .frame(width: 64, alignment: .leading)
            Text(detail)
                .font(.system(size: 8.5).weight(.medium))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .frame(height: 17)
    }
}

private struct WeatherHourTile: View {
    let hour: ForecastHour

    var body: some View {
        VStack(spacing: 3) {
            Text(hour.shortTime)
                .font(.system(size: 9.5).weight(.bold))
                .foregroundStyle(Palette.muted)
                .monospacedDigit()
            WeatherGlyph(code: hour.weatherCode, size: 11)
            Text(WeatherDisplay.temperature(hour.temperature))
                .font(.system(size: 10.5).weight(.bold))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
            Text(WeatherDisplay.precipitationLabel(for: hour))
                .font(.system(size: 9).weight(.bold))
                .foregroundStyle(Palette.muted)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CompactRateReadout: View {
    let label: String
    let symbol: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8.5).weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Palette.muted)
                HStack(spacing: 4) {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                    Text(value)
                        .font(.system(size: 14).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.16), value: value)
                }
                .foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 37)
    }
}

private struct CompactTransferHero: View {
    let downloadValue: String
    let uploadValue: String
    let downloadSamples: [Double]
    let uploadSamples: [Double]

    var body: some View {
        HStack(spacing: 10) {
            CompactHeroRate(
                label: "DOWNLOAD",
                symbol: "arrow.down",
                value: downloadValue,
                samples: downloadSamples,
                color: Palette.inbound,
                prominent: true
            )

            Rectangle()
                .fill(Palette.line.opacity(0.72))
                .frame(width: 1, height: 54)

            CompactHeroRate(
                label: "UPLOAD",
                symbol: "arrow.up",
                value: uploadValue,
                samples: uploadSamples,
                color: Palette.outbound,
                prominent: false
            )
        }
        .frame(height: 62)
    }
}

private struct CompactHeroRate: View {
    let label: String
    let symbol: String
    let value: String
    let samples: [Double]
    let color: Color
    let prominent: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RateSparkline(samples: samples, color: color)
                .frame(height: 29)
                .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(Palette.muted)
                HStack(spacing: 4) {
                    Image(systemName: symbol)
                        .font(.system(size: prominent ? 11 : 10, weight: .bold))
                    Text(value)
                        .font(.system(size: prominent ? 18 : 16, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.16), value: value)
                }
                .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RateSparkline: View {
    private static let sampleCapacity = 30

    let samples: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let points = chartPoints(in: geometry.size)

            ZStack {
                fillPath(points: points, size: geometry.size)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.15), color.opacity(0.015)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                linePath(points: points)
                    .stroke(
                        color.opacity(0.78),
                        style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round)
                    )
            }
            .animation(.easeOut(duration: 0.18), value: samples)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        let values = Array(repeating: 0.0, count: max(0, Self.sampleCapacity - samples.count)) + samples
        let scaled = values.map { log1p(max(0, $0)) }
        let peak = max(scaled.max() ?? 0, 1)
        let denominator = CGFloat(max(scaled.count - 1, 1))
        return scaled.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / denominator
            let normalized = CGFloat(value / peak)
            let y = size.height - max(1.5, normalized * (size.height - 3))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func fillPath(points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

private struct WiFiNetworkPicker: View {
    @ObservedObject var model: PulseModel
    @State private var password = ""
    @State private var hotspotName = ""
    @State private var editsHotspot = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)

            if let network = model.wifiPasswordRequest {
                Text("Hasło do \(network.name)")
                    .font(.system(size: 10).weight(.bold))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    SecureField("Hasło Wi-Fi", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5))
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .pulseGlass(radius: 9, interactive: true)
                        .onSubmit { connect(network) }
                    Button("Połącz") {
                        connect(network)
                    }
                    .buttonStyle(PanelButtonStyle())
                    .disabled(password.isEmpty)
                }
            } else {
                personalHotspotSection

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)

                HStack {
                    Text("DOSTĘPNE SIECI")
                        .font(.system(size: 8.5).weight(.bold))
                        .tracking(0.55)
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Button {
                        model.scanWiFiNetworks()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(PanelButtonStyle())
                    .disabled(model.wifiScanInProgress || model.wifiAwaitingLocationAccess)
                }

                if model.wifiAwaitingLocationAccess {
                    Text("Potwierdź dostęp w oknie macOS, aby zobaczyć nazwy sieci.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.muted)
                        .frame(height: 28)
                } else if model.wifiNeedsLocationAccess {
                    Button {
                        model.openWiFiLocationSettings()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Włącz Szlauch w Usługach lokalizacji")
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Palette.strong)
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                        .pulseGlass(radius: 9, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .help("Otwórz Ustawienia systemowe")
                } else if model.wifiScanInProgress && model.wifiNetworks.isEmpty {
                    Text("Szukam pobliskich sieci...")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                        .frame(height: 28)
                } else if model.wifiNetworks.isEmpty {
                    Text("Nie znaleziono pobliskich sieci.")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                        .frame(height: 28)
                } else {
                    ScrollView(.vertical, showsIndicators: model.wifiNetworks.count > 4) {
                        LazyVStack(spacing: 4) {
                            ForEach(model.wifiNetworks) { network in
                                WiFiNetworkRow(
                                    network: network,
                                    selected: WiFiIdentity.matches(model.wifi.networkName, network.name),
                                    connecting: model.wifiConnectingName == network.name
                                ) {
                                    model.connectWiFi(network)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 130)
                }
            }

            if let error = model.wifiConnectionError {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.danger)
                    .lineLimit(2)
            } else {
                Text("Po wybraniu zabezpieczonej sieci hasło pojawi się tylko, gdy jest potrzebne.")
                    .font(.system(size: 8))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
        .onAppear {
            hotspotName = model.personalHotspotName ?? ""
        }
    }

    private var personalHotspotSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("HOTSPOT OSOBISTY")
                    .font(.system(size: 8.5).weight(.bold))
                    .tracking(0.55)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button(editsHotspot ? "ANULUJ" : model.personalHotspotName == nil ? "USTAW" : "ZMIEŃ") {
                    hotspotName = model.personalHotspotName ?? ""
                    editsHotspot.toggle()
                }
                .buttonStyle(InlineActionButtonStyle())
            }

            if editsHotspot {
                HStack(spacing: 6) {
                    TextField("Nazwa hotspotu telefonu", text: $hotspotName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5))
                        .padding(.horizontal, 8)
                        .frame(height: 27)
                        .pulseGlass(radius: 9, interactive: true)
                        .onSubmit(saveHotspot)
                    Button("Zapisz") {
                        saveHotspot()
                    }
                    .buttonStyle(PanelButtonStyle())
                    .disabled(PersonalHotspotStore.normalizedName(hotspotName) == nil)
                }
            } else if let name = model.personalHotspotName {
                PersonalHotspotRow(
                    name: name,
                    selected: WiFiIdentity.matches(model.wifi.networkName, name),
                    connecting: model.wifiConnectingName == name
                ) {
                    model.connectPersonalHotspot()
                }
            } else {
                Text("Ustaw telefon raz, potem przełączaj się jednym kliknięciem.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Palette.muted)
                    .frame(height: 27)
            }
        }
    }

    private func connect(_ network: WiFiNetworkOption) {
        guard !password.isEmpty else { return }
        model.connectWiFi(network, password: password)
        password = ""
    }

    private func saveHotspot() {
        guard PersonalHotspotStore.normalizedName(hotspotName) != nil else { return }
        model.setPersonalHotspotName(hotspotName)
        hotspotName = model.personalHotspotName ?? ""
        editsHotspot = false
    }
}

private struct PersonalHotspotRow: View {
    let name: String
    let selected: Bool
    let connecting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "personalhotspot")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.strong)
                    .frame(width: 15)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 10.5).weight(.bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(selected ? "Połączono" : "Połącz z telefonem")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 4)
                if connecting {
                    Text("Łączę")
                        .foregroundStyle(Palette.muted)
                } else if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.strong)
                } else {
                    Text("POŁĄCZ")
                        .foregroundStyle(Palette.strong)
                }
            }
            .font(.system(size: 9).weight(.semibold))
            .padding(.horizontal, 8)
            .frame(height: 34)
            .background(
                selected ? Palette.soft : Palette.surface,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(connecting || selected)
    }
}

private struct WiFiNetworkRow: View {
    let network: WiFiNetworkOption
    let selected: Bool
    let connecting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: network.signalSymbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(network.signal <= -78 ? Palette.warning : Palette.strong)
                    .frame(width: 15)
                Text(network.name)
                    .font(.system(size: 10.5).weight(selected ? .bold : .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if network.secured {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
                if connecting {
                    Text("Łączę")
                        .foregroundStyle(Palette.muted)
                } else if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.strong)
                }
            }
            .font(.system(size: 9).weight(.semibold))
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(
                selected ? Palette.soft : Palette.surface,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(connecting || selected)
    }
}

private struct TrafficDetails: View {
    @ObservedObject var model: PulseModel
    @State private var range = TrafficRange.quarterHour

    private var window: TrafficWindow {
        TrafficWindow.make(
            from: model.trafficHistory,
            rateHistory: model.trafficRateHistory,
            range: range
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)

            HStack(spacing: 5) {
                ForEach(TrafficRange.allCases) { item in
                    Button(item.rawValue) {
                        withAnimation(PanelMotion.selection) {
                            range = item
                        }
                    }
                    .buttonStyle(WeatherSourceButtonStyle(active: range == item))
                }
                Spacer(minLength: 0)
                RateUnitPicker(unit: model.rateUnit, onSelect: model.setRateUnit)
                Button {
                    withAnimation(PanelMotion.navigation) {
                        model.toggleTrafficDetails()
                    }
                } label: {
                    InlineNavigationLabel(title: "WRÓĆ", backwards: true)
                }
                .buttonStyle(InlineActionButtonStyle())
            }

            TrafficDetailChart(
                samples: window.chartSamples,
                start: window.start,
                end: window.end,
                unit: model.rateUnit
            )
                .frame(height: 92)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 6) {
                TrafficMetric(
                    title: "POBRANO",
                    value: MetricFormatter.mobileData(window.totals.download),
                    color: Palette.inbound
                )
                TrafficMetric(
                    title: "WYSŁANO",
                    value: MetricFormatter.mobileData(window.totals.upload),
                    color: Palette.outbound
                )
                TrafficMetric(
                    title: "MAX ↓",
                    value: RateFormatter.detailed(window.maximumDownload, unit: model.rateUnit),
                    color: Palette.inbound
                )
                TrafficMetric(
                    title: "MAX ↑",
                    value: RateFormatter.detailed(window.maximumUpload, unit: model.rateUnit),
                    color: Palette.outbound
                )
            }

            Text(
                "Średnia zakresu: ↓ \(RateFormatter.detailed(window.averageDownload, unit: model.rateUnit))"
                    + "  ↑ \(RateFormatter.detailed(window.averageUpload, unit: model.rateUnit))"
            )
            .font(.system(size: 8.5))
            .foregroundStyle(Palette.muted)
            .monospacedDigit()

            TodayTrafficSummary(
                history: model.trafficHistory,
                activeRoute: model.activeTrafficRoute
            )
        }
    }
}

private struct RateUnitPicker: View {
    let unit: RateDisplayUnit
    let onSelect: (RateDisplayUnit) -> Void

    var body: some View {
        Menu {
            ForEach(RateDisplayUnit.allCases) { item in
                Button {
                    withAnimation(PanelMotion.selection) { onSelect(item) }
                } label: {
                    if item == unit {
                        Label("\(item.rawValue) · \(item.description)", systemImage: "checkmark")
                    } else {
                        Text("\(item.rawValue) · \(item.description)")
                    }
                }
            }
        } label: {
            Text(unit.rawValue)
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .frame(minWidth: 36)
        }
        .menuStyle(.button)
        .controlSize(.mini)
        .frame(width: 62)
        .tint(Palette.muted)
        .accessibilityLabel("Jednostka transferu")
        .help("MB/s: megabajty. Mb/s: megabity używane w prędkościach łącza.")
    }
}

private struct SystemDetails: View {
    @ObservedObject var model: PulseModel

    private var peakCore: (number: Int, usage: Double)? {
        guard let peak = model.system.coreUsages.enumerated().max(by: { $0.element < $1.element }) else {
            return nil
        }
        return (number: peak.offset + 1, usage: peak.element)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)

            HStack {
                Text("RDZENIE")
                    .font(.system(size: 8.5).weight(.bold))
                    .tracking(0.55)
                    .foregroundStyle(Palette.muted)
                Spacer()
                if let peakCore {
                    Text("MAX \(MetricFormatter.percent(peakCore.usage)) · #\(peakCore.number)")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .monospacedDigit()
                        .padding(.trailing, 3)
                }
                Button {
                    withAnimation(PanelMotion.navigation) {
                        model.toggleSystemDetails()
                    }
                } label: {
                    InlineNavigationLabel(title: "WRÓĆ", backwards: true)
                }
                .buttonStyle(InlineActionButtonStyle())
            }

            CoreUsageSkyline(usages: model.system.coreUsages)

            HStack(alignment: .top, spacing: 7) {
                ProcessColumn(
                    title: "CPU · APLIKACJE",
                    values: model.system.cpuProcesses,
                    value: { "\(Int($0.cpu.rounded()))%" }
                )
                ProcessColumn(
                    title: "RAM · APLIKACJE",
                    values: model.system.memoryProcesses,
                    value: { MetricFormatter.applicationMemory($0.memoryBytes) }
                )
            }

            Text("Aplikacje odświeżane co 5 s tylko w tym widoku.")
                .font(.system(size: 9))
                .foregroundStyle(Palette.muted)
        }
    }
}

private struct CoreUsageSkyline: View {
    let usages: [Double]

    var body: some View {
        if usages.isEmpty {
            Text("Odczytuję rdzenie...")
                .font(.system(size: 9))
                .foregroundStyle(Palette.muted)
                .frame(height: 34, alignment: .leading)
        } else {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(usages.enumerated()), id: \.offset) { index, usage in
                    CoreUsageMeter(index: index, usage: usage)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 34)
        }
    }
}

private struct CoreUsageMeter: View {
    let index: Int
    let usage: Double

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Palette.muted.opacity(0.18))
                Capsule()
                    .fill(Palette.metric.opacity(0.86))
                    .frame(height: max(2, 24 * min(max(usage, 0), 1)))
            }
            .frame(width: 5, height: 24)
            Text("\(index + 1)")
                .font(.system(size: 8).weight(.semibold))
                .foregroundStyle(Palette.muted)
        }
        .frame(height: 34)
    }
}

private struct ProcessColumn: View {
    let title: String
    let values: [ProcessUsage]
    let value: (ProcessUsage) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 8.5).weight(.bold))
                .tracking(0.35)
                .foregroundStyle(Palette.muted)
            if values.isEmpty {
                Text("Odczytuję...")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.muted)
                    .frame(height: 64, alignment: .topLeading)
            } else {
                ForEach(values) { process in
                    HStack(spacing: 4) {
                        Text(process.name)
                            .lineLimit(1)
                        Spacer(minLength: 3)
                        Text(value(process))
                            .monospacedDigit()
                    }
                    .font(.system(size: 10).weight(.medium))
                    .foregroundStyle(Palette.ink)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct TrafficDetailChart: View {
    let samples: [TrafficChartSample]
    let start: Date
    let end: Date
    let unit: RateDisplayUnit

    private let axisWidth: CGFloat = 58
    private let rightInset: CGFloat = 7
    private let topInset: CGFloat = 16
    private let bottomInset: CGFloat = 18
    private let horizontalLevels = [1.0, 0.5, 0.0]
    private let verticalLevels = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]

    var body: some View {
        GeometryReader { geometry in
            let plot = CGRect(
                x: axisWidth,
                y: topInset,
                width: max(1, geometry.size.width - axisWidth - rightInset),
                height: max(1, geometry.size.height - topInset - bottomInset)
            )
            let maximum = yMaximum
            let downloadPoints = points(for: \.download, maximum: maximum, in: plot)
            let uploadPoints = points(for: \.upload, maximum: maximum, in: plot)

            ZStack(alignment: .topLeading) {
                Text(unit.rawValue)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    .frame(width: axisWidth - 7, alignment: .trailing)
                    .position(x: (axisWidth - 7) / 2, y: 6)

                ForEach(horizontalLevels, id: \.self) { level in
                    let y = plot.minY + CGFloat(1 - level) * plot.height
                    Text(RateFormatter.axisValue(maximum * level, unit: unit))
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .frame(width: axisWidth - 7, alignment: .trailing)
                        .position(x: (axisWidth - 7) / 2, y: y)
                    Path { path in
                        path.move(to: CGPoint(x: plot.minX, y: y))
                        path.addLine(to: CGPoint(x: plot.maxX, y: y))
                    }
                    .stroke(
                        Palette.line.opacity(level == 0 ? 0.72 : 0.48),
                        style: StrokeStyle(lineWidth: 0.6, dash: level == 0 ? [] : [2, 3])
                    )
                }

                ForEach(verticalLevels, id: \.self) { level in
                    let x = plot.minX + CGFloat(level) * plot.width
                    Path { path in
                        path.move(to: CGPoint(x: x, y: plot.minY))
                        path.addLine(to: CGPoint(x: x, y: plot.maxY))
                    }
                    .stroke(Palette.line.opacity(0.26), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    Text(timeLabel(at: level))
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 37)
                        .position(x: timeLabelPosition(for: level, in: plot), y: plot.maxY + 10)
                }

                if samples.isEmpty {
                    Text("Zbieram próbki co 5 s")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .position(x: plot.midX, y: plot.midY)
                } else {
                    filledPath(points: downloadPoints, baseline: plot.maxY)
                        .fill(
                            LinearGradient(
                                colors: [Palette.inbound.opacity(0.13), Palette.inbound.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    filledPath(points: uploadPoints, baseline: plot.maxY)
                        .fill(
                            LinearGradient(
                                colors: [Palette.outbound.opacity(0.11), Palette.outbound.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    linePath(points: downloadPoints)
                        .stroke(Palette.inbound.opacity(0.96), style: chartStroke)
                    linePath(points: uploadPoints)
                        .stroke(Palette.outbound.opacity(0.96), style: chartStroke)
                }
            }
            .animation(.easeOut(duration: 0.18), value: samples.map(\.download))
            .animation(.easeOut(duration: 0.18), value: samples.map(\.upload))
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Transfer w czasie, skala liniowa")
    }

    private var yMaximum: Double {
        let peak = max(
            samples.map(\.download).max() ?? 0,
            samples.map(\.upload).max() ?? 0,
            1024
        )
        let unit = peak >= 1024 * 1024 ? 1024.0 * 1024 : 1024.0
        let scaled = peak / unit
        let magnitude = pow(10, floor(log10(max(scaled, 1))))
        let normalized = scaled / magnitude
        let nice = normalized <= 1 ? 1.0 : normalized <= 2 ? 2.0 : normalized <= 5 ? 5.0 : 10.0
        return nice * magnitude * unit
    }

    private var chartStroke: StrokeStyle {
        StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
    }

    private func points(
        for keyPath: KeyPath<TrafficChartSample, Double>,
        maximum: Double,
        in plot: CGRect
    ) -> [CGPoint] {
        let duration = max(end.timeIntervalSince(start), 1)
        return samples.map { sample in
            let elapsed = min(max(sample.timestamp.timeIntervalSince(start), 0), duration)
            let x = plot.minX + CGFloat(elapsed / duration) * plot.width
            let normalized = min(max(sample[keyPath: keyPath] / maximum, 0), 1)
            let y = plot.maxY - CGFloat(normalized) * plot.height
            return CGPoint(x: x, y: y)
        }
    }

    private func timeLabel(at fraction: Double) -> String {
        let duration = max(end.timeIntervalSince(start), 1)
        return Self.timeFormatter.string(
            from: start.addingTimeInterval(duration * fraction)
        )
    }

    private func timeLabelPosition(for fraction: Double, in plot: CGRect) -> CGFloat {
        if fraction == 0 {
            return plot.minX + 15
        }
        if fraction == 1 {
            return plot.maxX - 15
        }
        return plot.minX + CGFloat(fraction) * plot.width
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func filledPath(points: [CGPoint], baseline: CGFloat) -> Path {
        var path = linePath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: baseline))
        path.addLine(to: CGPoint(x: first.x, y: baseline))
        path.closeSubpath()
        return path
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct TrafficMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Text(title)
            }
            .font(.system(size: 8.5).weight(.bold))
            .tracking(0.3)
            .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 9).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct TodayTrafficSummary: View {
    let history: TrafficHistoryState
    let activeRoute: TrafficRoute

    private var all: TrafficTotals { history.todayTotals() }
    private var wifi: TrafficTotals { history.todayTotals(for: .wifi) }
    private var hotspot: TrafficTotals { history.todayTotals(for: .hotspot) }
    private var other: TrafficTotals { history.todayTotals(for: .other) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("DZIŚ · CAŁY RUCH")
                    .font(.system(size: 8.5).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text("↓ \(MetricFormatter.mobileData(all.download))  ↑ \(MetricFormatter.mobileData(all.upload))")
                    .font(.system(size: 10).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            routeRow("Wi-Fi", route: .wifi, totals: wifi, color: Palette.inbound)
            routeRow("Hotspot", route: .hotspot, totals: hotspot, color: Palette.outbound)
            if other.total > 0 {
                routeRow("Inne", route: .other, totals: other, color: Palette.muted)
            }
            Text("Cały ruch = Wi-Fi + hotspot + inne · pomiar lokalny.")
                .font(.system(size: 8.5))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func routeRow(
        _ name: String,
        route: TrafficRoute,
        totals: TrafficTotals,
        color: Color
    ) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(name)
                .foregroundStyle(Palette.muted)
            if activeRoute == route {
                Text("TERAZ")
                    .font(.system(size: 7.5).weight(.bold))
                    .tracking(0.35)
                    .foregroundStyle(color)
                    .padding(.horizontal, 4)
                    .frame(height: 11)
                    .background(color.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 4)
            Text("↓ \(MetricFormatter.mobileData(totals.download))   ↑ \(MetricFormatter.mobileData(totals.upload))")
                .foregroundStyle(Palette.ink)
        }
        .font(.system(size: 8.5).weight(.semibold))
        .monospacedDigit()
        .lineLimit(1)
    }
}

private struct CompactMetric: View {
    let title: String
    let value: String
    let progress: Double
    var color: Color = Palette.metric

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 9).weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(value)
                    .font(.system(size: 13).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.16), value: value)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.line.opacity(0.55))
                    Capsule()
                        .fill(color)
                        .frame(width: max(3, geometry.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
    }
}

private struct CompactHotspotRow: View {
    let history: TrafficHistoryState
    let connectionCost: ConnectionCost
    let expanded: Bool
    let onToggle: () -> Void
    let onReset: () -> Void

    private var days: [HotspotDayUsage] {
        history.hotspotDays()
    }

    private var today: TrafficTotals {
        days.first?.totals ?? TrafficTotals()
    }

    private var maximumDownload: UInt64 {
        max(days.map(\.totals.download).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(expanded ? "HOTSPOT · 7 DNI" : "HOTSPOT · DZIŚ")
                    .font(.system(size: 9).weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Palette.muted)
                Circle()
                    .fill(connectionCost.isMetered ? Palette.action : Palette.line)
                    .frame(width: 6, height: 6)
                Text(connectionCost.isMetered ? "TERAZ" : "POZA HOTSPOTEM")
                    .font(.system(size: 8.5).weight(.bold))
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button {
                    onToggle()
                } label: {
                    InlineNavigationLabel(
                        title: expanded ? "WRÓĆ" : "7 DNI",
                        backwards: expanded
                    )
                }
                .buttonStyle(InlineActionButtonStyle())
            }

            if expanded {
                HStack {
                    Text("DZIEŃ")
                    Spacer()
                    Text("POBRANO")
                        .foregroundStyle(Palette.inbound)
                    Text("WYSŁANO")
                        .frame(width: 62, alignment: .trailing)
                        .foregroundStyle(Palette.outbound)
                }
                .font(.system(size: 7.5).weight(.bold))
                .tracking(0.35)
                .foregroundStyle(Palette.muted)

                ForEach(days) { day in
                    HotspotDayRow(usage: day, maximumDownload: maximumDownload)
                }

                HStack {
                    Text("Pomiar lokalny · historia 31 dni")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Button("Wyczyść") {
                        onReset()
                    }
                    .buttonStyle(PanelButtonStyle())
                    .help("Wyzeruj dzienną historię hotspotu")
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("↓ \(MetricFormatter.mobileData(today.download))")
                        .font(.system(size: 12).weight(.bold))
                        .foregroundStyle(Palette.inbound)
                    Text("pobrano")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Text("↑ \(MetricFormatter.mobileData(today.upload))")
                        .font(.system(size: 10).weight(.semibold))
                        .foregroundStyle(Palette.outbound)
                    Text("wysłano")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                }
                .monospacedDigit()
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, 9)
        .padding(.bottom, 3)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }
}

private struct HotspotDayRow: View {
    let usage: HotspotDayUsage
    let maximumDownload: UInt64

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "E d MMM"
        return formatter
    }()

    private var label: String {
        if Calendar.current.isDateInToday(usage.day) { return "DZIŚ" }
        if Calendar.current.isDateInYesterday(usage.day) { return "WCZORAJ" }
        return Self.formatter.string(from: usage.day).uppercased()
    }

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.muted)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.line.opacity(0.45))
                    Capsule()
                        .fill(Palette.inbound.opacity(0.9))
                        .frame(
                            width: usage.totals.download == 0
                                ? 0
                                : max(3, geometry.size.width * Double(usage.totals.download) / Double(maximumDownload))
                        )
                }
            }
            .frame(width: 52, height: 3)
            Spacer(minLength: 2)
            Text(MetricFormatter.mobileData(usage.totals.download))
                .foregroundStyle(Palette.ink)
                .frame(width: 70, alignment: .trailing)
            Text(MetricFormatter.mobileData(usage.totals.upload))
                .foregroundStyle(Palette.muted)
                .frame(width: 62, alignment: .trailing)
        }
        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
        .monospacedDigit()
        .frame(height: 13)
    }
}

private struct CompactToggleCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isOn: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { isOn },
                set: { _ in action() }
            )
        ) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.strong : Palette.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 10.5).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Palette.action))
        .controlSize(.small)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

private struct CompactSleepCard: View {
    @ObservedObject var model: PulseModel

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "moon.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(model.sleep.mode.isPreventingSleep ? Palette.strong : Palette.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nie usypiaj")
                    .font(.system(size: 10.5).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text(model.sleep.mode.label)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 1)
            Menu {
                Button("Usuń zgodę macOS", role: .destructive) {
                    model.removeSleepConfiguration()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 16)
            .help("Usuń zgodę do przełączania blokady uśpienia")

            Toggle(
                "",
                isOn: Binding(
                    get: { model.sleep.mode.isPreventingSleep },
                    set: { _ in model.toggleSleep() }
                )
            )
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: Palette.action))
            .controlSize(.small)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .disabled(model.isWorking)
        .opacity(model.isWorking ? 0.55 : 1)
    }
}

private struct CompactConfigureSleepCard: View {
    @ObservedObject var model: PulseModel

    var body: some View {
        Button {
            model.requestSleepConfiguration()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.strong)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nie usypiaj")
                        .font(.system(size: 10.5).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("Zgoda raz")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .disabled(model.isWorking)
    }
}

private struct SleepPermissionPrompt: View {
    @ObservedObject var model: PulseModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.strong)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Jednorazowa zgoda macOS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Hasło wpisujesz w oknie systemu. Szlauch go nie widzi ani nie zapisuje; zgoda służy tylko do przełączania blokady uśpienia.")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 7) {
                Spacer()
                Button("Nie teraz") {
                    model.cancelSleepConfiguration()
                }
                .buttonStyle(PanelButtonStyle())

                Button("Kontynuuj") {
                    model.confirmSleepConfiguration()
                }
                .buttonStyle(ActionButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct RateReadout: View {
    let label: String
    let value: String
    let average: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 10).weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Palette.muted)
            }
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(value)
                    .font(.system(size: 17).weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(Palette.ink)
            Text("Śr. 5 s \(average)")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SystemMetric: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 10).weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(value)
                    .font(.system(size: 15).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.line.opacity(0.55))
                    Capsule()
                        .fill(Palette.metric)
                        .frame(width: max(4, geometry.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 4)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
    }
}

private struct InstrumentDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.line.opacity(0.72))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }
}

private struct InlineNavigationLabel: View {
    let title: String
    var backwards: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if backwards {
                Image(systemName: "chevron.left")
            }
            Text(title)
            if !backwards {
                Image(systemName: "chevron.right")
            }
        }
        .font(.system(size: 9.5, weight: .bold))
        .tracking(0.45)
    }
}

private struct InlineActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Palette.strong.opacity(0.65) : Palette.strong)
            .padding(.horizontal, 3)
            .frame(height: 22)
    }
}

private struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                configuration.isPressed ? Palette.line : Palette.surface,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(Palette.line, lineWidth: 0.5)
            }
    }
}

private struct PanelSwitchRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isOn: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.strong)
                    .frame(width: 21)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }

                Spacer()
                MiniSwitch(isOn: isOn)
            }
            .padding(.horizontal, 18)
            .frame(height: 51)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

private struct MiniSwitch: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Palette.action : Palette.line)
                .frame(width: 43, height: 25)
            Circle()
                .fill(Palette.surface)
                .frame(width: 19, height: 19)
                .padding(3)
        }
    }
}

private struct ConfigureSleepRow: View {
    @ObservedObject var model: PulseModel

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.strong)
                .frame(width: 21)
            VStack(alignment: .leading, spacing: 4) {
                Text("Sterowanie sleep")
                    .font(.system(size: 14).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("Wymaga jednej zgody administratora")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Button("Skonfiguruj") {
                model.requestSleepConfiguration()
            }
            .buttonStyle(ActionButtonStyle())
            .disabled(model.isWorking)
        }
        .padding(.horizontal, 18)
        .frame(height: 51)
    }
}

private struct BannerView: View {
    let banner: MessageBanner

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.kind == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(banner.text)
                .font(.system(size: 11.5).weight(.bold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(banner.kind == .success ? Palette.strong : Palette.danger)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(banner.kind == .success ? Palette.soft : Palette.danger.opacity(0.12))
    }
}

private struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Palette.soft, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Palette.action.opacity(0.18), lineWidth: 0.5)
            }
    }
}

private struct WeatherSourceButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(active ? Palette.strong : Palette.muted)
            .padding(.horizontal, 7)
            .frame(height: 25)
            .background(
                active ? Palette.soft : configuration.isPressed ? Palette.surface : Color.clear,
                in: Capsule()
            )
    }
}

private final class RateStatusView: NSView {
    private static let statusFontSize: CGFloat = 10.5
    private static let minimumFontSize: CGFloat = 8.1
    private static let statusFont = NSFont.monospacedDigitSystemFont(ofSize: statusFontSize, weight: .semibold)
    static let statusWidth: CGFloat = ceil(
        ("999 MB/s" as NSString).size(withAttributes: [.font: statusFont]).width + 2
    )

    var upload = "0 KB/s" {
        didSet { needsDisplay = true }
    }
    var download = "0 KB/s" {
        didSet { needsDisplay = true }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        upload.draw(
            in: NSRect(x: 0, y: bounds.height / 2 - 0.5, width: bounds.width, height: 12),
            withAttributes: attributes(for: upload, paragraph: paragraph)
        )
        download.draw(
            in: NSRect(x: 0, y: bounds.height / 2 - 11, width: bounds.width, height: 12),
            withAttributes: attributes(for: download, paragraph: paragraph)
        )
    }

    private func attributes(for value: String, paragraph: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        let naturalWidth = (value as NSString).size(withAttributes: [.font: Self.statusFont]).width
        let availableWidth = max(1, bounds.width - 2)
        let scaledSize = min(
            Self.statusFontSize,
            max(Self.minimumFontSize, Self.statusFontSize * availableWidth / max(naturalWidth, 1))
        )
        return [
            .font: NSFont.monospacedDigitSystemFont(ofSize: scaledSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }
}

private final class PopoverDelegate: NSObject, NSPopoverDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func popoverDidClose(_ notification: Notification) {
        onClose()
    }
}

private final class SingleInstanceGuard {
    private var descriptor: Int32 = -1

    func acquire() -> Bool {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("app.szlauch.macos.instance-v2.lock")
            .path
        descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return false }
        guard applyLock(type: Int16(F_WRLCK)) else {
            Darwin.close(descriptor)
            descriptor = -1
            return false
        }
        return true
    }

    deinit {
        guard descriptor >= 0 else { return }
        _ = applyLock(type: Int16(F_UNLCK))
        Darwin.close(descriptor)
    }

    private func applyLock(type: Int16) -> Bool {
        var lock = Darwin.flock()
        lock.l_type = type
        lock.l_whence = Int16(SEEK_SET)
        lock.l_start = 0
        lock.l_len = 0
        lock.l_pid = 0
        return Darwin.fcntl(descriptor, F_SETLK, &lock) != -1
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let popoverMenuBarGap: CGFloat = 1
    private static let firstRunPresentedKey = "onboarding-v1.presented-panel"

    private lazy var model = PulseModel()
    private let statusView = RateStatusView()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!
    private var popoverDelegate: PopoverDelegate!
    private var previewWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var currentNetwork = NetworkState.initial
    private var currentWiFi = WiFiState.initial
    private var instanceGuard: SingleInstanceGuard?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        LegacySettingsMigration.run()
        RetiredQuotaCleanup.run()
        AppearanceDefaultsMigration.run()

        if CommandLine.arguments.contains("--unregister-login") {
            try? SMAppService.mainApp.unregister()
            NSApp.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--register-login") {
            try? SMAppService.mainApp.register()
            NSApp.terminate(nil)
            return
        }

        if !RuntimeMode.isPreview {
            let guardHandle = SingleInstanceGuard()
            guard guardHandle.acquire() else {
                let ownPID = ProcessInfo.processInfo.processIdentifier
                if let identifier = Bundle.main.bundleIdentifier,
                   let existing = NSRunningApplication
                    .runningApplications(withBundleIdentifier: identifier)
                    .first(where: { $0.processIdentifier != ownPID }) {
                    existing.activate(options: [.activateIgnoringOtherApps])
                }
                NSApp.terminate(nil)
                return
            }
            instanceGuard = guardHandle
        }

        makeStatusItem()
        makePopover()
        connectModel()
        model.start()

        if let cityArgument = CommandLine.arguments.first(where: { $0.hasPrefix("--preview-city=") }) {
            let city = String(cityArgument.dropFirst("--preview-city=".count))
            model.searchWeather(city)
            if CommandLine.arguments.contains("--preview-return-location") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.model.useDeviceLocation()
                }
            }
        }
        if CommandLine.arguments.contains("--wifi-details") {
            model.toggleWiFiDetails()
        } else if CommandLine.arguments.contains("--traffic-details") {
            model.toggleTrafficDetails()
        } else if CommandLine.arguments.contains("--system-details") {
            model.toggleSystemDetails()
        } else if CommandLine.arguments.contains("--hotspot-details") {
            model.toggleHotspotDetails()
        } else if CommandLine.arguments.contains("--weather-details") {
            model.toggleWeatherDetails()
        }
        if CommandLine.arguments.contains("--preview-sleep-prompt") {
            model.requestSleepConfiguration()
        }

        if CommandLine.arguments.contains("--preview-window") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.showPreviewWindow()
                if CommandLine.arguments.contains("--preview-wifi-foreground") {
                    self.model.toggleWiFiDetails()
                }
            }
        } else if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showPopover()
            }
        } else if !UserDefaults.standard.bool(forKey: Self.firstRunPresentedKey) {
            UserDefaults.standard.set(true, forKey: Self.firstRunPresentedKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.showPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.prepareForTermination()
    }

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: RateStatusView.statusWidth)
        guard let button = statusItem.button else { return }
        button.title = ""
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp])
        button.toolTip = "Szlauch: upload i download"

        statusView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusView.topAnchor.constraint(equalTo: button.topAnchor),
            statusView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
    }

    private func makePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = PanelLayout.popoverSize
        popoverDelegate = PopoverDelegate { [weak self] in
            self?.statusItem.button?.highlight(false)
            self?.popover.contentViewController = nil
            self?.model.panelDidClose()
        }
        popover.delegate = popoverDelegate
    }

    private func connectModel() {
        model.$network
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.currentNetwork = state
                self.statusView.upload = RateFormatter.menu(state.instantUpload, unit: self.model.rateUnit)
                self.statusView.download = RateFormatter.menu(state.instantDownload, unit: self.model.rateUnit)
                self.refreshStatusToolTip()
            }
            .store(in: &cancellables)

        model.$rateUnit
            .receive(on: RunLoop.main)
            .sink { [weak self] unit in
                guard let self else { return }
                self.statusView.upload = RateFormatter.menu(self.currentNetwork.instantUpload, unit: unit)
                self.statusView.download = RateFormatter.menu(self.currentNetwork.instantDownload, unit: unit)
                self.refreshStatusToolTip()
            }
            .store(in: &cancellables)

        model.$wifi
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.currentWiFi = state
                self.refreshStatusToolTip()
            }
            .store(in: &cancellables)

    }

    private func refreshStatusToolTip() {
        statusItem.button?.toolTip =
            "\(currentWiFi.toolTip)\nOstatnia sekunda · Upload: \(RateFormatter.detailed(currentNetwork.instantUpload, unit: model.rateUnit))  Download: \(RateFormatter.detailed(currentNetwork.instantDownload, unit: model.rateUnit))"
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        model.panelDidOpen()
        let controller = NSHostingController(rootView: SzlauchPanel(model: model))
        controller.view.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = controller
        NSApp.activate(ignoringOtherApps: true)
        button.highlight(true)
        popover.show(relativeTo: popoverAnchorRect(for: button), of: button, preferredEdge: .minY)
        DispatchQueue.main.async { [weak self] in
            self?.positionPopoverBelowMenuBar()
        }
    }

    private func popoverAnchorRect(for button: NSStatusBarButton) -> NSRect {
        NSRect(
            x: button.bounds.midX - 1,
            y: button.bounds.minY,
            width: 2,
            height: 1
        )
    }

    private func positionPopoverBelowMenuBar() {
        guard popover.isShown,
              let popoverWindow = popover.contentViewController?.view.window,
              let statusWindow = statusItem.button?.window else { return }

        let requestedTop = statusWindow.frame.minY - Self.popoverMenuBarGap
        var origin = popoverWindow.frame.origin
        origin.y += requestedTop - popoverWindow.frame.maxY
        popoverWindow.setFrameOrigin(origin)
    }

    private func showPreviewWindow() {
        guard previewWindow == nil else { return }
        model.panelDidOpen()
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PanelLayout.width,
                height: PanelLayout.height
            ),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Szlauch"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        let hostingView = NSHostingView(rootView: SzlauchPanel(model: model))
        hostingView.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        previewWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

if CommandLine.arguments.contains("--self-test-vpn") {
    let failures = VPNService.selfTestFailures()
    if failures.isEmpty {
        print("VPN self-test: OK (7 przypadków)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("VPN self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-sleep") {
    let failures = SleepService.selfTestFailures()
    if failures.isEmpty {
        print("Sleep self-test: OK (3 przypadki)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Sleep self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-rate-format") {
    let failures = RateFormatter.selfTestFailures()
    if failures.isEmpty {
        print("Rate format self-test: OK (stała jednostka)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Rate format self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-network") {
    let failures = NetworkProbe.selfTestFailures()
    if failures.isEmpty {
        print("Network self-test: OK (łącza fizyczne bez podwójnego VPN)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Network self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-hotspot-history") {
    let failures = TrafficHistoryStore.selfTestFailures()
    if failures.isEmpty {
        print("Hotspot history self-test: OK (dzienne sumy, retencja i reset)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Hotspot history self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-personal-hotspot") {
    let failures = PersonalHotspotStore.selfTestFailures()
    if failures.isEmpty {
        print("Personal hotspot self-test: OK (zapamiętywana nazwa telefonu)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Personal hotspot self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-wifi-selection") {
    let failures = WiFiIdentity.selfTestFailures() + WiFiSettingsDestination.selfTestFailures()
    if failures.isEmpty {
        print("Wi-Fi selection self-test: OK (aktywna sieć, nazwy SSID i panel ustawień)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Wi-Fi selection self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-navigation") {
    let failures = PulseModel.navigationSelfTestFailures()
    if failures.isEmpty {
        print("Navigation self-test: OK (pasywny powrót, pogoda zachowana)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Navigation self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-weather") {
    let failures = AirQualitySnapshot.selfTestFailures()
    if failures.isEmpty {
        print("Weather self-test: OK (jakość powietrza i format PM2.5)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Weather self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-runtime") {
    let failures = RuntimeMode.selfTestFailures()
    if failures.isEmpty {
        print("Runtime self-test: OK (podgląd nie zapisuje transferu)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Runtime self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--self-test-theme") {
    let failures = PulseTheme.selfTestFailures() + AppearanceDefaultsMigration.selfTestFailures()
    if failures.isEmpty {
        print("Theme self-test: OK (palety, ciemny kontrast i startowa opacity 100%)")
        exit(EXIT_SUCCESS)
    }
    failures.forEach { FileHandle.standardError.write(Data("Theme self-test: \($0)\n".utf8)) }
    exit(EXIT_FAILURE)
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.run()
