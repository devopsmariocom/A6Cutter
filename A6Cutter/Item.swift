//
//  Item.swift
//  A6Cutter
//
//  Created by Mario Vejlupek on 01.10.2025.
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
