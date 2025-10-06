//
//  PermissionViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/1/25.
//

import UIKit

class PermissionViewController: BaseViewController {

    @IBOutlet weak var valueLb: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        if let permissionAllow:Bool = AppSettings.shared.get(forKey: AppSettings.Keys.permissionIdentify),
            permissionAllow == true {
            valueLb.text = "Allow"
        } else {
            valueLb.text = "Decline"
        }
        
    }
    
    @IBAction func permissionTapped(_ sender: Any) {
        
        ItemSelectionAlert.showMessage(
            message: "Permission",
            options: ["Decline", "Allow"],
            selectedValue: valueLb.text
        ) { [weak self] action, value, index in
            guard let self = self else { return }
            
            if action == .allow, let value = value {
                self.valueLb.text = value
                PrintLog("Save to backend: \(value)")
                
                // Decline = false, Allow = true
                AppSettings.shared.set((index == 0) ? false:true, forKey: AppSettings.Keys.permissionIdentify)
                
            }
        }
        
    }
    

}
