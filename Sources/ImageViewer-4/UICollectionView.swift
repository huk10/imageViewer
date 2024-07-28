//
//  Created by vvgvjks on 2024/7/26.
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

import Foundation
import SwiftUI
import UIKit
import SharedResources

/// UICollectionView + UIScrollView 实现图片浏览器功能。
/// 
/// UICollectionViewFlowLayout 内部应该已经处理了与 UIScrollView 的通向滚动冲突问题。
///
/// 这个处理如果使用 UIScrollView 实现会比较麻烦。
///
/// 不过思路应该还是：gestureRecognizer 的 shouldRecognizeSimultaneouslyWith 方法
///
/// 检查如果是父 UIScrollView 和子 UIScrollView 的 pan 手势，让他们不同时识别成功。
///
/// 但是存在一个问题这个方法不能貌似保证哪个 pan 手势会失败，发现突然大力滚动一下，拦截会失效。
///

public protocol HBrowserDelegate: NSObject {
    /// 触发关闭浏览器的行为
    func dismiss() -> Void
    /// 需要处理以下场景
    /// 1. 正在加载中
    /// 2. 数据还没有加载
    /// 3. 数据已加载完成
    func cellForItemAt(index: IndexPath, callback: (UIImage?) -> Void)
    
    func numberOfItemsInSection(section: Int) -> Int

    /// 需要返回一个 UIView 内容。
    /// 这个 UIView 需要是一个 UIScrollView 的实例，使用方自行处理，缩放等其他手势？
    /// 不然使用方对双击、单击、其他手势可能不太好处理。
    /// func cellForItemAt(index: IndexPath) -> UIView

    /// 重置属性以便复用
    /// func resetForCell(cell: UICollectionViewCell) -> Void

    /// 取消数据预取请求
    func cancelPrefetchingForImteAt(index: [IndexPath]) -> Void
}

class HBrowserConfiguration {
    var spacing: CGFloat = 40
    var opacity: Binding<CGFloat>?
    var onTapGesture: (() -> Void)?
}

/// 原来 UICollectionView 内部已经处理了滚动冲突的问题。。。
/// UIScrollView 处理很是麻烦，而且还需自己处理大数据的加载。
/// 真是：方向不对，努力白费。
/// 先是尝试只使用 iOS 16 的 SwiftUI 自己处理手势模拟滚动实现。效果很差，就没有考虑多图的处理。
/// Telegram 也存在这个问题。
/// 然后是 UIScrollView 嵌套，手势处理半天还差点意思。
/// 将 decelerationRate 设置为 .fast 就无比正常，不设置 可能内部的 UIScrollView 滚动没有结束
public class HBrowser: UICollectionView {
    let spacing: CGFloat = 40.0
    var layout: UICollectionViewFlowLayout
    var browserDelegate: HBrowserDelegate

    public init(delegate: HBrowserDelegate) {
        browserDelegate = delegate
        layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = spacing
        super.init(frame: .zero, collectionViewLayout: layout)
        setupCollectionView()
    }

    func setupCollectionView() {
        bounces = true
        dataSource = self
        isPagingEnabled = true
        backgroundColor = .clear
        /// decelerationRate = .fast
        alwaysBounceHorizontal = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        translatesAutoresizingMaskIntoConstraints = false

        /// panGestureRecognizer.delegate 已经有值了是 UICollectionViewFlowLayout
        register(HBrowserCell.self, forCellWithReuseIdentifier: "cell")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        contentInset.right = spacing
        layout.minimumLineSpacing = spacing
        layout.itemSize = CGSize(width: bounds.width - spacing, height: bounds.size.height)
    }

    /// updateUIView 更新内部状态，主要是 HBrowserConfiguration 中的配置。
    /// HBrowserDelegate 不需要更新。
    public func configure() {
        // TODO: configure
        // layout.minimumLineSpacing = HBrowserConfiguration.spacing
    }
}

extension HBrowser: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        browserDelegate.numberOfItemsInSection(section: section)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? HBrowserCell else {
            fatalError("UICollectionView -> HBrowserCell Fail")
        }
        cell.reset()
        cell.container = self
        cell.delegate = browserDelegate
        cell.backgroundColor = UIColor.clear

        /// 这里 bounds 有值了 但是 layout.itemSize 还是没有设置,
        /// 因为 layout.itemSize 是在 layoutSubviews 中设置的。
        /// 所以此处 configure 方法中也是无法获取到正确的 bounds 和 frame 的。
        /// 所以都需要再 layoutSubviews 中布局和设置 frame。
        browserDelegate.cellForItemAt(index: indexPath) { uiImage in
            /// 初始状态应该是 loading 视图。
            /// 在最初时应该先设置 blurHash 和 loading 提示。
            /// 在图片资源下载后，在使用最终的图像内容替换 blurHash 和 loading。
            if let uiImage {
                cell.configure(with: uiImage)
            } else {
                // TODO: handle fail
            }
        }
        return cell
    }
}

