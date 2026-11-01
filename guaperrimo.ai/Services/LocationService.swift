//
//  LocationService.swift
//  guaperrimo.ai
//

#if os(iOS)
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "Location")

/// A device fix the backend uses to find stores near the user.
/// Encoded as `location: {lat, lng, label}` on every chat turn.
nonisolated struct DeviceLocation: Codable, Sendable, Equatable {
    let lat: Double
    let lng: Double
    var label: String? = nil
}

/// Asks for when-in-use permission once and takes a single fix. The session
/// attaches it to every chat turn so the server never has to ask where the
/// user is; when the user declines, the server asks in the conversation.
@Observable
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case notDetermined
        case denied
        case locating
        case located
        case failed
    }

    private(set) var status: Status = .notDetermined
    private(set) var fix: DeviceLocation?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<DeviceLocation?, Never>?
    private var timeoutTask: Task<Void, Never>?

    /// A fix that takes longer than this is not worth delaying the first turn for.
    private let fixTimeout: Duration = .seconds(6)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if case .denied = Self.status(for: manager.authorizationStatus) {
            status = .denied
        }
    }

    /// True until the system permission alert has been shown once.
    var canAsk: Bool { manager.authorizationStatus == .notDetermined }

    var isAuthorized: Bool {
        manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    /// Requests permission if needed and resolves with one fix, or nil when the
    /// user denies, location fails or the fix takes too long. The label is
    /// filled in afterwards by reverse geocoding so the first turn is not delayed.
    func requestFix() async -> DeviceLocation? {
        if let fix { return fix }
        if status == .denied { return nil }
        if continuation != nil { return nil } // a request is already in flight
        status = .locating
        return await withCheckedContinuation { cont in
            continuation = cont
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: fixTimeout)
                guard let self, !Task.isCancelled else { return }
                logger.warning("⏰ Location fix timed out")
                self.status = .failed
                self.finish(nil)
            }
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization() // continues in locationManagerDidChangeAuthorization
            } else if isAuthorized {
                manager.requestLocation()
            } else {
                status = .denied
                finish(nil)
            }
        }
    }

    private func finish(_ result: DeviceLocation?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(returning: result)
        continuation = nil
    }

    private static func status(for auth: CLAuthorizationStatus) -> Status {
        switch auth {
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    /// "Roma Norte, Ciudad de México" when the geocoder knows the place.
    private func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let place = placemarks.first else { return nil }
            let parts = [place.subLocality, place.locality].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } catch {
            logger.warning("Reverse geocoding failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        Task { @MainActor in
            switch auth {
            case .authorizedWhenInUse, .authorizedAlways:
                logger.info("📍 Location permission granted")
                if continuation != nil {
                    manager.requestLocation()
                }
            case .denied, .restricted:
                logger.info("📍 Location permission denied")
                status = .denied
                finish(nil)
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        Task { @MainActor in
            let fix = DeviceLocation(lat: coordinate.latitude, lng: coordinate.longitude)
            self.fix = fix
            status = .located
            logger.info("📍 Fix: \(coordinate.latitude, privacy: .private) , \(coordinate.longitude, privacy: .private)")
            finish(fix)
            if let label = await reverseGeocode(location) {
                self.fix = DeviceLocation(lat: fix.lat, lng: fix.lng, label: label)
                logger.info("📍 Label: \(label, privacy: .private)")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.warning("📍 Location failed: \(String(describing: error), privacy: .public)")
            status = .failed
            finish(nil)
        }
    }
}
#endif
