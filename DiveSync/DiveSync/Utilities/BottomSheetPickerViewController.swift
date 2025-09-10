import UIKit

class BottomSheetPickerViewController: UIViewController {
    
    // MARK: - Public Properties
    var items: [String] = []
    var selectedIndex: Int?
    var sheetTitle: String? = nil
    var cancelTitle: String = "Cancel"
    var setTitle: String = "Set"
    var onValueChanged: ((Int, String) -> Void)?
    
    // MARK: - UI Components
    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let setButton = UIButton(type: .system)
    private let pickerView = UIPickerView()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
    }
    
    func presentBottomSheetOn(_ inViewController: UIViewController, animated: Bool = true) {
        if let sheet = self.presentationController as? UISheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        inViewController.present(self, animated: animated)
    }
    
    private func setupViews() {
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        
        // Top Bar
        topBar.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        view.addSubview(topBar)
        
        titleLabel.text = sheetTitle
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        topBar.addSubview(titleLabel)
        
        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        topBar.addSubview(cancelButton)
        
        setButton.setTitle(setTitle, for: .normal)
        setButton.addTarget(self, action: #selector(setTapped), for: .touchUpInside)
        topBar.addSubview(setButton)
        
        // Picker
        pickerView.dataSource = self
        pickerView.delegate = self
        view.addSubview(pickerView)
        
        // Select default if needed
        if let selectedIndex = selectedIndex {
            pickerView.selectRow(selectedIndex, inComponent: 0, animated: false)
        }
    }
    
    private func setupConstraints() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        setButton.translatesAutoresizingMaskIntoConstraints = false
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: cancelButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: setButton.leadingAnchor, constant: -8),
            
            cancelButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            cancelButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            setButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            setButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            pickerView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pickerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func setTapped() {
        let index = pickerView.selectedRow(inComponent: 0)
        guard index != selectedIndex else {
            dismiss(animated: true)
            return
        }
        onValueChanged?(index, items[index])
        dismiss(animated: true)
    }
}

extension BottomSheetPickerViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return items.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return items[row]
    }
}
