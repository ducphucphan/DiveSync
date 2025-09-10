//
//  TermsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/27/25.
//

import UIKit

class TermsViewController: BaseViewController {

    @IBOutlet weak var contentTv: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
    }
    

}
