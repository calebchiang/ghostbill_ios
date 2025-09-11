//
//  ReceiptScannerView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import AVFoundation

struct ReceiptScannerView: UIViewControllerRepresentable {
    var onComplete: (_ images: [UIImage]) -> Void
    var onCancel: () -> Void = {}
    var onError: (_ error: Error) -> Void = { _ in }

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onComplete = onComplete
        vc.onCancel = onCancel
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
        var onComplete: ((_ images: [UIImage]) -> Void)?
        var onCancel: (() -> Void)?
        var onError: ((_ error: Error) -> Void)?

        private let captureSession = AVCaptureSession()
        private let photoOutput = AVCapturePhotoOutput()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var overlayLayer: CAShapeLayer?

        override func viewDidLoad() {
            super.viewDidLoad()

            captureSession.sessionPreset = .photo
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                onError?(NSError(domain: "CameraError", code: -1, userInfo: nil))
                return
            }

            if captureSession.canAddInput(input) { captureSession.addInput(input) }
            if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds
            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }

            addOverlay()
            addCaptureButton()

            captureSession.startRunning()
        }

        private func addOverlay() {
            let overlay = CAShapeLayer()
            let path = UIBezierPath(rect: view.bounds)

            let inset: CGFloat = view.bounds.width * 0.15
            let focusRect = CGRect(x: inset,
                                   y: 0,
                                   width: view.bounds.width - inset * 2,
                                   height: view.bounds.height)

            let transparentPath = UIBezierPath(rect: focusRect)
            path.append(transparentPath.reversing())

            overlay.path = path.cgPath
            overlay.fillRule = .evenOdd
            overlay.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor

            view.layer.addSublayer(overlay)
            overlayLayer = overlay
        }

        private func addCaptureButton() {
            let buttonSize: CGFloat = 70
            let captureButton = UIButton(type: .custom)
            captureButton.frame = CGRect(x: (view.bounds.width - buttonSize) / 2,
                                         y: view.bounds.height - buttonSize - 100,
                                         width: buttonSize,
                                         height: buttonSize)
            captureButton.layer.cornerRadius = buttonSize / 2
            captureButton.backgroundColor = UIColor.white
            captureButton.layer.borderColor = UIColor.black.cgColor
            captureButton.layer.borderWidth = 2
            captureButton.addTarget(self, action: #selector(capturePressed), for: .touchUpInside)

            view.addSubview(captureButton)
        }

        @objc private func capturePressed() {
            takePhoto()
        }

        private func takePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(_ output: AVCapturePhotoOutput,
                         didFinishProcessingPhoto photo: AVCapturePhoto,
                         error: Error?) {
            if let error = error {
                onError?(error)
                return
            }
            if let data = photo.fileDataRepresentation(),
               let image = UIImage(data: data) {
                onComplete?([image])
            } else {
                onError?(NSError(domain: "PhotoError", code: -2, userInfo: nil))
            }
        }
    }
}

