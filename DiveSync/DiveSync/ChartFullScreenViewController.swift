import UIKit
import DGCharts

class ChartFullScreenViewController: UIViewController {

    var chartView: LineChartView? // Được truyền từ GasDetailViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.B_3
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotate), name: UIDevice.orientationDidChangeNotification, object: nil)

        // Add chart view if available
        if let chartView = chartView {
            chartView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(chartView)

            NSLayoutConstraint.activate([
                chartView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
                chartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                chartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                chartView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
            ])
        }
    }
    
    @objc func deviceDidRotate() {
        let orientation = UIDevice.current.orientation

        switch orientation {
        case .portrait, .portraitUpsideDown:
            self.dismissSelf()
        default:
            break
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true) {
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var shouldAutorotate: Bool {
        return true
    }
}
