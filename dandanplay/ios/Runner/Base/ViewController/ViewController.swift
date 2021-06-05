//
//  ViewController.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .backgroundColor
        let backBarButtton = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = backBarButtton
    }
}
