import UIKit

final class ItemSelectionAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    
    @IBOutlet private weak var setBtn: UIButton!
    @IBOutlet private weak var cancelBtn: UIButton!
    
    @IBOutlet weak var notesLabel: UILabel!
    
    @IBOutlet weak var pickerViewLeft: UIPickerView!
    
    private var options: [String] = []
    private var selectedValue: String?
    private var selectedIndex: Int?
    
    private var initialIndex: Int = 0
    
    private var completionWithValue: ((_ action: PrivacyAlertAction, _ selectedValue: String?, _ selectedIndex: Int?) -> Void)?
    private var messageText: String = ""
    private var setTitle: String = "Set".localized.uppercased()
    private var cancelTitle: String = "Cancel".localized.uppercased()
    
    private var notes: String? = "GF"
    
    // MARK: - Initializer
    static func showMessage(message: String,
                            options: [String],
                            selectedValue: String?,
                            notesValue: String? = nil,
                            setTitle: String = "Set".localized.uppercased(),
                            cancelTitle: String = "Cancel".localized.uppercased(),
                            completion: @escaping (_ action: PrivacyAlertAction, _ selectedValue: String?, _ selectedIndex: Int?) -> Void ) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "ItemSelectionAlert") as? ItemSelectionAlert else {
            return
        }
        
        alert.messageText = message
        alert.setTitle = setTitle
        alert.notes = notesValue
        alert.cancelTitle = cancelTitle
        alert.options = options
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
        
        // Picker
        pickerViewLeft.dataSource = self
        pickerViewLeft.delegate = self
        
        messageLabel.text = messageText
        setBtn.setTitle(setTitle, for: .normal)
        cancelBtn.setTitle(cancelTitle, for: .normal)
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Convert selectedValue to selectedIndex if needed
        if let selectedValue = selectedValue,
           let index = options.firstIndex(of: selectedValue) {
            selectedIndex = index
            initialIndex = index
        } else {
            selectedIndex = 0
            initialIndex = 0
        }
        
        if notes == nil {
            notesLabel.isHidden = true
        } else {
            notesLabel.isHidden = false
        }
        
        showGFValues()
        
        pickerViewLeft.selectRow(selectedIndex ?? 0, inComponent: 0, animated: false)
    }
    
    // MARK: - IBActions
    @IBAction private func setTapped(_ sender: UIButton) {
        guard selectedIndex != initialIndex else {
            // Optional: Có thể rung nhẹ, hoặc hiển thị cảnh báo người dùng
            PrintLog("Giá trị không thay đổi, không thực hiện hành động.")
            dismiss(animated: true) {}
            return
        }
        
        dismiss(animated: true) {
            self.completionWithValue?(.allow, self.selectedValue, self.selectedIndex)
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            //self.completionWithValue?(.deny, self.selectedValue, self.selectedIndex)
        }
    }
}

extension ItemSelectionAlert: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30 // hoặc giá trị bạn muốn
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return options.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.text = options[row]
        label.textAlignment = .center
        label.textColor = (row == selectedIndex) ? .white : .lightGray
        label.font = (row == selectedIndex) ? .boldSystemFont(ofSize: 20) : .systemFont(ofSize: 18)
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedIndex = row
        selectedValue = options[row]
        
        showGFValues()
        
        pickerView.reloadAllComponents()
    }
    
    func showGFValues() {
        if let notes = notes, notes == "GF" {
            switch selectedIndex {
            case 0:
                notesLabel.text = "GF High".localized + ": 90, " + "GF Low".localized + ": 90"
            case 1:
                notesLabel.text = "GF High".localized + ": 85, " + "GF Low".localized + ": 35"
            case 2:
                notesLabel.text = "GF High".localized + ": 70, " + "GF Low".localized + ": 35"
            default:
                break
            }
        }
    }
}
