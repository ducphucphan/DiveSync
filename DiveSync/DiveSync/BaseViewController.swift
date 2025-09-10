import UIKit
import SwiftHEXColors

class BaseViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //NotificationCenter.default.addObserver(self, selector: #selector(handleThemeChange), name: .themeDidChange, object: nil)
        //handleThemeChange()
        
        //setBackgroundImage()
        setupNavigationBar()
        setupRightBarItem()
    }
    
    private func setupRightBarItem() {
        /*
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: [.white, .red])
        let sizeConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        let finalConfig = sizeConfig.applying(paletteConfig)
        
        let image = UIImage(systemName: "sos.circle.fill")?.withConfiguration(finalConfig)
        
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.tintColor = .red // Dự phòng nếu palette không được áp dụng
        button.addTarget(self, action: #selector(rightBarButtonTapped), for: .touchUpInside)
        
        let rightItem = UIBarButtonItem(customView: button)
        navigationItem.rightBarButtonItem = rightItem
        */
    }
    
    @objc func rightBarButtonTapped() {
        PrintLog("Right bar item tapped!")
        // Thêm hành động bạn muốn ở đây
    }
    
    private func setBackgroundImage() {
        let backgroundImage = UIImageView(frame: UIScreen.main.bounds)
        backgroundImage.image = UIImage(named: "app_background") // Replace with your image name
        backgroundImage.contentMode = .scaleAspectFill
        backgroundImage.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImage)
        view.sendSubviewToBack(backgroundImage)
        
        // Constraints to make the image fill the screen
        NSLayoutConstraint.activate([
            backgroundImage.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImage.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImage.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        // Tạo navigation bar appearance mới
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground() // Không cho trong suốt
        appearance.backgroundColor = UIColor.B_3 // Hoặc màu bạn muốn
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        // Gán cho navigation bar
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        view.backgroundColor = UIColor.BG
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            ThemeManager.shared.updateCurrentTheme()
        }
    }
    
    @objc private func handleThemeChange() {
        
        if ThemeManager.shared.currentTheme == .dark {
            view.backgroundColor = .black
            
            self.view.setGradientBackground(colorOne: UIColor.red.withAlphaComponent(1.0),
                                            colorTwo: UIColor.red.withAlphaComponent(0.05))
            
            // Apply dark mode theme settings
        } else {
            view.backgroundColor = UIColor(hex: "#EEEEEE")
            
            self.view.setGradientBackground(colorOne: UIColor(hex: "0x01BBDA"),
                                            colorTwo: UIColor(hex: "0xEEEEEE"))
            // Apply light mode theme settings
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .themeDidChange, object: nil)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }
}
