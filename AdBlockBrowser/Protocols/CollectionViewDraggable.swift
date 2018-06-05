/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

/// Protocol, which will add ability to reorder collection view cells using drag and drop.
/// Client is only responsible for providing reference to collection view and storage
/// for draggable context.
@objc protocol CollectionViewDraggable: class {
    var draggableContext: CollectionViewDraggableContext? { get set }

    var collectionView: UICollectionView? { get }

    @objc
    optional func canMoveItem(at indexPath: IndexPath) -> Bool

    @objc
    optional func didBeginDraggingItem(at indexPath: IndexPath)

    @objc
    optional func didEndDraggingItem(at indexPath: IndexPath)

    @objc
    optional func didMoveItem(at oldIndexPath: IndexPath, to newIndexPath: IndexPath)

    @objc
    optional func snapshotViewForItem(at indexPath: IndexPath) -> UIView?

    @objc
    optional func willBeginDraggingAnimation(with snapshotView: UIView, duration: TimeInterval)

    @objc
    optional func willEndDraggingAnimation(with snapshotView: UIView, duration: TimeInterval)
}

extension CollectionViewDraggable {
    func setupCollectionViewDraggable() -> UIGestureRecognizer {
        let context = CollectionViewDraggableContext()
        context.delegate = self

        let gestureRecognizer = UILongPressGestureRecognizer(target: context,
                                                             action: #selector(CollectionViewDraggableContext.onGestureStateChanged(_:)))

        gestureRecognizer.minimumPressDuration = 1.0
        gestureRecognizer.delaysTouchesBegan = false

        if let gestureRecognizers = collectionView?.gestureRecognizers {
            for recognizer in gestureRecognizers {
                (recognizer as? UILongPressGestureRecognizer)?.require(toFail: gestureRecognizer)
            }
        }

        collectionView?.addGestureRecognizer(gestureRecognizer)
        draggableContext = context
        return gestureRecognizer
    }
}

// MARK: Point's convinience operators

func + (point1: CGPoint, point2: CGPoint) -> CGPoint {
    return CGPoint(x: point1.x + point2.x, y: point1.y + point2.y)
}

func - (point1: CGPoint, point2: CGPoint) -> CGPoint {
    return CGPoint(x: point1.x - point2.x, y: point1.y - point2.y)
}

func * (point: CGPoint, float: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * float, y: point.y * float)
}

prefix func - (point: CGPoint) -> CGPoint {
    return CGPoint(x: -point.x, y: -point.y)
}

// MARK: Draggable animation constants

private let scale = CGFloat(1.2)
private let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
private let scaleAnimationDuration = 0.4

/// Class, which hold current draggable status.
/// Client is responsible just only for providing storage for reference.
final class CollectionViewDraggableContext: NSObject {
    fileprivate var startingIndexPath = IndexPath(index: 0)
    fileprivate var currentIndexPath = IndexPath(index: 0)
    fileprivate var snapshotView: UIView?
    fileprivate var offset = CGPoint.zero
    fileprivate var isAnimating = false

    fileprivate weak var delegate: CollectionViewDraggable?

