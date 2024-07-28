//
//  Created by vvgvjks on 2024/7/19.
//
//  Copyright © 2024 vvgvjks <vvgvjks@gmail.com>.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice
//  (including the next paragraph) shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
//  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import SwiftUI
import UIKit

/// pinch: 手势目前只验证过: `magnification` 和 `startAnchor` 符合我的预期, 其他的没有测试.
/// pan  : 手势目前只验证过: `translation` 和 `predictedEndTranslation` 符合我的预期, 其他的没有测试.
@available(iOS 13.0, *)
struct ZoomAndDragGesture: UIViewRepresentable {
    var onPinchChanged: (MagnifyValue) -> Void
    var onPinchEnded: () -> Void

    var onPanChanged: (DragValue) -> Void
    var onPanEnded: (DragValue) -> Void

    /// Simulate ``DragGesture.Value`` 但是存在一些差异。
    /// DragGestore.value 是根据 rect 计算的, 会出现负数。
    /// 需要 coordinateSpace 设置为 .global `translation` 和 `predictedEndLocation` 才会与 `DragValue` 的这两个值相同。
    ///
    /// 需要谨慎使用 location 和 startLocation 还有 predictedEndLocation
    public struct DragValue {
        public let time: Date
        public let location: CGPoint
        public let startLocation: CGPoint
        public let velocity: CGPoint
        public var translation: CGSize

        public var predictedEndLocation: CGPoint {
            let endTranslation = predictedEndTranslation
            return CGPoint(x: location.x + endTranslation.width, y: location.y + endTranslation.height)
        }

        public var predictedEndTranslation: CGSize {
            // 不知道哪里来的计算方法...
            // In SwiftUI's DragGesture.Value, they compute the velocity with the following:
            //     velocity = 4 * (predictedEndLocation - location)
            // Since we have the velocity, we instead compute the predictedEndLocation with:
            //     predictedEndLocation = (velocity / 4) + location
            return CGSize(
                width: velocity.x / 4.0 + translation.width,
                height: velocity.y / 4.0 + translation.height
            )
        }
    }

    /// Simulate ``ManifyGesture.Value`` 但是存在一些差异。
    /// 此处的相关坐标始终以 view 最新的 frame 计算，并且 offset 不会影响。
    /// 而 ManifyGesture.Value 需要手动计算 startAnchor 可以看下 ``ImageViewer`` 中的处理
    public struct MagnifyValue {
        /// The time associated with the gesture's current event.
        public var time: Date

        /// The relative amount that the gesture has magnified by.
        ///
        /// A value of 2.0 means that the user has interacted with the gesture
        /// to increase the magnification by a factor of 2 more than before the
        /// gesture.
        public var magnification: CGFloat

        /// The current magnification velocity.
        public var velocity: CGFloat

        /// The initial anchor point of the gesture in the modified view's
        /// coordinate space.
        public var startAnchor: UnitPoint

        /// The initial center of the gesture in the modified view's coordinate
        /// space.
        public var startLocation: CGPoint
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

        let drag = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleDrag(_:))
        )
        view.addGestureRecognizer(drag)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class Coordinator: NSObject {
        var parent: ZoomAndDragGesture

        private var startDragLocation: CGPoint = .zero
        private var startPinchAnchor: UnitPoint = .center
        private var startPinchLocation: CGPoint = .zero

        init(parent: ZoomAndDragGesture) {
            self.parent = parent
        }

        @objc func handleDrag(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .cancelled, .failed, .possible:
                break
            case .began:
                startDragLocation = gesture.location(in: view)
            case .changed:
                let translation = gesture.translation(in: view)
                let value = DragValue(
                    time: Date(),
                    location: gesture.location(in: view),
                    startLocation: startDragLocation,
                    velocity: gesture.velocity(in: view),
                    translation: CGSize(width: translation.x, height: translation.y)
                )
                parent.onPanChanged(value)
            case .ended:
                let translation = gesture.translation(in: view)
                let value = DragValue(
                    time: Date(),
                    location: gesture.location(in: view),
                    startLocation: startDragLocation,
                    velocity: gesture.velocity(in: view),
                    translation: CGSize(width: translation.x, height: translation.y)
                )
                parent.onPanEnded(value)
                startDragLocation = .zero
            @unknown default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .possible, .cancelled, .failed:
                break
            case .began:
                /// 缩放手势的中心点就是: gesture.location(in: view) 它和下方计算结果是一致的
                /// 例: (76.0, 78.0) (76.66666412353516, 78.33332316080731)
                ///
                /// ```swift
                /// let touchPoint1 = gesture.location(ofTouch: 0, in: view)
                /// let touchPoint2 = gesture.location(ofTouch: 1, in: view)
                /// let pichCenter = CGPoint(
                ///     x: (touchPoint1.x + touchPoint2.x) / 2,
                ///     y: (touchPoint1.y + touchPoint2.y) / 2
                /// )
                /// ```
                ///
                /// 缩放中心点的 Location 与 Anchor
                /// 这两个值是相对于 view.frame 的值都是正数从左上角开始,
                /// 设置 offset 也始终从 view 的真正位置的左上角开始计算.
                startPinchLocation = gesture.location(in: view)
                /// 缩放中心点的 UnitPoint
                startPinchAnchor = UnitPoint(
                    x: startPinchLocation.x / view.frame.size.width,
                    y: startPinchLocation.y / view.frame.size.height
                )
            case .changed:
                let value = MagnifyValue(
                    time: Date(),
                    magnification: gesture.scale,
                    velocity: gesture.velocity,
                    startAnchor: startPinchAnchor,
                    startLocation: startPinchLocation
                )
                parent.onPinchChanged(value)
            case .ended:
                startPinchLocation = .zero
                startPinchAnchor = .center
                parent.onPinchEnded()
            @unknown default:
                break
            }
        }
    }
}
