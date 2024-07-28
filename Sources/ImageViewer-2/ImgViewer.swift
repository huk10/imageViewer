//
//  Created by vvgvjks on 2024/7/24.
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

/// 因为 safeAreaRegions 在 16.4 提供所以只支持 16.4 以上版本，
/// 16.4 以下可以考虑修改代码使用其他方法去除安全边界。

@available(iOS 16.4, *)
class ImgViewerConfiguration {
    var dismiss: (() -> Void)?
    var onClick: (() -> Void)?
    var opacity: Binding<CGFloat>?
    var maximumZoomScale: CGFloat = 1.0
}

@available(iOS 16.4, *)
public struct ImgViewer<Content: View>: UIViewRepresentable {
    let content: Content
    let configuration = ImgViewerConfiguration()

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    public func makeUIView(context: Context) -> ZoomableScrollView<Content> {
        ZoomableScrollView(rootView: content)
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.rootView = content
        uiView.configuration = configuration
        uiView.maximumZoomScale = configuration.maximumZoomScale
        uiView.hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    }
}

@available(iOS 16.4, *)
extension ImgViewer {
    func dismiss(_ execute: @escaping () -> Void) -> Self {
        configuration.dismiss = execute
        return self
    }

    func opacity(_ value: Binding<CGFloat>) -> Self {
        configuration.opacity = value
        return self
    }

    func maximumZoomScale(_ value: CGFloat) -> Self {
        /// 最大倍数不能超过 30 倍，否则需要去 zoomInAnimated 中调整逻辑。
        configuration.maximumZoomScale = max(min(20.0, value), 1.0)
        return self
    }

    func onClick(_ execute: @escaping () -> Void) -> Self {
        configuration.onClick = execute
        return self
    }
}

