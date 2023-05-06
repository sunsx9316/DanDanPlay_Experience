//
//  PCQRScannerViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/2.
//

import UIKit
import YYCategories

class PCQRScannerViewController: ViewController {
    
    var scanSuccessCallBack: ((LoginInfo) -> Void)?
    
    private lazy var qrCodeReader: JHQRCodeReader = {
        let qrCodeReader = JHQRCodeReader(metadataObjectTypes: [.qr])
        qrCodeReader.setCompletionWith { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.scanResult(result)
            }
        }
        
        return qrCodeReader
    }()
    
    private lazy var maskView = UIView()
    
    private lazy var cropLayer = CAShapeLayer()
    
    private lazy var shapeLayer = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black
        self.view.layer.addSublayer(self.qrCodeReader.previewLayer)
        self.view.addSubview(self.maskView)
        self.maskView.layer.addSublayer(self.cropLayer)
        self.maskView.layer.addSublayer(self.shapeLayer)
        
        self.maskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if JHQRCodeReader.isAuthorization() == false {
            
            let appName = Helper.appDisplayName ?? ""
            let vc = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: "请在设置-\(appName)中允许\(appName)访问您的相机~", preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: NSLocalizedString("好的", comment: ""), style: .default, handler: { _ in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }))
            
            vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { _ in
                self.navigationController?.popViewController(animated: true)
            }))
            
            self.present(vc, animated: true)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                self.qrCodeReader.startScanning()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.qrCodeReader.stopScanning()
    }
    
    deinit {
        self.qrCodeReader.stopScanning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if JHQRCodeReader.isAuthorization() {
            self.qrCodeReader.startScanning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.qrCodeReader.previewLayer.frame = self.view.bounds
        self.cropLayer.frame = self.view.bounds
        
        
        // 创建一个绘制路径
        let path = UIBezierPath(rect: self.view.bounds)
        
        let scannerSize: CGFloat = min(self.view.bounds.width, self.view.bounds.height) * 0.7
        // 空心矩形的rect
        let cropRect = CGRect(x: (self.view.bounds.width - scannerSize) / 2,
                              y: (self.view.bounds.height - scannerSize) / 2,
                              width: scannerSize,
                              height: scannerSize)
        let cropPath = UIBezierPath(rect: cropRect)
        path.append(cropPath)
        self.cropLayer.fillRule = .evenOdd
        self.cropLayer.fillColor = UIColor(white: 0, alpha: 0.6).cgColor
        self.cropLayer.path = path.cgPath
        

        //绘制虚线
        self.shapeLayer.frame = cropRect
        self.shapeLayer.fillColor = UIColor.clear.cgColor
        self.shapeLayer.strokeColor = UIColor.white.cgColor
        self.shapeLayer.lineWidth = 2
        self.shapeLayer.lineJoin = .round
        //设置线宽，线间距
        self.shapeLayer.lineDashPattern = [NSNumber(value: 14), NSNumber(value: 7)]
        let linkPath = UIBezierPath(roundedRect: CGRect(x: -1, y: -1, width: cropRect.size.width + 2, height: cropRect.size.height + 2), cornerRadius: 6)
        self.shapeLayer.path = linkPath.cgPath
    }
    
    
    private func scanResult(_ text: String?) {
        if let asJSON = text?.jsonValueDecoded() as? NSDictionary,
           let model = PCQRModel.deserialize(from: asJSON) {
            
            if !model.ip.isEmpty {
                self.qrCodeReader.stopScanning()
                
                var vc: UIAlertController?
                
                if model.ip.count == 1 {
                    let ip = "http://\(model.ip[0]):\(model.port)"

                    vc = UIAlertController(title: "是否连接到\(model.name)", message: ip, preferredStyle: .alert)
                    
                    vc?.addAction(.init(title: "确认", style: .default, handler: { _ in
                        self.select(LoginInfo(url: URL(string: ip)!))
                    }))
                } else {
                    //多网卡情况
                    vc = UIAlertController(title: "提示", message: "选择一个ip或域名进行连接~", preferredStyle: .alert)
                    
                    for ip in model.ip {
                        let address = "http://\(ip):\(model.port)"
                        vc?.addAction(.init(title: address, style: .default, handler: { _ in
                            self.select(LoginInfo(url: URL(string: address)!))
                        }))
                    }
                }

                vc?.addAction(.init(title: "取消", style: .cancel, handler: { _ in
                    self.qrCodeReader.startScanning()
                }))
                
                if let vc = vc {
                    self.present(vc, animated: true)
                }
            }
            
        }
    }
    
    private func select(_ loginInfo: LoginInfo) {
        self.scanSuccessCallBack?(loginInfo)
        self.navigationController?.popViewController(animated: true)
    }

}
