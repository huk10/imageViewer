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

struct GestureContext {
    var maxX: CGFloat
    var minX: CGFloat
    var maxY: CGFloat
    var minY: CGFloat
    var rect: CGRect
    var bounds: CGSize
}

/// 单张图片的预览:
/// * 双指缩放（以缩放中心放大缩小）。
/// * 超出边界拖拽浏览。
/// * 双击放大缩小（以点击中心放大缩小）。
/// * 超出边界的拖拽增加阻尼。
/// * 拖拽惯性出边界时增加阻尼并添加回弹动画。
/// * 小图模式时不能横向纵向同时滑动。
/// * 图片小于屏幕大小时，上下滑动，会有一个 opacity，滑动超出 100 时 = 0
///
/// 使用手势模拟效果很差, 可能是 ScrollView 有内置的优化，手势惯性滑动如果超出屏幕会有卡顿。
/// 这感觉是渲染的问题，也可能是实现的问题，没有 ScrollView 那种丝滑感。
///
/// 缺陷：
/// * 拖拽不够丝滑。
/// * 拖拽惯性超出屏幕时有时会卡顿，感觉像是前方的内容渲染的太慢，导致无法滚动过去的样子。
/// * 拖拽惯性超出界限的回弹（overscroll bounce），效果并不好（可能是动画没选好和阻尼算法不对）。
public struct ImageViewer: View {
    let image: UIImage
    var dismiss: (() -> Void)? = nil
    
    public init(image: UIImage, dismiss: @escaping () -> Void) {
        self.image = image
        self.dismiss = dismiss
    }

    /// 拖动超出边界的阻尼.
    private let damping = 0.35

    /// 根据手势上下滑动距离计算的透明度.
    /// 滑动距离超过 100 就会完全透明.
    @State var opacity: CGFloat = 1.0
    @State private var uiImage: UIImage? = nil

    @State private var maxSize: CGSize = .zero
    @State private var minSize: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    @State private var startAnchor: UnitPoint = .center

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragTime: Double = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var dragDirection: Axis? = nil

    private func loadImage(bounds: CGSize, nativeScale: CGFloat) async {
        minSize = CGSize(width: bounds.width, height: bounds.width / image.size.width * image.size.height)
        
        var height = image.scale >= scale ? image.size.height : image.size.height / scale

        /// 默认可以放大至屏幕高度的 2.5 倍
        height = max(bounds.height * 2.5, height)

        maxSize = CGSize(width: height / minSize.height * minSize.width, height: height)
        
        imageSize = minSize
        self.uiImage = image
    }

