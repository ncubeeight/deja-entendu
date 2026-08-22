//
//  Item.swift
//  Déjà Entendu
//
//  Created by Christopher Arnold on 8/22/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
