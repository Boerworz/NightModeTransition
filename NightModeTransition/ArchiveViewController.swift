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

class ArchiveViewController: UITableViewController, UIGestureRecognizerDelegate {

    // MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()

        applyCurrentStyle()
        setupPanGestureRecognizer()
    }

    // MARK: - UITableViewDelegate methods

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        guard let archiveCell = cell as? ArchiveTableCellView else {
            return
        }

        archiveCell.apply(style: currentStyle.tableViewStyle.cellStyle)
    }

    // MARK: - Gesture recognizer interaction

    private func setupPanGestureRecognizer() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panRecognizerDidChange(_:)))
        panRecognizer.maximumNumberOfTouches = 2
        panRecognizer.minimumNumberOfTouches = 2
        panRecognizer.delegate = self
        tableView.addGestureRecognizer(panRecognizer)
    }

    func panRecognizerDidChange(panRecognizer: UIPanGestureRecognizer) {
        switch panRecognizer.state {
        case .Began:
            beginInteractiveStyleTransition(withPanRecognizer: panRecognizer)
        case .Changed:
            adjustMaskViewPosition(basedOn: panRecognizer)
        case .Ended, .Failed:
            endInteractiveStyleTransition(withPanRecognizer: panRecognizer)
        default: break
        }
    }

    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }

        // A pan gesture recognizer recognizes pans in all directions, but we only
        // want the recognizer to begin if the user pans downwards.
        let translation = panRecognizer.translationInView(tableView.window)
        let isMovingDownwards = translation.y > 0.0
        return isMovingDownwards
    }

    // MARK: - Interactive style transition

    /// During the interactive transition, this property contains a
    /// snapshot of the view when it was styled with the previous style
    /// (i.e. the style we're transitioning _from_).
    /// As the transition progresses, less and less of the snapshot view
    /// will be visible, revealing more of the real view which is styled
    /// with the new style.
    private var previousStyleViewSnapshot: UIView?

    /// During the interactive transition, this property contains the view
    /// used to mask the contents of `previousStyleViewSnapshot`.
    /// When the user pans, the frame of `snapshotMaskView` is adjusted to
    /// reflect the current translation of the pan recognizer.
    private var snapshotMaskView: UIView?

    private func beginInteractiveStyleTransition(withPanRecognizer panRecognizer: UIPanGestureRecognizer) {
        guard let window = tableView.window else {
            return
        }

        // We snapshot the window before applying the new style, and make sure
        // it's positioned on top of all the other content.
        previousStyleViewSnapshot = window.snapshotViewAfterScreenUpdates(false)
        window.addSubview(previousStyleViewSnapshot!)
        window.bringSubviewToFront(previousStyleViewSnapshot!)

        // When we have the snapshot we create a new mask view that's used to
        // control how much of the previous view we display as the transition
        // progresses.
        snapshotMaskView = UIView(frame: window.bounds)
        snapshotMaskView?.backgroundColor = .blackColor()
        previousStyleViewSnapshot?.maskView = snapshotMaskView

        // Now we're free to apply the new style. This won't be visible until
        // the user pans more since the snapshot is displayed on top of the
        // actual content.
        useDarkMode = !useDarkMode

        // Finally we make our first adjustment to the mask view's position
        // based on the values of the pan recognizer.
        adjustMaskViewPosition(basedOn: panRecognizer)
    }

    private func adjustMaskViewPosition(basedOn panRecognizer: UIPanGestureRecognizer) {
        guard let window = tableView.window else {
            return
        }

        let verticalTranslation = panRecognizer.translationInView(window).y
        if verticalTranslation < 0.0 {
            // We wan't to prevent the user from moving the mask view out the
            // top of the window, since doing so would show the new style at
            // the bottom of the window instead.
            // By resetting the translation we make sure there's no visual 
            // delay between when the user tries to pan upwards and when they 
            // start panning downwards again.
            panRecognizer.setTranslation(.zero, inView: window)
            snapshotMaskView?.frame.origin.y = 0.0
        } else {
            // Simply move the mask view as much as the user has panned.
            // Note that if we had used the _location_ of the pan recognizer
            // instead of the translation, the top of the mask view would 
            // follow the fingers exactly. Using the translation results in a 
            // better user experience since the location of the mask view is 
            // instead relative to the distance moved.
            snapshotMaskView?.frame.origin.y = verticalTranslation
        }
    }

    private func endInteractiveStyleTransition(withPanRecognizer panRecognizer: UIPanGestureRecognizer) {
        guard let window = tableView.window else {
            return
        }

        let velocity = panRecognizer.velocityInView(window)
        let translation = panRecognizer.translationInView(window)

        let isMovingDownwards = velocity.y > 0.0
        let hasPassedThreshold = translation.y > window.bounds.midY

        // We support both completing the transition and cancelling the transition.
        // The transition to the new style should be completed if the user is panning
        // downwards or if they've panned enough that more than half of the new view
        // is already shown.
        let shouldCompleteTransition = isMovingDownwards || hasPassedThreshold

        if shouldCompleteTransition {
            completeInteractiveStyleTransition(withVelocity: velocity)
        } else {
            cancelInteractiveStyleTransition(withVelocity: velocity)
        }
    }

    private func cancelInteractiveStyleTransition(withVelocity velocity: CGPoint) {
        guard let snapshotMaskView = snapshotMaskView else {
            return
        }

        let duration = timeRequiredToMove(from: snapshotMaskView.frame.minY, to: 0.0, withVelocity: velocity.y)

        // When cancelling the transition we simply move the mask view to it's original
        // location (which means that the entire previous style snapshot is shown), then
        // reset the style to the previous style and remove the snapshot.
        UIView.animateWithDuration(duration, animations: {
            snapshotMaskView.frame.origin.y = 0.0
        }, completion: { _ in
            self.useDarkMode = !self.useDarkMode
            self.cleanupAfterInteractiveStyleTransition()
        })
    }

    private func completeInteractiveStyleTransition(withVelocity velocity: CGPoint) {
        guard let
            window = tableView.window,
            snapshotMaskView = snapshotMaskView else {
                return
        }

        let targetLocation = window.bounds.maxY
        let duration = timeRequiredToMove(from: snapshotMaskView.frame.minY, to: targetLocation, withVelocity: velocity.y)

        // When completing the transition we slide the mask view down to the bottom of
        // the window and then remove the snapshot. The further down the mask view is, 
        // the more of the underlying view is visible. When the mask view reaches the
        // bottom of the window, the entire underlying view will be visible so removing
        // the snapshot will have no visual effect.
        UIView.animateWithDuration(duration, animations: {
            snapshotMaskView.frame.origin.y = targetLocation
        }, completion: { _ in
            self.cleanupAfterInteractiveStyleTransition()
        })
    }

    private func cleanupAfterInteractiveStyleTransition() {
        self.previousStyleViewSnapshot?.removeFromSuperview()
        self.previousStyleViewSnapshot = nil
        self.snapshotMaskView = nil
    }

    // MARK: - Applying styles

    private var currentStyle = ViewControllerStyle.Light {
        didSet { applyCurrentStyle() }
    }

    private var useDarkMode = false {
        didSet { currentStyle = useDarkMode ? .Dark : .Light }
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

    // MARK: - Utilities

    private func timeRequiredToMove(from from: CGFloat, to: CGFloat, withVelocity velocity: CGFloat) -> NSTimeInterval {
        let distanceToMove = to - from
        let requiredTime = NSTimeInterval(abs(distanceToMove / velocity))
        return requiredTime
    }

}
