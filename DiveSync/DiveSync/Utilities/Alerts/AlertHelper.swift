//
//  AlertHelper.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 7/3/25.
//

import UIKit

func showAlert(on viewController: UIViewController,
               title: String? = nil,
               message: String,
               okTitle: String = "OK",
               cancelTitle: String? = nil,
               okHandler: (() -> Void)? = nil,
               cancelHandler: (() -> Void)? = nil) {
    
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    
    let okAction = UIAlertAction(title: okTitle, style: .default) { _ in
        okHandler?()
    }
    alert.addAction(okAction)
    
    if let cancelTitle = cancelTitle {
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            cancelHandler?()
        }
        alert.addAction(cancelAction)
    }
    
    DispatchQueue.main.async {
        viewController.present(alert, animated: true)
    }
}

