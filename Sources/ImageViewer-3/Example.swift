//
//  Created by vvgvjks on 2024/7/28.
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

import SharedResources
import SwiftUI

#if DEBUG
@available(iOS 16.4, *)
struct MultiImageViewer: View {
    @State var images: [UIImage] = []

    var body: some View {
        GeometryReader {
            let bounds = $0.size
            /// 内部设置子元素的高度与 ScrollView 相同，SwiftUI 部分自己控制
            MultiImgViewer(images: images)
                .spacing(40)
                .maximumZoomScale(5.0)
                .frame(width: bounds.width + 40, height: bounds.height)
        }
        .ignoresSafeArea()
        .task {
            images = Array(repeating: 0, count: 4)
                .indices.map { bundleImage(name: "\($0)") }
                .compactMap { $0 }
        }
    }
}

@available(iOS 17.4, *)
#Preview {
    MultiImageViewer()
}

#endif
