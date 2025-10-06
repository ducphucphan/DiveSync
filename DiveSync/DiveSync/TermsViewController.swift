//
//  TermsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/27/25.
//

import UIKit
import WebKit

enum TermsType {
    case terms
    case privacyPolicy
    
    var urlString: String {
        switch self {
        case .terms:
            return "http://divesync.io/openfile.php?id=2025001"
        case .privacyPolicy:
            return "http://divesync.io/openfile.php?id=2025002"
        }
    }
}

class TermsViewController: BaseViewController {
    
    @IBOutlet weak var webView: WKWebView!
    
    var type: TermsType = .terms   // default
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        if let url = URL(string: type.urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
    }
}
