//
//  CertificationViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/4/25.
//

import UIKit
import GRDB
import ProgressHUD

enum EditMode {
    case add(maxId: Int)
    case edit(item: Row) // Truyền đối tượng cần edit vào đây
    
    static func == (lhs: EditMode, rhs: EditMode) -> Bool {
        switch (lhs, rhs) {
        case let (.add(lMax), .add(rMax)):
            return lMax == rMax
        case let (.edit(lItem), .edit(rItem)):
            return lItem == rItem
        default:
            return false
        }
    }
}

class CertificationViewController: BaseViewController {

    @IBOutlet weak var certVew: UIView!
    
    @IBOutlet weak var certBtn: UIButton!
    
    @IBOutlet weak var imv: UIImageView!
    
    @IBOutlet weak var titleLb: UILabel!
    @IBOutlet weak var dateValueLb: UILabel!
    @IBOutlet weak var certValueLb: UILabel!
    
    @IBOutlet weak var addView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var cancelView: UIView!
    
    var titleText = "Add certificate"
    var mode: EditMode = .add(maxId: 0)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Certification",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        certVew.layer.borderColor = UIColor.darkGray.cgColor
        
        titleLb.text = titleText
        
        switch mode {
        case .add:
            deleteView.isHidden = true
        case .edit(let item):
            fillData(row: item)
        }
    }
    
    private func fillData(row: Row) {
        certValueLb.text = row["levels"]
        dateValueLb.text = row["dates"]
        
        if let imageName = row["imagepathfront"] as? String {
            let imageNamePath = HomeDirectory().appendingFormat("%@", USERINFO_DIR) + imageName
            imv.image = UIImage(contentsOfFile: imageNamePath)
        } else {
            imv.image = nil
        }
    }
    
    @IBAction func addImageTapped(_ sender: Any) {
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
    
    @IBAction func dateTapped(_ sender: Any) {
        EditProfilePopupManager.showBirthDatePicker(
            in: self,
            title: "Date",
            currentValue: dateValueLb.text ?? "",
            onSave: { [weak self] newDateString in
                guard let self = self else { return }
                self.dateValueLb.text = newDateString
            }
        )
    }
    
    @IBAction func countryTapped(_ sender: Any) {
        let currentValue = certValueLb.text ?? ""
        InputAlert.show(title: "Enter your cetificate", currentValue: currentValue) { action in
            switch action {
            case .save(let value):
                self.certValueLb.text = value
            default:
                break
            }
        }
    }
    
    @IBAction func saveTapped(_ sender: Any) {
        updateCert(mode: mode)
    }
    
    @IBAction func deleteTapped(_ sender: Any) {
        PrivacyAlert.showMessage(
            message: "Are you sure you want to delete certification?",
            allowTitle: "DELETE",
            denyTitle: "CANCEL"
        ) { action in
            switch action {
            case .allow:
                if case let .edit(item) = self.mode {
                    if let id = item["id"] as? Int64 {
                        DatabaseManager.shared.deleteRows(from: "certificate", where: "id=?", arguments: [id])
                        if let imageName = item["imagepathfront"] as? String {
                            let imageNamePath = HomeDirectory().appendingFormat("%@", USERINFO_DIR) + imageName
                            if FileManager.default.fileExists(atPath: imageNamePath) {
                                try? FileManager.default.removeItem(atPath: imageNamePath)
                            }
                        }
                        
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            case .deny:
                break
            }
        }
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    private func updateCert(mode: EditMode) {
        guard let certName = certValueLb.text, !certName.isEmpty, certName != "-" else { return }
        guard let certDate = dateValueLb.text, !certDate.isEmpty, certDate != "-" else { return }
        
        var properties: [String:Any] = [:]
        properties["dates"] = certDate
        properties["levels"] = certName
        
        switch mode {
        case .add(let maxId):
            let certImageName = String(format: "cert_%02i.png", maxId+1)
            if let image = imv.image {
                _ = Utilities.saveSelectedImage(image, createImageDate: Date(), dir: USERINFO_DIR, name: certImageName)
                
                properties["imagepathfront"] = certImageName
            }
            
            _ = DatabaseManager.shared.insertIntoTable(tableName: "certificate", params: properties)
        case .edit(let item):
            let certImageName = String(format: "cert_%02i.png", item.intValue(key: "id"))
            if let image = imv.image {
                _ = Utilities.saveSelectedImage(image, createImageDate: Date(), dir: USERINFO_DIR, name: certImageName)
                
                properties["imagepathfront"] = certImageName
            }
            
            DatabaseManager.shared.updateTable(tableName: "certificate",
                                               params: properties,
                                               conditions: "where id=\(item.intValue(key: "id"))")
        }
        
        ProgressHUD.animate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ProgressHUD.dismiss()
            self.navigationController?.popViewController(animated: true)
        }
        
    }
}

extension CertificationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            imv.image = image
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
