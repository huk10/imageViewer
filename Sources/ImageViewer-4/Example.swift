//
//  Created by vvgvjks on 2024/7/29.
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
import SharedResources

#if DEBUG
public struct HBrowserRepresentable: UIViewRepresentable {
    var configuration = HBrowserConfiguration()

    public func makeUIView(context: Context) -> HBrowser {
        let uiView = HBrowser(delegate: context.coordinator)
        return uiView
    }

    public func updateUIView(_ uiView: HBrowser, context: Context) {
        // 更新视图
        uiView.configure()
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    public class Coordinator: NSObject, HBrowserDelegate {
        public func cellForItemAt(index: IndexPath, callback: (UIImage?) -> Void) {
            let item = index.row + 1
            callback(bundleImage(name: "\(item)"))
        }

        public func dismiss() {}
        
        public func numberOfItemsInSection(section: Int) -> Int{
            4
        }

        public func cancelPrefetchingForImteAt(index: [IndexPath]) {}
    }
}

public extension HBrowserRepresentable {
    func bindOpacity(_ opacity: Binding<CGFloat>) -> Self {
        configuration.opacity = opacity
        return self
    }

    func spacing(_ spacing: CGFloat) -> Self {
        configuration.spacing = spacing
        return self
    }

    func onClick(_ block: @escaping () -> Void) -> Self {
        configuration.onTapGesture = block
        return self
    }
}

#Preview {
    GeometryReader {
        HBrowserRepresentable()
            /// 此处需要和 frame 的宽度中的 +40 对应
            .spacing(40)
            .frame(width: $0.size.width + 40, height: $0.size.height)
    }
    .ignoresSafeArea()
}

#endif
