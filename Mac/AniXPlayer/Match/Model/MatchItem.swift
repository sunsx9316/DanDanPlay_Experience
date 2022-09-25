//
//  MatchItem.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation

protocol MatchItem {
    
    var items: [MatchItem]? { get }
    
    var title: String { get }
    
    var episodeId: Int? { get }
    
    var typeDesc: String? { get }
    
}
