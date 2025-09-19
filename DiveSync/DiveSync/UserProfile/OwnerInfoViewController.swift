//
//  OwnerInfoViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/27/25.
//

import UIKit

// ProfileFieldType.swift (hoặc trong cùng file nếu đơn giản)
enum ProfileFieldType {
    case cert
    case plainText
    case phone
    case date
    case mail
    case valueWithUnit(units: [String])
    
    static func type(for key: String) -> ProfileFieldType {
        switch key {
        case "cert":
            return .cert
        case "phone":
            return .phone
        case "emergency_contact_phone":
            return .phone
        case "birthdate":
            return .date
        case "mail":
            return .mail
        default:
            return .plainText
        }
    }
}


class OwnerInfoViewController: BaseViewController {
    
    @IBOutlet weak var userView: UIView!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var userImv: UIImageView!
    @IBOutlet weak var nameLb: UILabel!
    
    let titleData = ["Weight", "Height", "Gender", "Blood Type", "Birth Date", "Address",
                     "City", "State/Province", "Zip/Post Code", "Phone Number",
                     "E-mail", "Certifications", "Emergency Contact Name", "Emergency Contact Phone"]
    
    let keys = ["weight", "height", "gender", "blood_type", "birthdate", "address",
                "city", "state_province", "zipcode", "phone", "mail", "cert",
                "emergency_contact_name", "emergency_contact_phone"]
    
    var profileValues: [String: Any] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        userView.layer.borderColor = UIColor.B_3.cgColor
        
        let avatarPath = HomeDirectory().appendingFormat("%@", USERINFO_DIR) + "avatar.png"
        userImv.image = UIImage(contentsOfFile: avatarPath)
        
        // Register the default cell
        tableView.backgroundColor = .clear
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
        
        if let userInfos = DatabaseManager.shared.runSQL("select * from userinfo WHERE id=1"), userInfos.count > 0 {
            self.profileValues = userInfos.first ?? [:]
            self.nameLb.text = self.profileValues.string(for: "fullname", default: "John Doe")
        }
    }
    
    @IBAction func editUserName(_ sender: Any) {
        InputAlert.show(title: "What is your name?", currentValue: nameLb.text ?? "") { action in
            switch action {
            case .save(let value):
                
                self.nameLb.text = value
                DatabaseManager.shared.updateTable(tableName: "userinfo",
                                                   params: ["fullname":value ?? ""])
            default:
                break
            }
        }
    }
    
    @IBAction func choosePhoto(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let cameraPicker = UIImagePickerController()
                cameraPicker.sourceType = .camera
                cameraPicker.delegate = self
                self.present(cameraPicker, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: nil, message: "Camera could not available for this device!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        let albumsAction = UIAlertAction(title: "Albums", style: .default) { _ in
            let albumPicker = UIImagePickerController()
            albumPicker.sourceType = .photoLibrary
            albumPicker.delegate = self
            self.present(albumPicker, animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(cameraAction)
        actionSheet.addAction(albumsAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func shareTapped(_ sender: Any) {
        
        Utilities.share(items: ["What do you want to share?"], from: self)
        
    }
}

extension OwnerInfoViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        let key = keys[indexPath.row]
        let fieldType = ProfileFieldType.type(for: key)
        switch fieldType {
        case .cert:
            cell.bindCell(title: titleData[indexPath.row], value: "", imageName: "cetificate")
            cell.accessoryType = .disclosureIndicator
        default:
            let value = profileValues[key]
            let displayValue: String
            if let stringValue = value as? String, !stringValue.isEmpty {
                displayValue = stringValue
            } else {
                displayValue = "-"
            }
            cell.bindCell(title: titleData[indexPath.row], value: displayValue)
        }
        
        cell.backgroundColor = .clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < titleData.count else { return }
        guard let cell = tableView.cellForRow(at: indexPath) as? BaseTableViewCell else { return }
        
        let key = keys[indexPath.row]
        let titleText = cell.titleLabel.text ?? ""
        let currentValue = cell.valueLabel.text ?? ""
        let fieldType = ProfileFieldType.type(for: key)
        
        switch fieldType {
        case .plainText:
            InputAlert.show(title: titleText, currentValue: currentValue) { action in
                switch action {
                case .save(let value):
                    self.updateValue(value ?? "", at: indexPath)
                default:
                    break
                }
            }
            
        case .phone:
            InputAlert.show(title: titleText, currentValue: currentValue, keyboardType: .phonePad) { action in
                switch action {
                case .save(let value):
                    self.updateValue(value ?? "", at: indexPath)
                default:
                    break
                }
            }
            
        case .mail:
            InputAlert.show(title: titleText, currentValue: currentValue, keyboardType: .emailAddress) { action in
                switch action {
                case .save(let value):
                    self.updateValue(value ?? "", at: indexPath)
                default:
                    break
                }
            }
            
        case .date:
            EditProfilePopupManager.showBirthDatePicker(
                in: self,
                title: titleText,
                currentValue: currentValue,
                onSave: { [weak self] newDateString in
                    self?.updateValue(newDateString, at: indexPath)
                }
            )
            break
        case .valueWithUnit(_):
            InputAlert.show(title: titleText, currentValue: currentValue, keyboardType: .phonePad) { action in
                switch action {
                case .save(let value):
                    self.updateValue(value ?? "", at: indexPath)
                default:
                    break
                }
            }
            /*
            EditProfilePopupManager.showValueWithUnitPicker(
                in: self,
                title: title,
                currentValue: currentValue,
                units: units,
                selectedUnitIndex: 0,
                onSave: { [weak self] value, unit in
                    self?.updateValue("\(value) \(unit)", at: indexPath)
                }
            )
            */
        case .cert:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "CertificationsViewController") as! CertificationsViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
    private func updateValue(_ newValue: String, at indexPath: IndexPath) {
        let key = keys[indexPath.row]
        let value = newValue
        
        DatabaseManager.shared.updateTable(tableName: "userinfo",
                                           params: [key:newValue])
        
        profileValues[key] = value
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension OwnerInfoViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            
            let (_, _) = Utilities.saveOriginalSelectedImage(image, createImageDate: nil, dir: USERINFO_DIR, name: "avatar.png")
            self.userImv.image = image
            
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
