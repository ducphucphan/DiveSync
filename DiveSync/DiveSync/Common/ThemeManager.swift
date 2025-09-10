import UIKit

class ThemeManager {
    static let shared = ThemeManager()
    
    private init() {
        updateCurrentTheme()
    }
    
    var currentTheme: UIUserInterfaceStyle = .light {
        didSet {
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        }
    }
    
    func updateCurrentTheme() {
        currentTheme = UITraitCollection.current.userInterfaceStyle
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}

extension UIView {
    func setGradientBackground(colorOne: UIColor, colorTwo: UIColor) {
        // Remove the first sublayer if it exists
        if let sublayers = self.layer.sublayers, !sublayers.isEmpty, sublayers.count > 1 {
            if let gradientLayer = sublayers[0] as? CAGradientLayer {
                gradientLayer.removeFromSuperlayer()
            }
        }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height)
        gradientLayer.colors = [colorOne.cgColor, colorTwo.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.locations = [0.0, 0.3]
        
        self.layer.insertSublayer(gradientLayer, at: 0)
    }
}
