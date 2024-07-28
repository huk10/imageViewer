# ImageViewer
[![MIT License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://github.com/huk10/imageViewer/blob/master/LICENSE)

内部有几个关于图片预览的实现，它们以 Telegram 的图片浏览功能作为模仿对象。
内部代码**不能直接用于生产**，仅供示例参考。

ImageViewer-4 的实现已经与 Telegram 的非常接近了。

其主要功能有：
* 支持拖拽浏览图片。
* 支持超出边界时的阻尼效果。
* 支持双指缩放图片（以缩放中心放大缩小）。
* 支持双击放大缩小图片（以点击中心放大缩小）。
* 支持拖拽惯性超出界限时的回弹动画。
* 支持小图模式下的上下滑动关闭预览。
* 支持小图模式下的上下滑动背景透明度渐变效果。

## ImageViewer-1

使用 DragGesture 模拟 ScrollView 实现单图浏览功能，支持 iOS 16 及以上版本。

初衷是仅使用 SwiftUI 实现，但是一些关键 API 都在比较靠近的版本才有，
与目标 iOS 16 不符合，故在 iOS 17 以下使用了 UIKit 的手势功能。

### 已知问题

使用手势模拟效果很差, 可能是 ScrollView 有内置的优化，手势惯性滑动如果超出屏幕会有卡顿。
这感觉是渲染的问题，也可能是实现的问题，没有 ScrollView 那种丝滑感。

* 拖拽操作不够流畅。
* 拖拽惯性超出屏幕时存在卡顿现象，可能是因为渲染速度慢导致内容无法及时更新。
* 拖拽惯性超出界限的回弹（overscroll bounce）动画效果不佳，可能是因为动画选择和阻尼算法不对。


## ImageViewer-2

使用 UIScrollView 实现的单图浏览功能。

作为单图浏览的话，与 Telegram 的目标已相差不大。

## ImageViewer-3

使用 UIScrollView 嵌套实现多图浏览器。但是还需在大数据量的使用场景做封装。

一个关键点是上下滑动的 pan 手势的 delegate 不能设置为 UIScrollView 自身。
因为 UIScrollView.panGestureRecognizer.delegate 就是这个 UIScrollView 本身，添加为 self 会导致 UIScrollView 的滚动出现问题。

### 已知问题

如果双击将图片放大，然后再返回左右切换，大力切换时存在跳过内部滚动直接切换上下张图片的现象。
这个问题 Telegram 也是存在的，如果需要解决可以考虑在图片切换至下一张时将上一张的缩放重置，这避开了这个问题，
像 iPhone 的 Photos 应用就是如此的。

## ImageViewer-4

使用 UICollectionView + UIScrollView 实现的多图浏览器。

一个关键点是上下滑动的 pan 手势的 delegate 不能设置为 UIScrollView 自身。
因为 UIScrollView.panGestureRecognizer.delegate 就是这个 UIScrollView 本身，添加为 self 会导致 UIScrollView 的滚动出现问题。

### 已知问题

存在如 ImageViewer-3 相同的问题。UIScrollView 默认行为就支持了嵌套滚动，但是还不够。

## License

ImageViewer is [MIT licensed](./LICENSE).
