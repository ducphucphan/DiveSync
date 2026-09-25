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
import Siren

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
        
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let siren = Siren.shared
        
        // Cấu hình loại thông báo (Bắt buộc cập nhật hoặc Cho phép bỏ qua)
        siren.rulesManager = RulesManager(
            globalRules: .annoying, // Hiển thị alert mỗi khi mở app nếu chưa update
            showAlertAfterCurrentVersionHasBeenReleasedForDays: 0
        )
        
        // 2. Tùy chỉnh Nội dung Alert (Title, Message, Buttons) theo đúng yêu cầu khách hàng
        let alertTitle = "New version available".localized
        let alertMessage = "A newer version of the app is available. Update now to get the latest features and improvements.".localized
        let updateButtonTitle = "Update now".localized
        let nextTimeButtonTitle = "Later".localized
        
        siren.presentationManager = PresentationManager(
            alertTitle: alertTitle,
            alertMessage: alertMessage,
            updateButtonTitle: updateButtonTitle,
            nextTimeButtonTitle: nextTimeButtonTitle
        )
        
        
        // Initial theme update
        ThemeManager.shared.updateCurrentTheme()
        
        // Set the global tint color for the navigation bar
        UINavigationBar.appearance().tintColor = .red // Use your desired color

        Thread.sleep(forTimeInterval: 2.0)
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupProgressHUDAppearance()
        
        siren.wail { [weak self] results in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch results {
                case .success(let updateResults):
                    print("Siren update result: \(updateResults)")
                    
                    switch updateResults.updateType {
                    case .major, .minor, .patch, .revision:
                        // CÓ PHIÊN BẢN MỚI
                        // Kiểm tra xem người dùng đã tương tác với Alert thế nào:
                        switch updateResults.alertAction {
                        case .nextTime, .skip:
                            // NGƯỜI DÙNG BẤM [Later]
                            print("Người dùng chọn Later -> Tiến hành khởi tạo dịch vụ.")
                            self.initializeCoreServices()
                            
                        case .appStore:
                            // NGƯỜI DÙNG BẤM [Update now]
                            // App sẽ tự động mở App Store. KHÔNG gọi initializeCoreServices()
                            print("Người dùng chọn Update now -> Đã chuyển sang App Store.")
                            return
                            
                        case .unknown:
                            // Alert vừa hiển thị, chờ người dùng bấm nút
                            print("Alert đang hiển thị, chờ người dùng chọn...")
                            return
                        }
                        
                    case .unknown:
                        // KHÔNG CÓ BẢN MỚI (Đã ở bản mới nhất)
                        print("Ứng dụng đang ở phiên bản mới nhất.")
                        self.initializeCoreServices()
                    }
                    
                case .failure(let error):
                    print("Siren error: \(error.localizedDescription)")
                    // Khi lỗi mạng hoặc lỗi API -> Cho phép khởi chạy dịch vụ
                    self.initializeCoreServices()
                }
            }
        }
        
        return true
    }
    
    private func initializeCoreServices() {
        _ = DatabaseManager.shared
        
        // Khởi tạo coordinator → scan tự chạy
        _ = BluetoothDeviceCoordinator.shared
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
    
    private func setupProgressHUDAppearance() {
        // 1. Màu nền của khung HUD
        ProgressHUD.colorHUD = UIColor.B_3
        
        // 2. Màu chữ (Status message)
        ProgressHUD.colorStatus = .white
        
        // 3. Màu hiệu ứng spinner / indicator
        ProgressHUD.colorAnimation = .white
        
        // 4. Màu lớp phủ nền toàn màn hình
        ProgressHUD.colorBackground = UIColor.black.withAlphaComponent(0.3)
        
        // 5. Màu thanh tiến trình (nếu có dùng dạng progress)
        ProgressHUD.colorProgress = .white
    }
}

