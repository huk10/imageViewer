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

@available(iOS 16.4, *)
public class MultiImgViewerConfiguration {
    var spacing: CGFloat = 40
    var dismiss: (() -> Void)?
    var onClick: (() -> Void)?
    var opacity: Binding<CGFloat>?
    var offsetX: Binding<CGFloat>?
    /// TODO：默认是内部计算，为最大倍速会放大至屏幕的2倍高度。
    var maximumZoomScale: CGFloat = 1.0
    var currentIndex: Binding<Int>?
}

/// 数据加载、优化等，先不管。
@available(iOS 16.4, *)
public struct MultiImgViewer: UIViewRepresentable {
    let images: [UIImage]
    var configuration = MultiImgViewerConfiguration()

    public init(images: [UIImage]) {
        self.images = images
    }

    public func makeUIView(context: Context) -> MultiImgViewerContainer {
        MultiImgViewerContainer()
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.images = images
        uiView.configuration = configuration

        uiView.update()
    }
}

@available(iOS 16.4, *)
public extension MultiImgViewer {
    func spacing(_ value: CGFloat) -> Self {
        configuration.spacing = value
        return self
    }

    func offsetX(_ value: Binding<CGFloat>) -> Self {
        configuration.offsetX = value
        return self
    }

    func currentIndex(_ index: Binding<Int>) -> Self {
        configuration.currentIndex = index
        return self
    }

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
public class MultiImgViewerContainer: UIScrollView, UIScrollViewDelegate {
    var images: [UIImage] = []
    var startOffsetX: CGFloat = .zero
    var childrens: [ZoomableScrollView] = []
    var configuration: MultiImgViewerConfiguration!

    var totals: Int {
        return max(Int((contentSize.width + configuration.spacing) / frame.width), 1)
    }

    var currentIndex: Int {
        Int(ceil(contentOffset.x / frame.width)) + 1
    }

    init() {
        super.init(frame: .zero)

        bounces = true
        delegate = self
        isScrollEnabled = true
        isPagingEnabled = true
//        alwaysBounceHorizontal = false
        showsHorizontalScrollIndicator = false
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update() {
        /// 先简单起见，全部删除，重新创建
        if childrens.isEmpty == false {
            for child in childrens {
                child.removeFromSuperview()
            }
            childrens.removeAll()
        }
        for image in images {
            let container = ZoomableScrollView(uiImage: image, parent: self)
            container.delegate = container
            container.maximumZoomScale = configuration.maximumZoomScale

            addSubview(container)
            childrens.append(container)
        }
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
        var size = CGSize.zero
        var xPosition = CGFloat.zero
        let spacing: CGFloat = configuration.spacing

        /// subviews 还存在 UIScrollView 自身的元素。
        for subview in childrens {
            subview.frame.origin.x = xPosition
            xPosition += subview.bounds.width + spacing

            size.width += subview.bounds.width + spacing
            size.height = max(subview.bounds.height, size.height)
        }
        size.width -= spacing
        contentInset.right = spacing

        contentSize = CGSize(
            width: size.width * zoomScale,
            height: size.height * zoomScale
        )
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        configuration.offsetX?.wrappedValue = contentOffset.x - startOffsetX
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        startOffsetX = contentOffset.x
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        configuration.currentIndex?.wrappedValue = currentIndex
    }

    class GestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
        /// 允许多个手势同时执行，可以更细力度控制的，暂且直接返回 true。
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    public class ZoomableScrollView: UIScrollView, UIScrollViewDelegate {
        var image: UIImageView
        var parent: MultiImgViewerContainer
        let gestureRecognizerDelegate = GestureRecognizerDelegate()

        init(uiImage: UIImage, parent: MultiImgViewerContainer) {
            self.parent = parent

            image = UIImageView()
            image.image = uiImage
            image.contentMode = .scaleAspectFit
            image.translatesAutoresizingMaskIntoConstraints = false

            let bounds = UIScreen.main.bounds

            // 限制图片的宽度为屏幕的宽度
            image.frame.size = CGSize(
                width: bounds.width,
                height: uiImage.size.height * (bounds.width / uiImage.size.width)
            )

            /// 设置宽高为屏幕的大小
            super.init(frame: CGRect(origin: .zero, size: bounds.size))

            // MARK: UIScrollView 属性设置

            bounces = true
            bouncesZoom = true
            isScrollEnabled = true
            minimumZoomScale = 1.0
//            alwaysBounceHorizontal = false
            contentInsetAdjustmentBehavior = .never

            // MARK: 添加单击和双击手势

            let doubleTapGesture = UITapGestureRecognizer(
                target: self,
                action: #selector(handleDoubleTapGesture(_:))
            )
            doubleTapGesture.numberOfTapsRequired = 2
            addGestureRecognizer(doubleTapGesture)

            let singleTapGesture = UIShortTapGestureRecognizer(
                target: self,
                action: #selector(handleSingleTapGesture(_:))
            )
            singleTapGesture.numberOfTapsRequired = 1
            singleTapGesture.require(toFail: doubleTapGesture)
            addGestureRecognizer(singleTapGesture)

            // MARK: 添加拖动手势

            let panGesture = UIPanGestureRecognizer(
                target: self,
                action: #selector(handlePanGesture(_:))
            )

            panGesture.delegate = gestureRecognizerDelegate
            addGestureRecognizer(panGesture)

            // MARK: 关系绑定

            addSubview(image)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            adjustedContentInset()
        }

        public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }

        /// 保持居中。
        func adjustedContentInset() {
            guard let subview = subviews.first else { return }

            contentSize = CGSize(
                width: subview.bounds.width * zoomScale,
                height: subview.bounds.height * zoomScale
            )

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

        /// 处理拖动手势
        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard isZooming == false, isDragging == false else { return }
            guard parent.isDragging == false else { return }
            guard canScrollViewScrollVertically() == false else { return }

            switch gesture.state {
            case .began:
                isScrollEnabled = false
                parent.isScrollEnabled = false
            case .changed:
                let offsetY = gesture.translation(in: self).y
                frame.origin.y = offsetY
                parent.configuration.opacity?.wrappedValue = 1 - min(abs(offsetY) / 100, 1.0)
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
                parent.isScrollEnabled = true

                /// handle dismiss event
                if let dismiss = parent.configuration.dismiss, predictedEndLocation > bounds.height * 0.45 {
                    dismiss()
                }
                /// reset
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) { [weak self] in
                    self?.frame.origin.y = 0
                    self?.parent.configuration.opacity?.wrappedValue = 1.0
                }
            case .failed, .cancelled, .possible:
                isScrollEnabled = true
                parent.isScrollEnabled = true
            default:
                break
            }
        }

        /// 处理双击手势
        @objc func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
            guard maximumZoomScale > 1.0 else {
                return
            }
            if zoomScale > 1.0 {
                zoomOutAnimated()
            } else {
                zoomInAnimated(with: gesture.location(in: image))
            }
        }

        /// 处理单击手势
        @objc func handleSingleTapGesture(_ gesture: UITapGestureRecognizer) {
            parent.configuration.onClick?()
        }
    }
}

