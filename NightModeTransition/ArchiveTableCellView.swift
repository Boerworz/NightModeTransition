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
        backgroundColor: .white,
        textColor: .black
    )

    static let Dark = CellStyle(
        backgroundColor: UIColor(white: 0.2, alpha: 1.0),
        textColor: .white
    )
}

class ArchiveTableCellView: UITableViewCell {

    @IBOutlet fileprivate weak var label: UILabel?
    @IBOutlet fileprivate weak var artworkImageView: UIImageView?

    override func awakeFromNib() {
        super.awakeFromNib()
        artworkImageView?.layer.cornerRadius = 10.0
    }

    func apply(style: CellStyle) {
        backgroundColor = style.backgroundColor
        label?.textColor = style.textColor
    }

}
