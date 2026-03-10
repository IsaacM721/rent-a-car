//
//  Item.swift
//  rent-a-car
//
//  Created by Isaac Mendez on 3/10/26.
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
