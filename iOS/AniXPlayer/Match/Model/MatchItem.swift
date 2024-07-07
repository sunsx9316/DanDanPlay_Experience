//
//  MatchItem.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation

protocol MatchItem {
    
    var items: [MatchItem]? { get }
    
    var title: String { get }
    
    var episodeId: Int? { get }
    
    var typeDesc: String? { get }
    
}
