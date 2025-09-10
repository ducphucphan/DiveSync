import UIKit

final class MDepthInputAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    
    @IBOutlet weak var notesLabel: UILabel!
    @IBOutlet weak var unitLb: UILabel!
    @IBOutlet weak var valueTf: UITextField!
    
    private var selectedValue: String = "0"
        
    private var completionWithValue: ((_ action: PrivacyAlertAction, _ selectedValue: String) -> Void)?
    private var messageText: String? = nil
    private var setTitle: String = "SET"
    private var cancelTitle: String = "CANCEL"
    private var unitValue: String = "M"
    private var notes: String? = "GF"
    
    private var blinkTimer: Timer?
    
    deinit {
        stopBlinkingNotes()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.valueTf.becomeFirstResponder()
        }
    }
    
    // MARK: - Initializer
    static func showMessage(message: String? = "Max Depth",
                            selectedValue: String,
                            notesValue: String? = nil,
                            unitValue: String,
                            setTitle: String = "SET",
                            cancelTitle: String = "CANCEL",
                            completion: @escaping (_ action: PrivacyAlertAction, _ selectedValue: String) -> Void ) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "MDepthInputAlert") as? MDepthInputAlert else {
            return
        }
        
        alert.messageText = message
        alert.setTitle = setTitle
        alert.notes = notesValue
        alert.unitValue = unitValue
        alert.cancelTitle = cancelTitle
        alert.selectedValue = selectedValue
        alert.completionWithValue = completion
        alert.modalPresentationStyle = .overFullScreen
        alert.modalTransitionStyle = .crossDissolve
        topVC.present(alert, animated: true)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        messageLabel.text = messageText
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        notesLabel.isHidden = false
        
        valueTf.delegate = self
        valueTf.addTarget(self, action: #selector(textFieldValueChanged), for: .editingChanged)
        
        notesLabel.text = notes
        unitLb.text = unitValue
        valueTf.text = selectedValue
    }
    
    private func startBlinkingNotes() {
        stopBlinkingNotes()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.3) {
                self.notesLabel.alpha = self.notesLabel.alpha == 1 ? 0 : 1
            }
        }
    }

    private func stopBlinkingNotes() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        notesLabel.alpha = 1
    }
    
    // MARK: - IBActions
    @IBAction private func setTapped(_ sender: UIButton) {
        let value = Double(valueTf.text ?? "") ?? 0
        if unitValue.uppercased() == "M" && (value < 0 || value > 999.9) {
            // Có thể rung hoặc show alert
            return
        }
        if unitValue.uppercased() == "FT" && (value < 0 || value > 3300) {
            return
        }
        
        dismiss(animated: true) {
            var returnValue = self.valueTf.text ?? "0"
            if returnValue.isEmpty {
                returnValue = "0"
            }
            self.completionWithValue?(.allow, returnValue)
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            //self.completionWithValue?(.deny, self.selectedValue, self.selectedIndex)
        }
    }
    
    @IBAction func clearTapped(_ sender: Any) {
        
        valueTf.text = ""
        
    }
}

extension MDepthInputAlert: UITextFieldDelegate {
    @objc private func textFieldValueChanged(_ textField: UITextField) {
        
        if notes == nil {return}
        
        let text = textField.text ?? ""
        let value = Double(text) ?? -1
        var isValid = true
        
        if unitValue.uppercased() == "M" {
            isValid = (value >= 0 && value <= 999.9)
        } else if unitValue.uppercased() == "FT" {
            isValid = (value >= 0 && value <= 3300)
        }
        
        if isValid {
            stopBlinkingNotes()
        } else {
            startBlinkingNotes()
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        return string.isEmpty || string.rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }
}