extension HBrowser: UICollectionViewDataSourcePrefetching {
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            _ = self.collectionView(collectionView, cellForItemAt: indexPath)
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        browserDelegate.cancelPrefetchingForImteAt(index: indexPaths)
    }
}

// MARK: UICollectionViewCell

public class HBrowserCell: UICollectionViewCell {
    var container: HBrowser?
    /// 下面两个是否通过 container 持有好些？
    var delegate: HBrowserDelegate?
    var configuration: HBrowserConfiguration?

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.bounces = true
        scrollView.delegate = self
        scrollView.bouncesZoom = true
        scrollView.isScrollEnabled = true
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        /// scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(imageView)

        return scrollView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureGestureRecognizer()
        contentView.addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        /// bounds.width == scrollView.bounds.width == imageView.bounds.width
        if let image = imageView.image {
            imageView.frame = CGRect(
                x: 0, y: 0,
                width: bounds.width,
                height: image.size.height * (bounds.width / image.size.width)
            )

            calculateImageMaxZoomScaleValue()
        }

        scrollView.frame = CGRect(origin: .zero, size: bounds.size)
        scrollView.contentSize = imageView.bounds.size
        adjustedContentInset()
    }

    /// 计算 contentInset 以保持居中
    /// TODO: UIScrollView 应该子类化，将双击放大等操作包装在内部，不然就需要调用 Cell.layoutSubviews 方法。
    private func adjustedContentInset() {
        /// 居中
        if scrollView.contentSize.width < scrollView.bounds.width {
            scrollView.contentInset.left = (bounds.width - scrollView.contentSize.width) / 2
            scrollView.contentInset.right = (bounds.width - scrollView.contentSize.width) / 2
        } else {
            scrollView.contentInset.left = 0
            scrollView.contentInset.right = 0
        }

        /// 居中
        if scrollView.contentSize.height < bounds.height {
            scrollView.contentInset.top = (bounds.height - scrollView.contentSize.height) / 2
            scrollView.contentInset.bottom = (bounds.height - scrollView.contentSize.height) / 2
        } else {
            scrollView.contentInset.top = 0
            scrollView.contentInset.bottom = 0
        }
    }

    /// 计算出一个合适的最大缩放值。
    /// TODO: 支持覆盖此逻辑，传入最大缩放值，或者接受一个方法返回一个值。
    private func calculateImageMaxZoomScaleValue() {
        guard let uiImage = imageView.image else { return }

        /// 默认是使用最佳效果。
        let scale = imageView.window?.windowScene?.screen.nativeScale ?? 3
        var height = uiImage.scale >= scale ? uiImage.size.height : uiImage.size.height / scale

        /// 默认可以放大至屏幕高度的 2.5 倍
        height = max(bounds.height * 2.5, height)

        scrollView.maximumZoomScale = height / imageView.bounds.height
    }

    /// 添加手势处理器
    private func configureGestureRecognizer() {
        // MARK: 添加双击手势

        let doubleTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTapGesture(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)

        // MARK: 添加单击手势

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

        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }
}

// MARK: UIScrollViewDelegate

extension HBrowserCell: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

// MARK: UIGestureRecognizerDelegate

extension HBrowserCell: UIGestureRecognizerDelegate {
    /// 在内部添加了 pan 手势处理上下滑动 dismiss 的操作。
    /// 这里需要返回 true 否则 UICollectionView 的滚动会失效。
    /// 但是在 pan 手势内部需要处理，如果 UIScrollView 或者 UICollectionView 正在滚动就需要取消处理，也就是不能同时滚动。
    /// TODO: pan 手势滚动停止，还能触发 UICollectionView 的滚动，需要处理。
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: public function

public extension HBrowserCell {
    /// 在 UIImage 加载成功后调用此方法，设置 ImageView 的内容。
    /// 调用此方法时，Cell 可能还没有被添加到 collection 中.
    func configure(with uiImage: UIImage) {
        imageView.image = uiImage
        /// 内部会自动处理布局
    }

