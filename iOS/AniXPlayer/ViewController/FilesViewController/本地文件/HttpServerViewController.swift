//
//  HttpServerViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/12.
//

import UIKit
import SnapKit

extension HttpServerViewController: HttpServerDelegate {
    func httpServer(_ httpServer: HttpServer, didReceiveFileAtPath path: String) {
        DispatchQueue.main.async {
            let file = LocalFile(with: .init(fileURLWithPath: path))
            self.dataSource.append(file)
            self.tableView.reloadData()
        }
    }
    
    func httpServerDidStart(_ httpServer: HttpServer) {
        self.resetAddress()
    }
}

extension HttpServerViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = self.dataSource[indexPath.row]
        
        let cell = tableView.dequeueCell(class: FileTableViewCell.self, indexPath: indexPath)
        cell.file = file
        cell.backgroundView?.backgroundColor = .backgroundColor
        return cell
    }
    
}

class HttpServerViewController: ViewController {
    
    private lazy var httpServer: HttpServer = {
        let httpServer = HttpServer()
        httpServer.delegate = self
        return httpServer
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.spacing = 5
        return stackView
    }()
    
    private weak var addressLabel: UILabel?
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: FileTableViewCell.self)
        tableView.allowsSelection = false
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    private weak var wifiIconImgView: UIImageView?
    
    private lazy var dataSource = [File]()
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.tableView.reloadData()
        self.setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("WiFi传文件", comment: "")
        
        self.httpServer.start()
        
        let tipsLabel = Label()
        tipsLabel.text = NSLocalizedString(NSLocalizedString("上传过程中请勿离开此页或锁屏", comment: ""), comment: "")
        self.stackView.addArrangedSubview(tipsLabel)
        
        let wifiIconImgView = UIImageView()
        self.wifiIconImgView = wifiIconImgView
        self.stackView.addArrangedSubview(wifiIconImgView)
        
        let addressTipsLabel = Label()
        addressTipsLabel.text = NSLocalizedString("在电脑浏览器地址栏输入", comment: "")
        self.stackView.addArrangedSubview(addressTipsLabel)
        
        let addressLabel = Label()
        addressLabel.font = .ddp_large
        addressLabel.numberOfLines = 0
        addressLabel.textColor = .mainColor
        addressLabel.isUserInteractionEnabled = true
        addressLabel.addGestureRecognizer(UILongPressGestureRecognizer(actionBlock: { [weak self] ges in
            guard let self = self,
                  let ges = ges as? UILongPressGestureRecognizer else { return }
            
            if ges.state == .began {
                UIPasteboard.general.string = self.addressLabel?.text?.replacingOccurrences(of: "\n", with: "")
                self.view.showHUD(NSLocalizedString("复制成功~", comment: ""))
            }
            
        }))
        self.addressLabel = addressLabel
        self.stackView.addArrangedSubview(addressLabel)
        
        self.view.addSubview(self.stackView)
        self.view.addSubview(self.tableView)
        self.stackView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(10)
            make.leading.trailing.equalToSuperview()
        }
        
        self.tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(self.stackView.snp.bottom).offset(5)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
        
        self.setupUI()
        self.resetAddress()
    }
    
    //MARK: Private Method
    private func resetAddress() {
        self.addressLabel?.text = "\n" + (self.httpServer.serverURL?.absoluteString ?? "") + "\n"
    }
    
    private func setupUI() {
        self.wifiIconImgView?.image = .init(named: "PickFile/wifi")?.byTintColor(.mainColor)
    }

}
