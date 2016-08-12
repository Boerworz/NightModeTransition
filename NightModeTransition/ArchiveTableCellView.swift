//
//  ArchiveTableCellView.swift
//  NightModeTransition
//
//  Created by Tim Andersson on 12/08/16.
//  Copyright © 2016 Cocoabeans Software. All rights reserved.
//

import UIKit

struct CellStyle {
    var backgroundColor: UIColor
    var textColor: UIColor

    static let Light = CellStyle(
        backgroundColor: .whiteColor(),
        textColor: .blackColor()
    )

    static let Dark = CellStyle(
        backgroundColor: UIColor(white: 0.2, alpha: 1.0),
        textColor: .whiteColor()
    )
}

class ArchiveTableCellView: UITableViewCell {

    @IBOutlet private weak var label: UILabel?

    func apply(style style: CellStyle) {
        backgroundColor = style.backgroundColor
        label?.textColor = style.textColor
    }

}