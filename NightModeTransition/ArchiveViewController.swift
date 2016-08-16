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
            adjustMaskLayer(basedOn: panRecognizer)
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

    /// During the interactive transition, this property contains the layer
    /// used to mask the contents of `previousStyleViewSnapshot`.
    /// When the user pans, the position and path of `snapshotMaskLayer` is
    /// adjusted to reflect the current translation of the pan recognizer.
    private var snapshotMaskLayer: CAShapeLayer?

    private func beginInteractiveStyleTransition(withPanRecognizer panRecognizer: UIPanGestureRecognizer) {
        guard let window = tableView.window else {
            return
        }

        // We snapshot the window before applying the new style, and make sure
        // it's positioned on top of all the other content.
        previousStyleViewSnapshot = window.snapshotViewAfterScreenUpdates(false)
        window.addSubview(previousStyleViewSnapshot!)
        window.bringSubviewToFront(previousStyleViewSnapshot!)

        // When we have the snapshot we create a new mask layer that's used to
        // control how much of the previous view we display as the transition
        // progresses.
        snapshotMaskLayer = CAShapeLayer()
        snapshotMaskLayer?.path = UIBezierPath(rect: window.bounds).CGPath
        snapshotMaskLayer?.fillColor = UIColor.blackColor().CGColor
        previousStyleViewSnapshot?.layer.mask = snapshotMaskLayer

        // Now we're free to apply the new style. This won't be visible until
        // the user pans more since the snapshot is displayed on top of the
        // actual content.
        useDarkMode = !useDarkMode

        // Finally we make our first adjustment to the mask layer based on the 
        // values of the pan recognizer.
        adjustMaskLayer(basedOn: panRecognizer)
    }

    private func adjustMaskLayer(basedOn panRecognizer: UIPanGestureRecognizer) {
        adjustMaskLayerPosition(basedOn: panRecognizer)
        adjustMaskLayerPath(basedOn: panRecognizer)
    }

    private func adjustMaskLayerPosition(basedOn panRecognizer: UIPanGestureRecognizer) {
        guard let window = tableView.window else {
            return
        }

        // We need to disable implicit animations since we don't want to
        // animate the position change of the mask layer.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let verticalTranslation = panRecognizer.translationInView(window).y
        if verticalTranslation < 0.0 {
            // We wan't to prevent the user from moving the mask layer out the
            // top of the window, since doing so would show the new style at
            // the bottom of the window instead.
            // By resetting the translation we make sure there's no visual 
            // delay between when the user tries to pan upwards and when they 
            // start panning downwards again.
            panRecognizer.setTranslation(.zero, inView: window)
            snapshotMaskLayer?.frame.origin.y = 0.0
        } else {
            // Simply move the mask layer as much as the user has panned.
            // Note that if we had used the _location_ of the pan recognizer
            // instead of the translation, the top of the mask layer would
            // follow the fingers exactly. Using the translation results in a 
            // better user experience since the location of the mask layer is
            // instead relative to the distance moved.
            snapshotMaskLayer?.frame.origin.y = verticalTranslation
        }

        CATransaction.commit()
    }

    private func adjustMaskLayerPath(basedOn panRecognizer: UIPanGestureRecognizer) {
        guard let window = tableView.window else {
            return
        }

        let maskingPath = UIBezierPath()

        // Top-left corner...
        maskingPath.moveToPoint(.zero)

        // ...arc to top-right corner...
        // This is all the code that is required to get the bouncy effect.
        // Since the control point of the quad curve depends on the velocity
        // of the pan recognizer, the path will "deform" more for a larger
        // velocity.
        // We don't need to do anything to animate the path back to its
        // non-deformed state since the pan gesture recognizer's target method
        // (panRecognizerDidChange(_:) in our case) is called periodically
        // even when the user stops moving their finger (until the velocity
        // reaches 0).
        // Note: To increase the bouncy effect, decrease the `damping` value.
        let damping: CGFloat = 45.0
        let verticalOffset = panRecognizer.velocityInView(window).y / damping
        maskingPath.addQuadCurveToPoint(CGPoint(x: window.bounds.maxX, y: 0.0), controlPoint: CGPoint(x: window.bounds.midX, y: verticalOffset))

        // ...to bottom-right corner...
        maskingPath.addLineToPoint(CGPoint(x: window.bounds.maxX, y: window.bounds.maxY))

        // ...to bottom-left corner...
        maskingPath.addLineToPoint(CGPoint(x: 0.0, y: window.bounds.maxY))

        // ...and close the path.
        maskingPath.closePath()

        snapshotMaskLayer?.path = maskingPath.CGPath
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
        guard let snapshotMaskLayer = snapshotMaskLayer else {
            return
        }

        // When cancelling the transition we simply move the mask layer to it's original
        // location (which means that the entire previous style snapshot is shown), then
        // reset the style to the previous style and remove the snapshot.
        animate(snapshotMaskLayer, to: .zero, withVelocity: velocity) {
            self.useDarkMode = !self.useDarkMode
            self.cleanupAfterInteractiveStyleTransition()
        }
    }

    private func completeInteractiveStyleTransition(withVelocity velocity: CGPoint) {
        guard let
            window = tableView.window,
            snapshotMaskLayer = snapshotMaskLayer else {
                return
        }


        // When completing the transition we slide the mask layer down to the bottom of
        // the window and then remove the snapshot. The further down the mask layer is,
        // the more of the underlying view is visible. When the mask layer reaches the
        // bottom of the window, the entire underlying view will be visible so removing
        // the snapshot will have no visual effect.
        let targetLocation = CGPoint(x: 0.0, y: window.bounds.maxY)
        animate(snapshotMaskLayer, to: targetLocation, withVelocity: velocity) {
            self.cleanupAfterInteractiveStyleTransition()
        }
    }

    private func cleanupAfterInteractiveStyleTransition() {
        self.previousStyleViewSnapshot?.removeFromSuperview()
        self.previousStyleViewSnapshot = nil
        self.snapshotMaskLayer = nil
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

    // MARK: - Animation utilities

    private func timeRequiredToMove(from from: CGPoint, to: CGPoint, withVelocity velocity: CGPoint) -> NSTimeInterval {
        let distanceToMove = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        let velocityMagnitude = sqrt(pow(velocity.x, 2) + pow(velocity.y, 2))
        let requiredTime = NSTimeInterval(abs(distanceToMove / velocityMagnitude))
        return requiredTime
    }

    private func animate(layer: CALayer, to targetPoint: CGPoint, withVelocity velocity: CGPoint, completion: () -> Void) {
        let startPoint = layer.position
        layer.position = targetPoint

        let positionAnimation = CABasicAnimation(keyPath: "position")
        positionAnimation.duration = min(3.0, timeRequiredToMove(from: startPoint, to: targetPoint, withVelocity: velocity))
        positionAnimation.fromValue = NSValue(CGPoint: startPoint)
        positionAnimation.toValue = NSValue(CGPoint: targetPoint)

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)

        layer.addAnimation(positionAnimation, forKey: "position")

        CATransaction.commit()
    }

}
