//
//  ArchiveViewController.swift
//  NightModeTransition
//
//  Created by Tim Andersson on 12/08/16.
//  Copyright © 2016 Cocoabeans Software. All rights reserved.
//

import UIKit

struct ViewControllerStyle {
    var navigationBarStyle: UIBarStyle
    var statusBarStyle: UIStatusBarStyle
    var tableViewStyle: TableViewStyle

    static let Dark = ViewControllerStyle(
        navigationBarStyle: .Black,
        statusBarStyle: .LightContent,
        tableViewStyle: .Dark
    )

    static let Light = ViewControllerStyle(
        navigationBarStyle: .Default,
        statusBarStyle: .Default,
        tableViewStyle: .Light
    )

}

struct TableViewStyle {
    var backgroundColor: UIColor
    var separatorColor: UIColor?
    var cellStyle: CellStyle

    static let Dark = TableViewStyle(
        backgroundColor: UIColor(white: 0.15, alpha: 1.0),
        separatorColor: UIColor(white: 0.35, alpha: 1.0),
        cellStyle: .Dark
    )

    static let Light = TableViewStyle(
        backgroundColor: .groupTableViewBackgroundColor(),
        separatorColor: UIColor(white: 0.81, alpha: 1.0),
        cellStyle: .Light
    )
}

class ArchiveViewController: UITableViewController {

    // MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()
        applyCurrentStyle()
    }

    // MARK: - UITableViewDelegate methods

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        guard let archiveCell = cell as? ArchiveTableCellView else {
            return
        }

        archiveCell.apply(style: currentStyle.tableViewStyle.cellStyle)
    }

    // MARK: - Applying styles

    private var currentStyle = ViewControllerStyle.Dark {
        didSet { applyCurrentStyle() }
    }

    private func applyCurrentStyle() {
        apply(style: currentStyle)
    }

    private func apply(style style: ViewControllerStyle) {
        navigationController?.navigationBar.barStyle = style.navigationBarStyle
        UIApplication.sharedApplication().statusBarStyle = style.statusBarStyle

        tableView.backgroundColor = style.tableViewStyle.backgroundColor
        tableView.separatorColor = style.tableViewStyle.separatorColor
        apply(cellStyle: style.tableViewStyle.cellStyle, toCells: tableView.visibleCells)
    }

    private func apply(cellStyle cellStyle: CellStyle, toCells cells: [UITableViewCell]) {
        for cell in cells {
            guard let archiveCell = cell as? ArchiveTableCellView else {
                continue
            }

            archiveCell.apply(style: cellStyle)
        }
    }

}

