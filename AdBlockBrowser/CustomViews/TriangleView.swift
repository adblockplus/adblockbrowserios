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

final class TriangleView: UIView {
    private var triangleLayer: CAShapeLayer?

    @IBInspectable var isUpsideDown: Bool = false {
        didSet {
            update()
        }
    }

    override var tintColor: UIColor! {
        didSet {
            triangleLayer?.fillColor = tintColor.cgColor
        }
    }

    override var frame: CGRect {
        didSet {
            update()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        update()
    }

    private func update() {
        let width = frame.size.width
        let height = frame.size.height
        let orientationOffset = isUpsideDown ? height : 0

        let trianglePath = UIBezierPath()
        trianglePath.move(to: CGPoint(x: 0, y: orientationOffset))
        trianglePath.addLine(to: CGPoint(x: width / 2, y: height - orientationOffset))
        trianglePath.addLine(to: CGPoint(x: width, y: orientationOffset))
        trianglePath.close()

        self.triangleLayer?.removeFromSuperlayer()

        let triangleLayer = CAShapeLayer()
        triangleLayer.path = trianglePath.cgPath
        triangleLayer.fillColor = tintColor.cgColor
        layer.addSublayer(triangleLayer)
        self.triangleLayer = triangleLayer
    }
}
