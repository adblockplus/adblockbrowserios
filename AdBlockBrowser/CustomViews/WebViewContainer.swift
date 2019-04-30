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

import UIKit

private final class ReloaderView: UIView {
    let imageView = UIImageView(image: UIImage(named: "back_inactive"))

    let circleLayer = CAShapeLayer()

    var forward: Bool = false {
        didSet {
            if forward {
                imageView.image = UIImage(named: "forward_inactive")
            } else {
                imageView.image = UIImage(named: "back_inactive")
            }
        }
    }

    var classRadius: CGFloat = 0

    var radius: CGFloat {
        get { return classRadius; }
        set (radius) {
            classRadius = radius
            circleLayer.path = createPathWith(radius)
            circleLayer.bounds = CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius)
            circleLayer.removeAnimation(forKey: "scale")
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)

        radius = 0
        circleLayer.fillColor = UIColor(white: 240.0 / 256.0, alpha: 1.0).cgColor
        circleLayer.transform = CATransform3DMakeTranslation(imageView.bounds.midX, imageView.bounds.midY, 0)

        imageView.layer.insertSublayer(circleLayer, at: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func setRadius(_ radius: CGFloat, withDuration duration: Double) {
        let oldRadius = self.radius
        let newRadius = radius

        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.fromValue = createPathWith(oldRadius)
        pathAnimation.toValue = createPathWith(newRadius)

        let boundsAnimation = CABasicAnimation(keyPath: "bounds")
        let oldBounds = CGRect(x: -oldRadius, y: -oldRadius, width: 2 * oldRadius, height: 2 * oldRadius)
        boundsAnimation.fromValue = NSValue(cgRect: oldBounds)
        let newBounds = CGRect(x: -newRadius, y: -newRadius, width: 2 * newRadius, height: 2 * newRadius)
        boundsAnimation.toValue = NSValue(cgRect: newBounds)
        boundsAnimation.isAdditive = true

        let animations = CAAnimationGroup()
        animations.animations = [pathAnimation, boundsAnimation]
        animations.isRemovedOnCompletion = false
        animations.duration = duration
        animations.fillMode = CAMediaTimingFillMode.forwards

        classRadius = radius
        circleLayer.add(animations, forKey: "scale")
    }

    func createPathWith(_ radius: CGFloat) -> CGPath {
        // The scaling animation was not properly interpolated on iOS8, if the animation goes to/from zero radius.
        // The solution, which fixes this issue, is to span the last quater segment over the first quater segment of the arc.
        let newPath = UIBezierPath(arcCenter: CGPoint(x: 0, y: 0),
                                   radius: radius,
                                   startAngle: -CGFloat.pi / 2,
                                   endAngle: CGFloat.pi * 5 / 2,
                                   clockwise: true)
        return newPath.cgPath
    }
}

enum ReloaderStatus {
    case ready, interactive
}

final class WebViewContainer: UIView, UIGestureRecognizerDelegate {
    fileprivate let reloader: ReloaderView

    required init?(coder aDecoder: NSCoder) {
        reloader = ReloaderView(frame: CGRect.zero)
        reloader.backgroundColor = UIColor(white: 0x44 / 256.0, alpha: 1.0)
        reloader.isHidden = true
        super.init(coder: aDecoder)
        addSubview(reloader)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Screen edge pan recognizers must be created manually. When created in Designer,
        // it does not ever invoke the selector on iOS8. It is a known bug, probably an incomplete
        // initialization sequence UIScreenEdgePanGestureRecognizer, which was apparently
        // fixed in iOS9.
        // http://stackoverflow.com/a/29485778

        let makeRecognizer = { (edges: UIRectEdge) -> (UIGestureRecognizer) in
            let recognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(WebViewContainer.onScreenEdgePanGestureRecognizer(_:)))
            recognizer.edges = edges
            recognizer.delegate = self
            recognizer.minimumNumberOfTouches = 1
            recognizer.maximumNumberOfTouches = 1
            return recognizer
        }
        addGestureRecognizer(makeRecognizer(.left))
        addGestureRecognizer(makeRecognizer(.right))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !reloader.isHidden {
            var frame = reloader.frame
            frame.size.height = self.frame.height
            reloader.frame = frame
        }
    }

    var reloaderStatus = ReloaderStatus.ready
    var startPoint = CGPoint.zero
    var canAdvance = false

    var webView: UIWebView? {
        didSet {
            let webViewFrame = bounds
            let shadowFrame = CGRect(x: -10,
                                     y: -10,
                                     width: webViewFrame.width + 20,
                                     height: webViewFrame.height + 20)

            let shadowPath = UIBezierPath(rect: shadowFrame)
            webView?.layer.masksToBounds = false
            webView?.layer.shadowColor = UIColor(white: 0x2A / 256.0, alpha: 1.0).cgColor
            webView?.layer.shadowOffset = CGSize(width: 0, height: 0)
            webView?.layer.shadowOpacity = 0.0
            webView?.layer.shadowPath = shadowPath.cgPath
        }
    }

