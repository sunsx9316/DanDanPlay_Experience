//
//  UIImage+Helper.swift
//  AniXPlayer
//

#if os(iOS) || os(tvOS)
import UIKit

extension UIImage {
    static var placeholder: UIImage? {
        return UIImage(named: "Public/placeholder")
    }
}
#endif
