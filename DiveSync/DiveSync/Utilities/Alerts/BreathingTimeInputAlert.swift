import UIKit

enum BreathingTimeAlertAction {
    case cancel
    case set(minutes: Int, seconds: Int)
}

final class BreathingTimeInputAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var setButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    
    @IBOutlet weak var minLb: UILabel!
    @IBOutlet weak var minValueTf: UITextField!
    
    @IBOutlet weak var secLb: UILabel!
    @IBOutlet weak var secValueTf: UITextField!
    
    private var minutes: Int = 0
    private var seconds: Int = 0
        
    private var completion: ((_ action: BreathingTimeAlertAction) -> Void)?
    private var messageText: String? = nil
    private var setTitle: String = "Set".localized.uppercased()
    private var cancelTitle: String = "Cancel".localized.uppercased()
    
    // MARK: - Initializer
    static func showMessage(message: String? = "Breathing Time".localized,
                            minutes: Int = 0,
                            seconds: Int = 0,
                            setTitle: String = "Set".localized.uppercased(),
                            cancelTitle: String = "Cancel".localized.uppercased(),
                            completion: @escaping (_ action: BreathingTimeAlertAction) -> Void ) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "BreathingTimeInputAlert") as? BreathingTimeInputAlert else {
            return
        }
        
        alert.messageText = message
        alert.setTitle = setTitle
        alert.cancelTitle = cancelTitle
        alert.minutes = minutes
        alert.seconds = seconds
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
            self.minValueTf.becomeFirstResponder()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        minLb.text = "Minutes".localized
        secLb.text = "Seconds".localized
        
        messageLabel.text = messageText
        cancelButton.setTitle(cancelTitle, for: .normal)
        setButton.setTitle(setTitle, for: .normal)
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        minValueTf.delegate = self
        secValueTf.delegate = self
        
        minValueTf.text = "\(minutes)"
        secValueTf.text = "\(seconds)"
    }
    
    // MARK: - IBActions
    @IBAction private func setTapped(_ sender: UIButton) {
        let mins = Int(minValueTf.text ?? "") ?? 0
        let secs = Int(secValueTf.text ?? "") ?? 0
        dismiss(animated: true) {
            self.completion?(.set(minutes: mins, seconds: secs))
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            self.completion?(.cancel)
        }
    }
    
    @IBAction func clearTapped(_ sender: Any) {
        if let button = sender as? UIButton {
            let buttonTag = button.tag
            switch buttonTag {
            case 0:
                minValueTf.text = ""
            default:
                secValueTf.text = ""
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension BreathingTimeInputAlert: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Chỉ cho nhập số
                let allowedCharacters = CharacterSet.decimalDigits
                guard string.isEmpty || string.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
                    return false
                }

                // ✅ Cho phép nhập số bình thường
                let currentText = textField.text ?? ""
                let newText = (currentText as NSString).replacingCharacters(in: range, with: string)

                // ✅ Nếu là seconds field → giới hạn 0–59
                if textField == secValueTf, let value = Int(newText), value > 59 {
                    // Tự động chỉnh lại thành "59"
                    textField.text = "59"
                    return false
                }

                // ✅ Nếu là minutes thì cho thoải mái
                return true
    }
}
