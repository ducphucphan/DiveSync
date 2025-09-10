import UIKit

final class SortAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var allowButton: UIButton!
    @IBOutlet private weak var denyButton: UIButton!
    @IBOutlet private weak var favoriteOnlyButton: UIButton!
    
    @IBOutlet weak var pickerViewLeft: UIPickerView!
    
    @IBOutlet weak var pickerViewRight: UIPickerView!
    
    private var leftOptions = ["Increasing", "Decreasing"]
    private var rightOptions = ["Date", "Max Depth", "Dive Time"]
    
    private var selectedLeft = 0
    private var selectedRight = 0
    
    private var completion: ((PrivacyAlertAction) -> Void)?
    private var messageText: String = ""
    private var allowTitle: String = "ALLOW"
    private var denyTitle: String = "DENY"
    
    var isFavoriteOnly = false
    
    private var completionOptions: ((SortOptions?) -> Void)?
    private var initialOptions: SortOptions = SortPreferences.load() // fallback nếu chưa set
    
    // MARK: - Initializer
    static func showMessage(message: String,
                            allowTitle: String = "ALLOW",
                            denyTitle: String = "DENY",
                            currentOptions: SortOptions,
                            completion: @escaping (SortOptions?) -> Void) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "SortAlert") as? SortAlert else {
            return
        }
        
        alert.messageText = message
        alert.allowTitle = allowTitle
        alert.denyTitle = denyTitle
        alert.completionOptions = completion
        alert.initialOptions = currentOptions
        
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
        
        pickerViewRight.dataSource = self
        pickerViewRight.delegate = self
        
        // Dựa vào initialOptions
        selectedLeft = (initialOptions.direction == .increasing) ? 0 : 1
        switch initialOptions.field {
        case .date: selectedRight = 0
        case .maxDepth: selectedRight = 1
        case .diveTime: selectedRight = 2
        }
        
        isFavoriteOnly = initialOptions.favoritesOnly
        updateFavoriteUI()
        
        pickerViewLeft.selectRow(selectedLeft, inComponent: 0, animated: false)
        pickerViewRight.selectRow(selectedRight, inComponent: 0, animated: false)
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
        ])
        
    }
    
    // MARK: - IBActions
    @IBAction private func sortTapped(_ sender: UIButton) {
        let direction: SortDirection = (selectedLeft == 0) ? .increasing : .decreasing
        let field: SortField = {
            switch selectedRight {
            case 0: return .date
            case 1: return .maxDepth
            case 2: return .diveTime
            default: return .date
            }
        }()
        
        let options = SortOptions(direction: direction, field: field, favoritesOnly: isFavoriteOnly)
        SortPreferences.save(options)
        
        dismiss(animated: true) {
            self.completionOptions?(options)
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            self.completionOptions?(nil)
        }
    }
    
    @IBAction func favoriteOnlyTapped(_ sender: Any) {
        isFavoriteOnly.toggle()
        updateFavoriteUI()
    }
    
    private func updateFavoriteUI() {
        let imageName = isFavoriteOnly ? "checked1" : "uncheck"
        let tintColor = isFavoriteOnly ? UIColor.B_1 : UIColor.white
        favoriteOnlyButton.setImage(UIImage(named: imageName), for: .normal)
        favoriteOnlyButton.tintColor = tintColor
    }
}

extension SortAlert: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30 // hoặc giá trị bạn muốn
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return (pickerView == pickerViewLeft) ? leftOptions.count:rightOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.textAlignment = .center
        
        var selectedRow = selectedLeft
        if pickerView == pickerViewLeft {
            label.text = leftOptions[row]
        } else {
            label.text = rightOptions[row]
            selectedRow = selectedRight
        }
        
        if row == selectedRow {
            label.textColor = .white
            label.font = UIFont.boldSystemFont(ofSize: 20)
        } else {
            label.textColor = .lightGray
            label.font = UIFont.systemFont(ofSize: 18)
        }
        
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == pickerViewLeft {
            selectedLeft = row
        } else {
            selectedRight = row
        }
        pickerView.reloadAllComponents() // Update appearance
    }
}