    /// 在 cell 被复用的时候重置属性。
    func reset() {
        imageView.image = nil
        imageView.frame = .zero
        scrollView.zoomScale = .zero
        scrollView.contentOffset = .zero
    }
}

// MARK: private gesture handle function

private extension HBrowserCell {
    /// 将 UIScrollView 的缩放还原至 1.0。
    func zoomOutAnimated() {
        UIView.animate(withDuration: 0.3, delay: .zero, options: .curveEaseOut) {
            self.scrollView.setZoomScale(1.0, animated: false)
        }
    }

    /// 指定的一个坐标以它为中心将视图放大。
    func zoomInAnimated(with location: CGPoint) {
        let width = 10.0
        let height = width / (scrollView.bounds.width / scrollView.bounds.height)

        /// 计算需要放大的区域的矩形坐标
        let rect = CGRect(
            origin: CGPoint(x: location.x - width, y: location.y - height),
            /// 放大区域是 10*21.67，而屏幕宽度是 393 也就是说可以放大至 39 倍。
            size: CGSize(width: width, height: height)
        )

        UIView.animate(withDuration: 0.3, delay: .zero, options: .curveEaseOut) {
            self.scrollView.zoom(to: rect, animated: false)
        }
    }

    /// 检查 UIScrollView 是否可以上下滚动
    func canScrollVertically() -> Bool {
        guard scrollView.isScrollEnabled else { return false }

        // 计算垂直方向的可滚动区域
        let contentInset = scrollView.contentInset
        let verticalInsets = scrollView.verticalScrollIndicatorInsets
        let contentSizeHeight = scrollView.contentSize.height + verticalInsets.top + verticalInsets.bottom
        let scrollViewHeight = scrollView.bounds.height - contentInset.top - contentInset.bottom

        // 如果内容大小大于滚动视图的高度，则可以滚动
        return contentSizeHeight > scrollViewHeight
    }

    /// 处理拖动手势
    /// TODO: 拖动时 UICollectionView 不应该滚动。
    /// 这个手势需要提升至 UICollectionView 但是这个需要判断当前页是否可以滚动，
    /// 即 contentSize.height 是否大于 bounds.height
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard !scrollView.isZooming, !scrollView.isDragging else { return }
        guard container?.isDragging == false else { return }
        guard canScrollVertically() == false else { return }

        switch gesture.state {
        case .began:
            scrollView.isScrollEnabled = false
            container?.isScrollEnabled = false
        case .changed:
            let offsetY = gesture.translation(in: self).y
            scrollView.frame.origin.y = offsetY
            configuration?.opacity?.wrappedValue = 1 - min(abs(offsetY) / 100, 1.0)
        case .ended:
            // 不知道哪里来的计算方法...
            // In SwiftUI's DragGesture.Value, they compute the velocity with the following:
            //     velocity = 4 * (predictedEndLocation - location)
            // Since we have the velocity, we instead compute the predictedEndLocation with:
            //     predictedEndLocation = (velocity / 4) + location

            let velocity = gesture.velocity(in: self)
            let translationY = gesture.translation(in: self).y
            let predictedEndLocation = abs(velocity.y / 4.0 + translationY)

            scrollView.isScrollEnabled = true
            container?.isScrollEnabled = true

            /// handle dismiss event
            let threshold = scrollView.bounds.height * 0.45
            if let dismiss = delegate?.dismiss, predictedEndLocation > threshold {
                dismiss()
                /// 这里不直接 return 防止 Delegate 实现了这个方法但是没有马上关闭和销毁
            }
            /// reset
            /// 注意这里使用弱引用，放在上面 dismiss 直接把 self 给销毁了。
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) { [weak self] in
                self?.scrollView.frame.origin.y = 0
                self?.configuration?.opacity?.wrappedValue = 1.0
            }
        case .failed, .cancelled, .possible:
            scrollView.isScrollEnabled = true
            container?.isScrollEnabled = true
        default:
            break
        }
    }

    /// 处理双击手势
    @objc func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard scrollView.maximumZoomScale > 1.0 else {
            return
        }
        if scrollView.zoomScale > 1.0 {
            zoomOutAnimated()
        } else {
            zoomInAnimated(with: gesture.location(in: imageView))
        }
        // TODO: UIScrollView 应该子类化，将双击放大等操作包装在内部，
        adjustedContentInset()
        scrollView.setNeedsLayout()
    }

    /// 处理单击手势
    @objc func handleSingleTapGesture(_ gesture: UITapGestureRecognizer) {
        configuration?.onTapGesture?()
    }
}