    var webViewConstraint: NSLayoutConstraint? {
        let index = constraints.index { constraint -> Bool in
            return constraint.identifier == webViewCenterXConstraintIdentifier && constraint.firstItem === self.webView
        }
        if let index = index {
            return constraints[index]
        } else {
            return nil
        }
    }

    var historyChangeEventHandler: ((Bool) -> Void)?

    // MARK: - Actions

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    @IBAction func onScreenEdgePanGestureRecognizer(_ sender: UIScreenEdgePanGestureRecognizer) {
        let progressThreshold = CGFloat(1.0 / 3.0)
        let scalingAnimationDuration = 0.2
        let finalizingAnimationDuration = 0.5

        switch sender.state {
        case .began:
            // Initialize reloader view
            startPoint = sender.location(in: self)
            canAdvance = (sender.edges.contains(.right) ? webView?.canGoForward : webView?.canGoBack) ?? false
            reloader.radius = 0
            reloader.forward = sender.edges.contains(.right)
            reloader.imageView.isHidden = !canAdvance
            reloader.isHidden = false
            reloaderStatus = .interactive
        case .changed:
            if let constraint = webViewConstraint {

                let point = sender.location(in: self)

                var frame = self.bounds

                let offset = (point.x - startPoint.x) * (canAdvance ? 1 : 1.0 / 3.0)

                let progress = abs(offset) / frame.width

                let isCircleShown = reloader.radius > 0

                if (progress > progressThreshold) != isCircleShown {
                    reloader.setRadius(isCircleShown ? 0 : 30, withDuration: scalingAnimationDuration)
                }

                webView?.layer.shadowOpacity = 1.0 - Float(progress) / Float(progressThreshold)

                if sender.edges.contains(.right) {
                    frame.origin.x = frame.width + min(0, offset)
                    frame.size.width = -min(0, offset)
                    constraint.constant = min(0, offset)
                } else {
                    frame.size.width = max(0, offset)
                    constraint.constant = max(0, offset)
                }

                reloader.frame = frame
            }
        case .ended, .failed, .cancelled:
            // Finalize animation, hide reloader
            if let constraint = webViewConstraint {

                let velocity = sender.velocity(in: self)
                let point = sender.location(in: self)
                let offset = point.x - startPoint.x

                let recognizerDirection = sender.edges.contains(.right) ? -1 : 1
                let targetDirection = velocity.x < 0 ? -1 : 1

                var frame = self.bounds

                let executeAction: Bool
                let targetOffset: CGFloat
                let springVelocity: CGFloat

                let isSlowMovement = Swift.abs(velocity.x) < frame.width / 10
                let isFirstSection = abs(offset) < progressThreshold * frame.width
                let isSameDirection = recognizerDirection == targetDirection

                // Travel back to default state if swipe gesture is slow
                if sender.state == .failed
                    || !canAdvance
                    || (isSlowMovement && isFirstSection)
                    || (!isSlowMovement && !isSameDirection) {
                    executeAction = false
                    targetOffset = 0
                    springVelocity = velocity.x / offset * CGFloat(recognizerDirection * targetDirection)
                } else {
                    executeAction = true
                    targetOffset = CGFloat(recognizerDirection) * frame.width
                    springVelocity = velocity.x / (targetOffset - offset)
                }

                let goForward: Bool
                if sender.edges.contains(.right) {
                    frame.origin.x = frame.width + targetOffset
                    frame.size.width = -targetOffset
                    goForward = true
                } else {
                    frame.size.width = targetOffset
                    goForward = false
                }

                if executeAction {
                    let radius = sqrt(pow(frame.width, 2) + pow(frame.height, 2))
                    reloader.setRadius(radius, withDuration: finalizingAnimationDuration)
                } else {
                    reloader.setRadius(0, withDuration: scalingAnimationDuration)
                }

                UIView.animate(withDuration: finalizingAnimationDuration,
                               delay: 0,
                               usingSpringWithDamping: 1,
                               initialSpringVelocity: springVelocity,
                               options: UIView.AnimationOptions(),
                               animations: { () in

                                self.webView?.layer.shadowOpacity = 0.0
                                self.reloader.frame = frame
                                constraint.constant = targetOffset
                                self.reloader.layoutIfNeeded()
                                self.webView?.layoutIfNeeded()
                                // swiftlint:disable:next multiple_closures_with_trailing_closure
                }) { _ in
                    self.reloader.isHidden = true
                    self.reloaderStatus = .ready
                    if executeAction {
                        (self.webView as? SAContentWebView)?.openCurtain()

                        if let handler = self.historyChangeEventHandler {
                            handler(goForward)
                        }

                        constraint.constant = 0
                        self.webView?.alpha = 0

                        UIView.animate(withDuration: 0.5) { () in
                            self.webView?.alpha = 1.0
                        }
                    }
                }
            }
        default:
            break
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return reloaderStatus == .ready
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
