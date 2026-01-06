//
//  LocationPermissionManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/26/25.
//

import CoreLocation
import UIKit

class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionManager()

    private let locationManager = CLLocationManager()
    private var completion: ((Bool) -> Void)?

    func requestLocationPermission(from viewController: UIViewController? = nil, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        locationManager.delegate = self

        // Hiển thị alert tùy chỉnh
        PrivacyAlert.showMessage(
            message: "Allow DIVESYNC to access this device’s location.".localized,
            allowTitle: "ALLOW".localized,
            denyTitle: "DENY".localized
        ) { action in
            switch action {
            case .allow:
                self.locationManager.requestWhenInUseAuthorization()
            case .deny:
                completion(false)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            completion?(true)
        case .denied, .restricted:
            completion?(false)
        default:
            break
        }
    }
}
