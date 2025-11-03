//
//  AppDelegate.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/6/24.
//

import UIKit
import RxSwift
import RxBluetoothKit
import ProgressHUD

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
        
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Initial theme update
        ThemeManager.shared.updateCurrentTheme()
        
        // Set the global tint color for the navigation bar
        UINavigationBar.appearance().tintColor = .red // Use your desired color

        Thread.sleep(forTimeInterval: 2.0)
        
        _ = DatabaseManager.shared
        
        // Khởi tạo coordinator → scan tự chạy
        _ = BluetoothDeviceCoordinator.shared
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        PrintLog("URL: \(url)")
        if url.host == "dive" {
            if let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "token" })?.value {
                // Handle token here
                Utilities.handleSharedDive(token: token)
            }
        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

