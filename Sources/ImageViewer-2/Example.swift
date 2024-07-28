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

import SwiftUI
import SharedResources

#if DEBUG

extension Image {
    init(boundle: String) {
        self.init(uiImage: bundleImage(name: boundle)!)
    }
}

@available(iOS 17.0, *)
struct ImageViewer: View {

    @State private var opacity: CGFloat = 1.0

    @State private var maxZoom: CGFloat = 8.0

    @State private var isOpenViewer: Bool = false
    @State private var isOpenOperationLayer: Bool = true

    var body: some View {
        ZStack {
            VStack {
                Image(boundle: "1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .onTapGesture {
                        withAnimation {
                            isOpenViewer.toggle()
                        }
                    }
            }
            
            if isOpenViewer {
                VStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                            .opacity(opacity)

                        GeometryReader {
                            let bounds = $0.size

                            ImgViewer {
                                Image(boundle: "1")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: bounds.width)
                            }
                            .opacity($opacity)
                            .maximumZoomScale(maxZoom)
                            .dismiss {
                                withAnimation {
                                    isOpenViewer.toggle()
                                    opacity = 1.0
                                }
                            }
                            .onClick {
                                withAnimation(.easeOut) {
                                    isOpenOperationLayer.toggle()
                                }
                            }
                            .frame(width: bounds.width, height: bounds.height)
                        }
                        .ignoresSafeArea()

                        VStack {
                            HStack {
                                Button {
                                    withAnimation {
                                        isOpenViewer.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("返回")
                                    }
                                }

                                Spacer()
                                Text("182/315")
                                Spacer()
                                Text("返回").hidden()
                                Image(systemName: "ellipsis.circle")
                            }
                            .offset(y: isOpenOperationLayer ? 0 : -100)
                            .padding(.horizontal)
                            Spacer()
                            HStack {
                                Image(systemName: "arrowshape.turn.up.right")
                                Spacer()
                                VStack {
                                    Text("视频集合")
                                    Text("05/09/24")
                                }
                                Spacer()
                                Image(systemName: "trash")
                            }
                            .offset(y: isOpenOperationLayer ? 0 : 100)
                            .padding(.horizontal)
                        }
                        .foregroundStyle(Color.white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


@available(iOS 17.0, *)
#Preview {
    ImageViewer()
}

#endif