    public var body: some View {
        GeometryReader {
            let bounds = $0.size
            VStack {
                /// 目前的布局 frame 放大时是以左上角进行放大的.
                GeometryReader {
                    let rect = $0.frame(in: .global)
                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageSize.width, height: imageSize.height)
                            .offset(x: dragOffset.width + offset.width, y: dragOffset.height + offset.height)
                            .coordinateSpace(name: "IMAGE-CORP")
                            .animation(.easeInOut, value: imageSize)
                            .modify { content in
                                if #available(iOS 17, *) {
                                    self.SwiftUIGesture(rect, bounds, content: content)
                                } else {
                                    self.UIKitGesture(rect, bounds, content: content)
                                }
                            }
                    }
                }
                .frame(width: minSize.width, height: minSize.height)
            }
            .frame(width: bounds.width, height: bounds.height, alignment: .center)
            .task {
                await loadImage(bounds: bounds, nativeScale: 3)
            }
        }
        .ignoresSafeArea()
    }

    /// 各个手势都会使用到的一些信息。
    /// rect 和 bounds 的值都是固定的不会变的。
    private func gestureContextBuilder(_ rect: CGRect, _ bounds: CGSize) -> GestureContext {
        /// 这些事以 UnintPoint.center 为坐标的边界.
        ///    maxX: -rect.minX,
        ///    minX: -(rect.minX + imageSize.width - bounds.width),
        ///    maxY: maxSize.height / 2 - rect.midY,
        ///    minY: -(maxSize.height / 2 - rect.midY),
        ///    rect: rect,
        ///    bounds: bounds

        var maxY = -rect.minY
        var minY = -(maxSize.height - bounds.height + rect.minY)
        if imageSize.height < bounds.height {
            maxY = -(imageSize.height - minSize.height) / 2
            minY = -(imageSize.height - minSize.height) / 2
        }
        return GestureContext(
            maxX: 0,
            minX: -(imageSize.width - bounds.width),
            maxY: maxY,
            minY: minY,
            rect: rect,
            bounds: bounds
        )
    }

    @ViewBuilder
    private func UIKitGesture(_ rect: CGRect, _ bounds: CGSize, content: some View) -> some View {
        content
            /// 需要部署到 iOS 16 MagnifyGesture 仅支持 iOS 17, 故而需要使用 UIKit 中的手势实现.
            /// iOS 16.6(真机调试) UIKit 的手势和 DragGesture 一起使用存在问题(缩放手势非常不灵敏).
            /// 所以需要全部在 UIKit 中实现而 iOS 16.4 (模拟器) 和 iOS 17.5 (模拟器)都没有这个问题.
            /// UIKit 中的手势与 SwiftUI 的手势, 在很多坐标的计算方式上都有差异.
            .overlay(
                ZoomAndDragGesture(
                    onPinchChanged: {
                        /// 目前只使用 magnification 和 startAnchor 只验证过这两个.
                        let context = gestureContextBuilder(rect, bounds)
                        onPinchZoomChanged(context, $0.magnification, $0.startAnchor)
                    },
                    onPinchEnded: {
                        onPinchZoomEnded(gestureContextBuilder(rect, bounds))
                    },
                    onPanChanged: {
                        dragTime = Date().timeIntervalSince1970 * 1000
                        onDragChanged(gestureContextBuilder(rect, bounds), $0.translation)
                    },
                    onPanEnded: {
                        /// UIKit 的手势没有一个对应的 predictedEndTranslation 需要自己计算.
                        /// 停顿超过 10 毫秒就不在使用 predictedEndTranslation .

                        /// velocity 比较轻巧的都在 1400 左右, 一般的用力 在 4000 左右
                        /// 最用力为 10000 左右.
                        if Int64(Date().timeIntervalSince1970 * 1000) - Int64(dragTime) > 10 {
                            onDragEnded(gestureContextBuilder(rect, bounds), $0.translation)
                        } else {
                            onDragEnded(gestureContextBuilder(rect, bounds), $0.predictedEndTranslation)
                        }
                    }
                )
                /// animation 修饰器貌似不能间接传递给 UIViewRepresentable
                /// withAnimation 方法也不行.
                /// 不过这里不加动画应该也不影响.
                .offset(x: dragOffset.width + offset.width, y: dragOffset.height + offset.height)
                .animation(.easeInOut, value: offset)
                .animation(.easeInOut, value: imageSize)
                .animation(.easeInOut, value: dragOffset)
            )
            /// SwiftUI 中使用这个手势要放前面, 与 UIKit 使用时要放后面...
            .gesture(
                SpatialTapGesture(count: 2, coordinateSpace: .named("IMAGE-CORP"))
                    .onEnded {
                        onSpatialTagGesture(gestureContextBuilder(rect, bounds), $0)
                    }
            )
    }

    /// 内部的一些定位还没有适配好
    @available(iOS 17.0, *)
    @ViewBuilder
    private func SwiftUIGesture(_ rect: CGRect, _ bounds: CGSize, content: some View) -> some View {
        content
            .gesture(
                SpatialTapGesture(count: 2, coordinateSpace: .named("IMAGE-CORP"))
                    .onEnded {
                        onSpatialTagGesture(gestureContextBuilder(rect, bounds), $0)
                    }
            )
            .gesture(
                SimultaneousGesture(
                    /// 这个手势虽然放在这里, 其实它不需要覆盖这个元素上面, 它只需要覆盖在 boundes 上就行.
                    /// 这里 coordinateSpace 只能选择 .global 否则会有剧烈波动, 他会收到 offset 影响.
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged {
                            /// DragGestore.value.location 是根据 rect 计算的, 会出现负数.
                            /// 需要 coordinateSpace 设置为 .global 才符合预期。
                            dragTime = Date().timeIntervalSince1970 * 1000
                            onDragChanged(gestureContextBuilder(rect, bounds), $0.translation)
                        }
                        .onEnded {
                            if Int64(Date().timeIntervalSince1970 * 1000) - Int64(dragTime) > 5 {
                                onDragEnded(gestureContextBuilder(rect, bounds), $0.translation)
                            } else {
                                onDragEnded(gestureContextBuilder(rect, bounds), $0.predictedEndTranslation)
                            }
                        },
                    MagnifyGesture()
                        .onChanged {
                            /// 它这个 startAnchor 不符合我们的预期
                            /// 它这个 startLocation 倒是可以配合 offset 计算出 startAnchor
                            if startAnchor == .center {
                                let location = CGPoint(
                                    x: $0.startLocation.x + abs(offset.width),
                                    y: $0.startLocation.y + abs(offset.height)
                                )
                                let anchor = UnitPoint(
                                    x: location.x / imageSize.width,
                                    y: location.y / imageSize.height
                                )
                                startAnchor = anchor
                            }
                            onPinchZoomChanged(gestureContextBuilder(rect, bounds), $0.magnification, startAnchor)
                        }
                        .onEnded { _ in
                            startAnchor = .center
                            onPinchZoomEnded(gestureContextBuilder(rect, bounds))
                        }
                )
            )
    }

    /// 响应图片的 DragGesture
    ///
    /// - 当图片的高度小于屏幕的高度时, 一次只能上下滑动或者左右滑动
    /// - 左右拖动如果超出边界会增加阻尼.
    /// - 高度超出屏幕高度时: 上下左右拖动如果超出边界时也会增加阻尼.
    private func onDragChanged(_ ctx: GestureContext, _ value: CGSize) {
        var translation = value
        if translation.width == .zero, translation.height == .zero {
            return
        }

        /// 计算此次滑动的方向, 应该更优先上下滑动
        if dragDirection == nil, translation.width != .zero || translation.width != .zero {
            if abs(translation.width) > abs(translation.height) {
                dragDirection = Axis.horizontal
            } else {
                dragDirection = Axis.vertical
            }
        }

        let offsetX = offset.width + translation.width
        let offsetY = offset.height + translation.height

        if imageSize.height <= ctx.bounds.height {
            /// 当图片的高度小于屏幕的高度时, 一次只能上下滑动或者左右滑动
            /// 上下滑动, 背景会百分比透明, 停止时可能会触发关闭事件.
            /// 左右滑动, 停止时可能会触发切换下一张或上一张图片的事件.
            if dragDirection == .vertical {
                dragOffset.height = translation.height
                opacity = 1.0 - max(min(abs(translation.height) / 100, 1.0), 0.0)
                return
            }

            /// 如果没有上一张图片或下一张图片, 则增加阻尼.
            if (translation.width > 0) || (translation.width < 0) {
                dragOffset.width = translation.width * damping
            } else {
                dragOffset.width = translation.width
            }
            return
        }

        /// 边界处理, 超出后增加阻尼.
        if offsetY > ctx.maxY {
            translation.height -= abs(offsetY - ctx.maxY) * (1 - damping)
        }
        if offsetY < ctx.minY {
            translation.height += abs(ctx.minY - offsetY) * (1 - damping)
        }
        if offsetX > ctx.maxX {
            translation.width -= abs(offsetX - ctx.maxX) * (1 - damping)
        }
        if offsetX < ctx.minX {
            translation.width += abs(ctx.minX - offsetX) * (1 - damping)
        }
        withAnimation(.easeOut) {
            dragOffset = translation
        }
    }

    /// 处理拖拽停止后的回弹和重置操作.
    /// - 如果图片的高度小于 bounds.height 则上下拖动时背景会变成透明色,
    /// - 并且拖动达到一定距离(imageSize.height * 0.4), 触发 dismiss 事件.
    private func onDragEnded(_ ctx: GestureContext, _ value: CGSize) {
        /// 状态重置
        dragDirection = nil
        /// 偏移量
        let offsetX = offset.width + value.width
        let offsetY = offset.height + value.height

        if imageSize.height <= ctx.bounds.height {
            /// 检查上下滑动距离是否超出 dismiss 的阈值.
            /// 图片高度小于屏幕高度时, 一次只能触发上下或左右滑动的其中一个.
            /// 这里只需处理 height.
            if let dismiss, abs(offsetY) > imageSize.height * 0.4 {
                /// 是否应该等待动画结束时关闭的.
                if #available(iOS 17.0, *) {
                    withAnimation(.spring()) {
                        offset.height = offsetY
                    } completion: {
                        dismiss()
                    }
                } else {
                    withAnimation(.spring(duration: 0.2)) {
                        offset.height = offsetY
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        dismiss()
                    }
                }
                return
            }

            withAnimation(.snappy) {
                opacity = .zero
                dragOffset = .zero
                offset.height = max(ctx.minY, min(offsetY, ctx.maxY))
                offset.width = max(ctx.minX, min(offsetX, ctx.maxX))
            }
            return
        }

        /// 处理惯性出边界的回弹效果.
        /// 效果比较一般, 需要优化.
        if #available(iOS 17.0, *) {
            withAnimation(.linear) {
                opacity = .zero
                dragOffset = .zero
                offset.width = appendDamping(ctx.minX, ctx.maxX, offsetX)
                offset.height = appendDamping(ctx.minY, ctx.maxY, offsetY)
            } completion: {
                withAnimation(.easeOut) {
                    offset.width = max(ctx.minX, min(offsetX, ctx.maxX))
                    offset.height = max(ctx.minY, min(offsetY, ctx.maxY))
                }
            }
        } else {
            withAnimation(.linear(duration: 0.2)) {
                opacity = .zero
                dragOffset = .zero
                offset.width = appendDamping(ctx.minX, ctx.maxX, offsetX)
                offset.height = appendDamping(ctx.minY, ctx.maxY, offsetY)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut) {
                    offset.width = max(ctx.minX, min(offsetX, ctx.maxX))
                    offset.height = max(ctx.minY, min(offsetY, ctx.maxY))
                }
            }
        }
    }

    /// 计算拖拽惯性超出边界时, 超出边界部分收到阻尼后的结果.
    private func calculateDamping(offset: CGFloat) -> CGFloat {
        /// 这里传入的是 predictedEndTranslation 与 translation 的插值.
        /// velocity 比较轻巧的都在 1400 左右, 一般的用力在 4000 左右, 最用力为 10000 左右.
        /// UIKit 的实现是 velocity / 4 + value 这个值和 SwiftUI 的差别不是很大.
        /// 这里传入的值是已经 / 4 过的了, 返回值在 1 ~ 250, 线性的.
        min(max(10, offset), 2500) / 10 * 0.75
    }
    /// 阻尼算法2：chatgpt 给的
    /// 与 calculateDamping 的输出差不多，只是这个是非线性的。
    ///     distance: 10.0,   dampenedDistance: 1.6351009657391071 calculateDamping: 0.75
    ///     distance: 100.0,  dampenedDistance: 11.139813200670671 calculateDamping: 7.5
    ///     distance: 500.0,  dampenedDistance: 42.59443991706685  calculateDamping: 37.5
    ///     distance: 1000.0, dampenedDistance: 75.89466384404112  calculateDamping: 75.0
    ///     distance: 2000.0, dampenedDistance: 135.2289174646964  calculateDamping: 150.0
    ///     distance: 3000.0, dampenedDistance: 189.5886295702802  calculateDamping: 187.5
    private func dampenedDistance(for distance: CGFloat) -> CGFloat {
        let clampedDistance = min(max(distance, 1), 3000)
        let dampingFactor: CGFloat = 0.24
        let maxDampenedDistance: CGFloat = 300
        let exponent: CGFloat = 1.2
        let dampenedDistance = pow(clampedDistance, 1 / exponent) * dampingFactor
        return min(dampenedDistance, maxDampenedDistance)
    }


    /// 对超出边界的 offset 添加阻尼
    private func appendDamping(_ min: CGFloat, _ max: CGFloat, _ offset: CGFloat) -> CGFloat {
        if offset > max {
            return max + calculateDamping(offset: offset - max)
        }
        if offset < min {
            return min - calculateDamping(offset: min - offset)
        }
        return offset
    }

    /// 响应双击操作-将图片以点击位置为中心进行放大或者重置.
    /// - 如果当前宽度比最小宽度大至少 50 的距离就进行缩小.
    private func onSpatialTagGesture(_ ctx: GestureContext, _ value: SpatialTapGesture.Value) {
        /// 如果图片已经大于 minSize 一定程度以上, 则重置图片大小.
        if imageSize.width - minSize.width > 50.0 {
            offset = .zero
            imageSize = minSize
            return
        }

        /// 转换点击位置的新坐标
        let clickAnchor = UnitPoint(x: value.location.x / imageSize.width, y: value.location.y / imageSize.height)

        /// 已经 offset 过的距离.
        /// 如果父级元素的 frame 没有固定, 放大的中心是: UnitPoint(x: 0, y: 0.5)
        /// 否则放大的中心是: UnitPoint(x: 0, y: 0)
        let defaultAnchor = UnitPoint(x: 0, y: 0)

        /// 还需要 offset 的距离
        let anchor = UnitPoint(x: clickAnchor.x - defaultAnchor.x, y: clickAnchor.y - defaultAnchor.y)

        /// 放大的相对距离
        let distanceX = maxSize.width - imageSize.width
        let distanceY = maxSize.height - imageSize.height

        imageSize = maxSize
        /// 这里需要重新计算.
        let ctx2 = gestureContextBuilder(ctx.rect, ctx.bounds)
        offset.width = -distanceX * anchor.x
        offset.height = max(min(ctx2.maxY, -distanceY * anchor.y), ctx2.minY)
    }

    /// 按照缩放的中心位置并将缩放应用与 frame 和 offset 而不是 scaleEffect.
    ///
    /// - 目前的算法需要保证 offset 与 point 是符合的是对应的.
    private func onPinchZoomChanged(_ ctx: GestureContext, _ value: CGFloat, _ anchor: UnitPoint) {
        let delta = value / scale
        let damping: CGFloat = 0.7
        let scaleValue = 1.0 + (delta - 1) * damping

        /// 缩放后大小
        var afterWidth = imageSize.width * scaleValue
        var afterHeight = imageSize.height * scaleValue

        /// 修正最小值
        if afterWidth < minSize.width * 0.5 {
            afterWidth = minSize.width * 0.5
            afterHeight = minSize.height * 0.5
        }
        /// 修正最大值
        if afterHeight > maxSize.height {
            afterWidth = maxSize.width
            afterHeight = maxSize.height
        }

        /// 已经 offset 过的距离.
        let defaultAnchor = UnitPoint(x: 0, y: 0)

        /// 还需要 offset 的距离
        let offsetAnchor = UnitPoint(x: anchor.x - defaultAnchor.x, y: anchor.y - defaultAnchor.y)

        /// 放大的相对距离
        let distanceX = afterWidth - imageSize.width
        let distanceY = afterHeight - imageSize.height

        scale = value
        imageSize.width = afterWidth
        imageSize.height = afterHeight
        offset.width += -distanceX * offsetAnchor.x
        offset.height += -distanceY * offsetAnchor.y
    }

    /// 处理缩放停止后的回弹和重置操作.
    ///
    /// - 缩小的比 bounds.width 还小时, 回调时会有一个震动反馈.
    private func onPinchZoomEnded(_ ctx: GestureContext) {
        scale = 1.0
        /// 如果缩放后小于最小值, 则重置为最小值.
        if imageSize.width <= minSize.width {
            offset = .zero
            imageSize = minSize
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        let offsetX = max(ctx.minX, min(offset.width, ctx.maxX))
        let offsetY = max(ctx.minY, min(offset.height, ctx.maxY))

        withAnimation(.easeOut) {
            offset.height = offsetY
            offset.width = offsetX
        }
    }
}
