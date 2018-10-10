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

import RxSwift
import UIKit

final class DashboardViewController: CollectionViewController<DashboardViewModel>, CollectionViewDraggable, DashboardDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        UIMenuController.shared.menuItems = [UIMenuItem(title: NSLocalizedString("Edit", comment: "Bookmark edit"),
                                                        action: #selector(DashboardCell.editBookmark(_:)))]

        // Allow to show context menu after recognized long tap, but before drag&drop has been triggered
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self,
                                                                      action: #selector(onGestureStateChanged(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.25
        collectionView?.addGestureRecognizer(longPressGestureRecognizer)

        let gestureRecognizer = setupCollectionViewDraggable()
        // Drag&Drop recognizer has bigger priority
        longPressGestureRecognizer.require(toFail: gestureRecognizer)
    }

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    override func observe(viewModel: DashboardViewModel) {
        viewModel.isGhostModeEnabled.asObservable()
            .subscribe(onNext: { [weak self] isEnabled in
                UIView.animate(withDuration: 0.5) {
                    self?.collectionView?.backgroundColor = isEnabled ? .abbGhostMode : .abbLightGray
                }
            })
            .addDisposableTo(disposeBag)

        collectionView?.reloadData()

        viewModel.modelChanges
            .filter { $0.count > 0 }
            .subscribe(onNext: { [weak collectionView] changes in
                collectionView?.performBatchUpdates({
                    for change in changes {
                        switch change {
                        case .deleteItems(let indexPaths):
                            collectionView?.deleteItems(at: indexPaths)
                        case .insertItems(let indexPaths):
                            collectionView?.insertItems(at: indexPaths)
                        case .reloadItems(let indexPaths):
                            collectionView?.reloadItems(at: indexPaths)
                        case .moveItem(let indexPath, let toIndexPath):
                            collectionView?.moveItem(at: indexPath, to: toIndexPath)
                        }
                    }
                }, completion: nil)
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: - UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel?.model.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DashboardCell", for: indexPath)

        if let dashboardCell = cell as? DashboardCell, let bookmark = viewModel?.model[indexPath.row] {
            dashboardCell.delegate = self
            dashboardCell.set(bookmark: bookmark)
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter {
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                   withReuseIdentifier: "TipFooterView",
                                                                   for: indexPath)
        } else {
            return super.collectionView(collectionView,
                                        viewForSupplementaryElementOfKind: kind,
                                        at: indexPath)
        }
    }

    // MARK: - UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let bookmark = viewModel?.model.element(at: indexPath.row) {
            viewModel?.load(bookmark: bookmark)
        }
    }

    // MARK: - CollectionViewDraggable

    var draggableContext: CollectionViewDraggableContext?
    var startingIndexPath: IndexPath?

    func canMoveItem(at indexPath: IndexPath) -> Bool {
        return true
    }

    func didBeginDraggingItem(at indexPath: IndexPath) {
        viewModel?.isReordering.value = true
        startingIndexPath = indexPath
    }

    func didEndDraggingItem(at indexPath: IndexPath) {
        viewModel?.isReordering.value = false
        if indexPath == startingIndexPath, let cell = collectionView?.cellForItem(at: indexPath) {
            // Cell have to be first responder in order to display menu
            cell.becomeFirstResponder()
            let menu = UIMenuController.shared
            menu.setTargetRect(cell.bounds, in: cell)
            menu.setMenuVisible(true, animated: true)
        }
    }

    func didMoveItem(at indexPath: IndexPath, to toIndexPath: IndexPath) {
        viewModel?.didMoveItem(at: indexPath, to: toIndexPath)
    }

    func snapshotViewForItem(at indexPath: IndexPath) -> UIView? {
        if let dashboardCell = collectionView?.cellForItem(at: indexPath) as? DashboardCell {
            let snapshotView = UIView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 64, height: 64)))

            let overlayView = UIView(frame: dashboardCell.imageView?.frame ?? CGRect.zero)
            overlayView.tag = snapshotOverlayTag
            overlayView.backgroundColor = .white
            overlayView.alpha = 0
            overlayView.layer.cornerRadius = 5
            snapshotView.addSubview(overlayView)

            let imageView = UIImageView(image: dashboardCell.imageView?.image)
            imageView.frame = dashboardCell.imageView?.frame ?? CGRect.zero
            imageView.layer.cornerRadius = dashboardCell.imageView?.layer.cornerRadius ?? 0
            snapshotView.addSubview(imageView)

            if let titleLabel = dashboardCell.titleLabel {
                let label = UILabel(frame: titleLabel.frame)
                label.text = titleLabel.text
                label.textAlignment = titleLabel.textAlignment
                label.textColor = titleLabel.textColor
                label.font = titleLabel.font
                label.backgroundColor = UIColor(white: 1.0, alpha: 0.0)
                label.numberOfLines = titleLabel.numberOfLines
                label.tag = snapshotLabelTag
                snapshotView.addSubview(label)
            }

            return snapshotView
        }

        return nil
    }

    func willBeginDraggingAnimation(with snapshotView: UIView, duration: TimeInterval) {
        let overlay = snapshotView.viewWithTag(snapshotOverlayTag)
        let label = snapshotView.viewWithTag(snapshotLabelTag)
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(duration)
        overlay?.alpha = 1
        label?.alpha = 0
        UIView.commitAnimations()
    }

    func willEndDraggingAnimation(with snapshotView: UIView, duration: TimeInterval) {
        let overlay = snapshotView.viewWithTag(snapshotOverlayTag)
        let label = snapshotView.viewWithTag(snapshotLabelTag)
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(duration)
        overlay?.alpha = 0
        label?.alpha = 1
        UIView.commitAnimations()
    }

    private let snapshotOverlayTag = 456123
    private let snapshotLabelTag = 456124

    // MARK: - UIResponderStandardEditActions

    @objc
    fileprivate func onGestureStateChanged(_ sender: UILongPressGestureRecognizer) {
        if sender.state != .ended {
            return
        }

        let point = sender.location(in: collectionView)

        guard let collectionView = collectionView,
            let indexPath = collectionView.indexPathForItem(at: point),
            let cell = collectionView.cellForItem(at: indexPath) else {
                return
        }

        cell.becomeFirstResponder()
        let menu = UIMenuController.shared
        menu.setTargetRect(cell.bounds, in: cell)
        menu.setMenuVisible(true, animated: true)
    }

    // MARK: - DashboardDelegate

    func editBookmark(for cell: DashboardCell) {
        if let indexPath = collectionView?.indexPath(for: cell), let bookmark = viewModel?.model[indexPath.row] {
            viewModel?.browserSignalSubject.onNext(.presentEditBookmark(bookmark))
        }
    }
}
