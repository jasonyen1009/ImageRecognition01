//
//  ContentView.swift
//  ImageRecognition01
//
//  Created by Yen Hung Cheng on 2023/5/21.
//

import SwiftUI
import CoreML
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    
    
    @State private var inputImage: UIImage?
    @State private var predictionText = "I think this is a ..."
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false


    private var model: Resnet50Int8LUT?

    init() {
        // 初始化模型
        do {
            // 創建 Resnet50Int8LUT 模型實例，並使用空的 MLModelConfiguration 進行初始化
            model = try Resnet50Int8LUT(configuration: MLModelConfiguration())
        } catch {
            // 如果在模型初始化過程中發生錯誤，則輸出錯誤信息
            print("初始化模型時發生錯誤：\(error)")
        }
    }
    
    var body: some View {
        VStack {
            // 進行辨識的圖片
            if let inputImage = inputImage {
                Image(uiImage: inputImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo.fill")
                    .resizable()
                    .scaledToFit()
            }
            
            // prediction text
            Text(predictionText)
                .padding()
            
            HStack {
                // Camera Button
                Button(action: {
                    showCameraPicker = true
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Camera")
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(.blue)
                    .cornerRadius(40)
                }
                .sheet(isPresented: $showCameraPicker) {
                    ImagePicker(image: $inputImage, sourceType: .camera, onImagePicked: processImage)
                }
                                
                // Photo Library Button
                Button(action: {
                    showLibraryPicker = true
                }) {
                    HStack(spacing: 20) {
                        Image(systemName: "photo.stack")
                        Text("Library")
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(.blue)
                    .cornerRadius(40)
                }
                .sheet(isPresented: $showLibraryPicker) {
                    ImagePicker(image: $inputImage, sourceType: .photoLibrary, onImagePicked: processImage)
                }
            .padding()
            }
            
            
        }
        .padding()
    }
    
    func processImage(_ image: UIImage) {
        // 確認模型是否可用
        guard let model = model else { return }
        
        // 開始一個指定大小和比例的圖形上下文
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 224, height: 224), true, 2.0)
        
        // 在圖形上下文中繪製原始圖片到指定的矩形區域內
        image.draw(in: CGRect(x: 0, y: 0, width: 224, height: 224))
        
        // 從目前的圖形上下文中獲取處理後的圖片
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        // 結束目前的圖形上下文
        UIGraphicsEndImageContext()
        
        // 將處理後的圖片轉換為像素緩衝區，以供模型輸入使用
        guard let pixelBuffer = newImage.toPixelBuffer(pixelFormatType: kCVPixelFormatType_32ARGB, width: 224, height: 224) else {
            return
        }
        
        // 使用模型和輸入的像素緩衝區進行預測
        guard let prediction = try? model.prediction(image: pixelBuffer) else {
            return
        }
        
        // 從預測結果中提取預測的類別標籤
        let classLabel = prediction.classLabel
        
        // 通過移除逗號之後的額外資訊，清理類別標籤
        let cleanedLabel = cleanClassLabel(classLabel)
        
        // 獲取與預測的類別標籤相對應的概率值
        let probability = prediction.classLabelProbs[classLabel] ?? 0
        
        // 將概率值格式化為百分比字串
        let formattedProbability = String(format: "%.2f%%", probability * 100)
        
        // 使用清理後的類別標籤和格式化後的概率值設定預測文字
        predictionText = "I think this is a \(cleanedLabel) with probability \(formattedProbability)."
    }

    // 清理類別標籤，通過移除逗號之後的額外資訊（如果存在）
    func cleanClassLabel(_ classLabel: String) -> String {
        if let commaIndex = classLabel.firstIndex(of: ",") {
            return String(classLabel[..<commaIndex])
        }
        return classLabel
    }

}

// 定義一個結構(ImagePicker)，使其符合UIViewControllerRepresentable協議
struct ImagePicker: UIViewControllerRepresentable {
    
    // 定義綁定和屬性
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
   
    // 創建協調器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 創建並返回 UIImagePickerController
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        // 使用 UTType.image
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = false
        return picker
    }
    
    // 更新UIViewController
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        
    }
    
    // 定義Coordinator類，使其符合UINavigationControllerDelegate和UIImagePickerControllerDelegate協議
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        // 選取圖片後的回調方法
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                parent.image = uiImage
                parent.onImagePicked(uiImage)
            }
            picker.dismiss(animated: true)
        }
    }
}

extension UIImage {
    // 將UIImage轉換為CVPixelBuffer
    func toPixelBuffer(pixelFormatType: OSType, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: NSNumber] = [
            kCVPixelBufferCGImageCompatibilityKey as String: NSNumber(booleanLiteral: true),
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: NSNumber(booleanLiteral: true)
        ]
        
        // 創建CVPixelBuffer
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormatType, attrs as CFDictionary, &pixelBuffer)
        
        guard status == kCVReturnSuccess else {
            return nil
        }
        
        // 鎖定CVPixelBuffer 的基地址
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        // 創建CGContext
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        // 調整座標系
        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: 1.0, y: -1.0)
        
        // 繪製圖像
        UIGraphicsPushContext(context!)
        draw(in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        UIGraphicsPopContext()
        
        // 解鎖基地址並返回CVPixelBuffer
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}





struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