@available(iOS 16.4, *)
public class ZoomableScrollView<Content: View>: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var configuration: ImgViewerConfiguration!
    var hostingController: UIHostingController<Content>

    var rootView: Content {
        get { hostingController.rootView }
        set { hostingController.rootView = newValue; setNeedsLayout() }
    }

    init(rootView: Content) {
        hostingController = UIHostingController(rootView: rootView)
        /// 要不在这里去除安全边界，要不在 SwiftUI 中去除。
        /// 否则会影响布局如：UIScrollView 忽略安全边界内部的 SwiftUI 却不会忽略。
        /// SwiftUI 中的 ignoresSafeArea() 默认是 .all 这个值对应着：safeAreaRegions
        /// 这里可以进行判断是否已在 SwiftUI 中忽略，在设置为 [] 的。
        hostingController.safeAreaRegions = []
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: .zero)

        // MARK: UIScrollView 属性设置

        bounces = true
        delegate = self
        bouncesZoom = true
        isScrollEnabled = true
        minimumZoomScale = 1.0
        alwaysBounceHorizontal = true
        contentInsetAdjustmentBehavior = .never

        // MARK: 添加单击和双击手势

        let doubleTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTapGesture(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        hostingController.view.addGestureRecognizer(doubleTapGesture)

        let singleTapGesture = UIShortTapGestureRecognizer(
            target: self,
            action: #selector(handleSingleTapGesture(_:))
        )
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        hostingController.view.addGestureRecognizer(singleTapGesture)

        // MARK: 添加拖动手势

        let panGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePanGesture(_:))
        )

        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        // MARK: 关系绑定

        addSubview(hostingController.view)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        adjustedContentInset()
    }

    /// 修正布局
    /// UIScrollView 在 updateUIView 方法中它的 bounds 可能不是最新的。可能是 .zero
    /// 这里有个链接解释：https://forums.developer.apple.com/forums/thread/691362
    ///
    /// 所以必须在这里实现布局，但是在这里实现触发频率会高很多，还好计算量不大。
    func adjustedContentInset() {
        guard let subview = subviews.first, let superview else { return }

        subview.sizeToFit()

        let cSize = subview.sizeThatFits(bounds.size)

        contentSize = CGSize(width: cSize.width * zoomScale, height: cSize.height * zoomScale)

        /// 设置 UIScrollView 与其父元素一样大
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: superview.widthAnchor),
            heightAnchor.constraint(equalTo: superview.heightAnchor),
        ])

        /// 约束最大宽度不超过 UIScrollView
        NSLayoutConstraint.activate([
            subview.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            subview.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor),
        ])

        /// 居中
        if contentSize.width < bounds.width {
            contentInset.left = (bounds.width - contentSize.width) / 2
            contentInset.right = (bounds.width - contentSize.width) / 2
        } else {
            contentInset.left = 0
            contentInset.right = 0
        }

        /// 居中
        if contentSize.height < bounds.height {
            contentInset.top = (bounds.height - contentSize.height) / 2
            contentInset.bottom = (bounds.height - contentSize.height) / 2
        } else {
            contentInset.top = 0
            contentInset.bottom = 0
        }
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews.first
    }

    /// 允许多个手势同时执行，可以更细力度控制的，暂且直接返回 true。
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    /// 检查 UIScrollView 是否可以上下滚动。
    func canScrollViewScrollVertically() -> Bool {
        guard isScrollEnabled else { return false }

        // 计算垂直方向的可滚动区域
        let verticalInsets = verticalScrollIndicatorInsets
        let contentSizeHeight = contentSize.height + verticalInsets.top + verticalInsets.bottom
        let scrollViewHeight = bounds.height - contentInset.top - contentInset.bottom

        // 如果内容大小大于滚动视图的高度，则可以滚动
        return contentSizeHeight > scrollViewHeight
    }

    /// 将 UIScrollView 的缩放还原至 1.0。
    func zoomOutAnimated() {
        UIView.animate(withDuration: 0.3, delay: .zero, options: .curveEaseOut) {
            self.setZoomScale(1.0, animated: false)
        }
    }

    /// 指定的一个坐标以它为中心将视图放大。
    func zoomInAnimated(with location: CGPoint) {
        let width = 10.0
        let height = width / (bounds.width / bounds.height)

        /// 计算需要放大的区域的矩形坐标
        let rect = CGRect(
            origin: CGPoint(x: location.x - width, y: location.y - height),
            /// 放大区域是 10*21.67，而屏幕宽度是 393 也就是说可以放大至 39 倍。
            size: CGSize(width: width, height: height)
        )

        UIView.animate(withDuration: 0.3, delay: .zero, options: .curveEaseOut) {
            self.zoom(to: rect, animated: false)
        }
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard isZooming == false else { return }
        guard isDragging == false else { return }
        guard canScrollViewScrollVertically() == false else { return }

        switch gesture.state {
        case .began:
            isScrollEnabled = false
        case .changed:
            let offsetY = gesture.translation(in: self).y
            frame.origin.y = offsetY
            configuration.opacity?.wrappedValue = 1 - min(abs(offsetY) / 100, 1.0)
        case .ended:
            // 不知道哪里来的计算方法...
            // In SwiftUI's DragGesture.Value, they compute the velocity with the following:
            //     velocity = 4 * (predictedEndLocation - location)
            // Since we have the velocity, we instead compute the predictedEndLocation with:
            //     predictedEndLocation = (velocity / 4) + location

            let velocity = gesture.velocity(in: self)
            let translationY = gesture.translation(in: self).y
            let predictedEndLocation = abs(velocity.y / 4.0 + translationY)

            isScrollEnabled = true

            /// handle dismiss event
            if let dismiss = configuration.dismiss, predictedEndLocation > bounds.height * 0.45 {
                dismiss()
                return
            }
            /// reset
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                self.frame.origin.y = 0
                self.configuration.opacity?.wrappedValue = 1.0
            }
        case .failed, .cancelled, .possible:
            isScrollEnabled = true
        default:
            break
        }
    }

    @objc func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard maximumZoomScale > 1.0 else {
            return
        }
        guard let view = hostingController.view else {
            return
        }

        if zoomScale > 1.0 {
            zoomOutAnimated()
        } else {
            zoomInAnimated(with: gesture.location(in: view))
        }
    }

    @objc func handleSingleTapGesture(_ gesture: UITapGestureRecognizer) {
        configuration.onClick?()
    }
}


