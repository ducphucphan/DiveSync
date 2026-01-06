import UIKit

enum TankCapacityAlertAction {
    case cancel
    case set(cylinderSize: Double, workingPressure: Double)
}

final class TankCapacityInputAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    
    @IBOutlet private weak var setButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    
    @IBOutlet weak var cylinderLb: UILabel!
    @IBOutlet weak var cylinderValueTf: UITextField!
    
    @IBOutlet weak var workingLb: UILabel!
    @IBOutlet weak var workingValueTf: UITextField!
    
    @IBOutlet weak var cylinderUnitLb: UILabel!
    @IBOutlet weak var workingUnitLb: UILabel!
    
    private var cylinderSize: Double = 0
    private var workingPressure: Double = 0
    private var unitOfDive = M
        
    private var completion: ((_ action: TankCapacityAlertAction) -> Void)?
    private var messageText: String? = nil
    private var setTitle: String = "Set".localized.uppercased()
    private var cancelTitle: String = "Cancel".localized.uppercased()
    
    // MARK: - Initializer
    static func showMessage(message: String? = "Tank Capacity".localized,
                            cylinderSize: Double = 0,
                            workingPressure: Double = 0,
                            unitOfDive: Int = M,
                            setTitle: String = "Set".localized.uppercased(),
                            cancelTitle: String = "Cancel".localized.uppercased(),
                            completion: @escaping (_ action: TankCapacityAlertAction) -> Void ) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "TankCapacityInputAlert") as? TankCapacityInputAlert else {
            return
        }
        
        alert.messageText = message
        alert.setTitle = setTitle
        alert.cancelTitle = cancelTitle
        alert.cylinderSize = cylinderSize
        alert.workingPressure = workingPressure
        alert.unitOfDive = unitOfDive
        alert.completion = completion
        alert.modalPresentationStyle = .overFullScreen
        alert.modalTransitionStyle = .crossDissolve
        topVC.present(alert, animated: true)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.cylinderValueTf.becomeFirstResponder()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        cylinderLb.text = "Cylinder Size".localized
        workingLb.text = "Working Pressure".localized
        
        messageLabel.text = messageText
        cancelButton.setTitle(cancelTitle, for: .normal)
        setButton.setTitle(setTitle, for: .normal)
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        cylinderValueTf.delegate = self
        workingValueTf.delegate = self
        
        cylinderValueTf.text = formatNumber(cylinderSize)
        workingValueTf.text = formatNumber(workingPressure)
        
        if unitOfDive == M {
            cylinderUnitLb.text = "L"
            workingUnitLb.text = "BAR"
        } else {
            cylinderUnitLb.text = "CUFT"
            workingUnitLb.text = "PSI"
        }
    }
    
    // MARK: - IBActions
    @IBAction private func setTapped(_ sender: UIButton) {
        let size = Double(cylinderValueTf.text ?? "") ?? 0
        let pressure = Double(workingValueTf.text ?? "") ?? 0
        dismiss(animated: true) {
            self.completion?(.set(cylinderSize: size, workingPressure: pressure))
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            self.completion?(.cancel)
        }
    }
}

// MARK: - UITextFieldDelegate
extension TankCapacityInputAlert: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Chỉ cho nhập số
        let allowedCharacters = CharacterSet.decimalDigits
        guard string.isEmpty || string.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return false
        }
        
        // ✅ Nếu là minutes thì cho thoải mái
        return true
    }
}