    @objc
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    fileprivate func onGestureStateChanged(_ sender: UILongPressGestureRecognizer) {
        if isAnimating {
            return
        }

        guard let collectionView = delegate?.collectionView else {
            return
        }

        let point = sender.location(in: collectionView)

        switch sender.state {
        case .began:
            if let indexPath = collectionView.indexPathForItem(at: point), (delegate?.canMoveItem?(at: indexPath) ?? false),
                let cell = collectionView.cellForItem(at: indexPath) {
                startingIndexPath = indexPath
                currentIndexPath = startingIndexPath
                delegate?.didBeginDraggingItem?(at: indexPath)

                // Cell movement
                guard let snapshotView = {() -> UIView? in
                    if let view = delegate?.snapshotViewForItem?(at: indexPath) {
                        return view
                    } else {
                        return cell.snapshotView(afterScreenUpdates: true)
                    }
                }() else {
                    break
                }

                let center = CGPoint(x: snapshotView.bounds.width, y: snapshotView.bounds.height) * 0.5
                collectionView.superview?.addSubview(snapshotView)
                cell.isHidden = true

                offset = collectionView.convert(point, to: cell) - center
                let point = collectionView.convert(point,
                                                   to: collectionView.superview) - offset

                snapshotView.transform = CGAffineTransform.identity
                snapshotView.center = point

                delegate?.willBeginDraggingAnimation?(with: snapshotView, duration: scaleAnimationDuration)
                UIView.beginAnimations(nil, context: nil)
                UIView.setAnimationDuration(scaleAnimationDuration)
                snapshotView.transform = scaleTransform
                snapshotView.center = point
                snapshotView.alpha = 0.6
                UIView.commitAnimations()

                self.snapshotView = snapshotView
            }
        case .changed:
            snapshotView?.center = collectionView.convert(point,
                                                          to: collectionView.superview) - offset
            collectionView.cellForItem(at: currentIndexPath)?.isHidden = true

            checkForDraggingAtTheEdgeAndAnimatePaging(sender)

            if let indexPath = collectionView.indexPathForItem(at: point) {
                if indexPath != currentIndexPath && (delegate?.canMoveItem?(at: indexPath) ?? false) {
                    delegate?.didMoveItem?(at: currentIndexPath, to: indexPath)
                    self.currentIndexPath = indexPath
                }
            }
        case .ended:
            finishItemAnimation(currentIndexPath)
            delegate?.didEndDraggingItem?(at: currentIndexPath)
        case .cancelled, .failed:
            if startingIndexPath != currentIndexPath {
                delegate?.didMoveItem?(at: currentIndexPath, to: startingIndexPath)
            }

            finishItemAnimation(startingIndexPath)
            delegate?.didEndDraggingItem?(at: startingIndexPath)
        case .possible:
            // Nothing to do
            break
        }
    }

    fileprivate func finishItemAnimation(_ indexPath: IndexPath) {
        if let cell = delegate?.collectionView?.cellForItem(at: indexPath) {
            let collectionView = delegate?.collectionView
            if let snapshotView = snapshotView {
                let point = (collectionView?.convert(cell.frame.origin, to: collectionView?.superview) ?? CGPoint.zero)
                            + CGPoint(x: snapshotView.bounds.width, y: snapshotView.bounds.height ) * 0.5

                delegate?.willEndDraggingAnimation?(with: snapshotView, duration: scaleAnimationDuration)
                UIView.animate(withDuration: scaleAnimationDuration, animations: { () in
                    snapshotView.transform = CGAffineTransform.identity
                    snapshotView.center = point
                    snapshotView.alpha = 1
                }, completion: { _ in
                    snapshotView.removeFromSuperview()
                    collectionView?.cellForItem(at: indexPath)?.isHidden = false
                })
            }

            snapshotView = nil
        } else {
            snapshotView?.removeFromSuperview()
            snapshotView = nil
        }
    }

    fileprivate func checkForDraggingAtTheEdgeAndAnimatePaging(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if isAnimating {
            return
        }

        guard let collectionView = delegate?.collectionView, let snapshotView = snapshotView else {
            return
        }

        let snapshotFrame = snapshotView.frame
        var contentOffset = collectionView.contentOffset

        if snapshotFrame.minY < collectionView.frame.minY + 20 {
            contentOffset.y = max(0, contentOffset.y - collectionView.bounds.height)
        }

        if snapshotFrame.maxY > collectionView.frame.maxY - 20 {
            contentOffset.y = min(collectionView.contentSize.height - collectionView.bounds.height, contentOffset.y + collectionView.bounds.height)
        }

        if !collectionView.contentOffset.equalTo(contentOffset) {

            isAnimating = true

            // Do not use UIView.animateWithDuration here,
            // it is causing cells not be rendered.

            CATransaction.begin()
            CATransaction.setCompletionBlock({[weak self] () -> Void in
                self?.isAnimating = false
            })
            CATransaction.setAnimationDuration(0.5)
            collectionView.setContentOffset(contentOffset, animated: true)
            CATransaction.commit()
        }
    }
}
