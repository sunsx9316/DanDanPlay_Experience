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
        self.setupNavigationItem()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupNavigationItem()
    }
    
    private func setupNavigationItem() {
        self.navigationItem.leftBarButtonItem = .init(backToTopItem: self, action: #selector(onTouchLeftBarButtonItem(_:)))
        self.navigationItem.leftItemsSupplementBackButton = true
    }
    
    @objc private func onTouchLeftBarButtonItem(_ item: UIButton) {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
}
