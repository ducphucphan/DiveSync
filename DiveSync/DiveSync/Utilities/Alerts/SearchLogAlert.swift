import UIKit
final class SearchLogAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var allowButton: UIButton!
    @IBOutlet private weak var denyButton: UIButton!
    @IBOutlet private weak var favoriteOnlyButton: UIButton!
    
    @IBOutlet weak var pickerViewLeft: UIPickerView!
    
    private var leftOptions = ["Increasing".localized, "Decreasing".localized, "Counting".localized, "Nha Trang City"]
    
    private var selectedLeft = 0
    
    private var completion: ((PrivacyAlertAction) -> Void)?
    private var messageText: String = ""
    private var allowTitle: String = "ALLOW".localized
    private var denyTitle: String = "DENY".localized
    
    var isFavoriteOnly = false
    
    // MARK: - Initializer
    static func showMessage(message: String,
                            allowTitle: String = "ALLOW".localized,
                            denyTitle: String = "DENY".localized,
                            completion: @escaping (PrivacyAlertAction) -> Void) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "SearchLogAlert") as? SearchLogAlert else {
            return
        }
        
        alert.messageText = message
        alert.allowTitle = allowTitle
        alert.denyTitle = denyTitle
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
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        // Picker
        // Picker
        pickerViewLeft.dataSource = self
        pickerViewLeft.delegate = self
        
        // Select default if needed
        pickerViewLeft.selectRow(selectedLeft, inComponent: 0, animated: false)
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
        ])
        
    }
    
    // MARK: - IBActions
    @IBAction private func sortTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            self.completion?(.allow)
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            self.completion?(.deny)
        }
    }
    
    @IBAction func favoriteOnlyTapped(_ sender: Any) {
        isFavoriteOnly.toggle()
        
        let imageName = isFavoriteOnly ? "checked1" : "uncheck"
        let tintColor = isFavoriteOnly ? UIColor.B_1 : UIColor.white
        
        favoriteOnlyButton.setImage(UIImage(named: imageName), for: .normal)
        favoriteOnlyButton.tintColor = tintColor
    }
}

extension SearchLogAlert: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30 // hoặc giá trị bạn muốn
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return leftOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.textAlignment = .center
        
        var selectedRow = selectedLeft
        
        label.text = leftOptions[row]
        
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
        selectedLeft = row
        pickerView.reloadAllComponents() // Update appearance
    }
}
