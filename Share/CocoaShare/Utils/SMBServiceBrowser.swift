//
//  SMBServiceBrowser.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/9/27.
//

#if os(iOS) || os(tvOS)

import Foundation
import Network

class SMBService: NSObject, NetServiceDelegate {
    
    var scanningCallBack: (() -> Void)?
    
    let svr: NetService!
    
    var didResolve = false
    
    var name: String {
        return self.svr.name
    }
    
    var addressDesc: String {
        let addressModels = self.addresses
        let str = addressModels.reduce("", { res, model in
            return res + model + (model == addressModels.last ? "" : "\n")
        })
        return str
    }
    
    var addresses: [String] {
        return self.svr.addresses?.compactMap({ data in
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String? in
                let sockAddr = ptr.bindMemory(to: sockaddr_in.self)
                let addr = sockAddr.baseAddress?.pointee.sin_addr
                guard let addr = addr else { return nil }
                var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var sinaddr = addr
                guard let ipPtr = inet_ntop(AF_INET, &sinaddr, &ipBuffer, socklen_t(INET_ADDRSTRLEN)) else { return nil }
                return String(cString: ipPtr)
            }
        }) ?? []
    }
    
    init(svr: NetService) {
        self.svr = svr
        super.init()
        self.svr.delegate = self
        self.svr.resolve(withTimeout: 5)
    }
    
    // MARK: - NetServiceDelegate
    func netServiceDidResolveAddress(_ sender: NetService) {
        self.didResolve = true
        self.scanningCallBack?()
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Failed to resolve service: \(errorDict)")
    }
}

class SMBServiceBrowser: NSObject {
    
    typealias ScanningAction = () -> Void
    
    private lazy var netServiceBrowser = {
        let service = NetServiceBrowser()
        service.delegate = self
        return service
    }()
    
    lazy var discoveredServices: [SMBService] = []
    
    private var scanningCallBack: ScanningAction?

    func startScanning(_ callBack: @escaping(ScanningAction)) {
        self.scanningCallBack = callBack
        // 开始查找 SMB 服务
        self.netServiceBrowser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")
    }
    
    deinit {
        self.netServiceBrowser.stop()
    }
}

extension SMBServiceBrowser: NetServiceBrowserDelegate {
    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Found service: \(service.name)")
        let svr = SMBService(svr: service)
        svr.scanningCallBack = { [weak self] in
            self?.scanningCallBack?()
        }
        self.discoveredServices.append(svr)
        self.scanningCallBack?()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("Removed service: \(service.name)")
        if let index = self.discoveredServices.firstIndex(where: { $0.svr == service }) {
            self.discoveredServices.remove(at: index)
        }
        self.scanningCallBack?()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Failed to search for services: \(errorDict)")
    }

}

#endif
