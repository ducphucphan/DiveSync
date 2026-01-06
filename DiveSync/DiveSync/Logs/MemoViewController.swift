//
//  MemoViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/7/25.
//

import UIKit
import GRDB

class MemoViewController: BaseViewController, UITextViewDelegate {

    @IBOutlet weak var memoTv: UITextView!
    @IBOutlet weak var saveLb: UILabel!
    @IBOutlet weak var deleteLb: UILabel!
    @IBOutlet weak var cancelLb: UILabel!
    
    var diveLog: Row!
    
    var onUpdated:(() -> Void)?
    
    let placeholderText = "Tap here to input memo".localized
    let placeholderColor = UIColor.lightGray
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Memo".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        saveLb.text = "SAVE".localized.capitalized
        deleteLb.text = "Delete".localized
        cancelLb.text = "Cancel".localized
        
        memoTv.delegate = self
        memoTv.returnKeyType = .done // tuỳ chọn nếu bạn muốn có nút "Done"
        
        // Load memo
        memoTv.text = diveLog.stringValue(key: "Memo")
        
        if memoTv.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            memoTv.text = placeholderText
            memoTv.textColor = placeholderColor
        }
    }

    @IBAction func buttonAction(_ sender: Any) {
        if let button = sender as? UIButton {
            let buttonTag = button.tag
            switch buttonTag {
            case 0:
                saveMemo()
            case 1:
                PrivacyAlert.showMessage(
                    message: "Are you sure you want to clear the memo?".localized,
                    allowTitle: "Delete".localized.uppercased(),
                    denyTitle: "Cancel".localized.uppercased()
                ) { action in
                    switch action {
                    case .allow:
                        // Clear memo
                        self.memoTv.text = ""
                        
                        // Save Memo
                        self.saveMemo()
                    case .deny:
                        break
                    }
                }
            default:
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    private func saveMemo() {
        // Save to database.
        let memo: String = (memoTv.text == placeholderText) ? "" : memoTv.text
        
        DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                           params: ["Memo":memo],
                                           conditions: "where DiveID=\(diveLog.intValue(key: "DiveID"))")
        
        onUpdated?()
        
        // Pop
        self.navigationController?.popViewController(animated: true)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == placeholderText {
            textView.text = ""
            textView.textColor = .label // hoặc .black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = placeholderText
            textView.textColor = placeholderColor
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}
