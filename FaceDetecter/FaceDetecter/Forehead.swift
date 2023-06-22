//
//  Forehead.swift
//  FaceDetecter
//
//  Created by Abboskhon on 22/06/23.
//

import UIKit

struct ForeheadColor {
    let center: UIColor
    let left1: UIColor
    let left2: UIColor
    let left3: UIColor
    let left4: UIColor
    let left5: UIColor
    let right1: UIColor
    let right2: UIColor
    let right3: UIColor
    let right4: UIColor
    let right5: UIColor
}

enum Forehead: String, CaseIterable {
    case top
    case left1, left2, left3, left4, left5
    case right1, right2, right3, right4, right5
}
