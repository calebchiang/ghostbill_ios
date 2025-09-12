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

        private var captureButton: UIButton?
        private var cancelButton: UIButton?

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

            let preview = AVCaptureVideoPreviewLayer(session: captureSession)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview

            // Overlay first (below buttons), then buttons on top
            addOverlay()
            addCaptureButton()
            addCancelButton()

            captureSession.startRunning()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
            layoutButtons()
            updateOverlayPath()
        }

        // MARK: - Overlay (visual guide only)

        /// Central window to encourage close framing (tall/skinny receipt).
        private func focusRect(in bounds: CGRect) -> CGRect {
            let xInset = bounds.width * 0.12
            let yInset = bounds.height * 0.08
            return bounds.insetBy(dx: xInset, dy: yInset)
        }

        private func addOverlay() {
            let overlay = CAShapeLayer()
            overlay.fillRule = .evenOdd
            overlay.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
            overlay.zPosition = 200   // below buttons (we'll put buttons at > 200)
            view.layer.addSublayer(overlay)
            overlayLayer = overlay
            updateOverlayPath()
        }

        private func updateOverlayPath() {
            guard let overlay = overlayLayer else { return }
            let bounds = view.bounds
            let path = UIBezierPath(rect: bounds)
            let window = focusRect(in: bounds)
            let cutout = UIBezierPath(roundedRect: window, cornerRadius: 14)
            path.append(cutout.reversing())
            overlay.path = path.cgPath
            overlay.frame = bounds
        }

        // MARK: - Buttons

        private func addCaptureButton() {
            let buttonSize: CGFloat = 70
            let btn = UIButton(type: .custom)
            btn.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
            btn.layer.cornerRadius = buttonSize / 2
            btn.backgroundColor = UIColor.white
            btn.layer.borderColor = UIColor.black.cgColor
            btn.layer.borderWidth = 2
            btn.addTarget(self, action: #selector(capturePressed), for: .touchUpInside)

            // Ensure above overlay
            btn.layer.zPosition = 1000

            view.addSubview(btn)
            captureButton = btn
        }

        private func addCancelButton() {
            let btn = UIButton(type: .system)
            btn.setTitle("Cancel", for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)

            // Keep above overlay as well
            btn.layer.zPosition = 1000

            btn.addTarget(self, action: #selector(cancelPressed), for: .touchUpInside)
            view.addSubview(btn)
            cancelButton = btn
        }

        private func layoutButtons() {
            let bounds = view.bounds
            let safe = view.safeAreaInsets

            if let capture = captureButton {
                let buttonSize = capture.bounds.width
                let y = bounds.height - safe.bottom - 100
                capture.frame = CGRect(
                    x: (bounds.width - buttonSize) / 2,
                    y: y,
                    width: buttonSize,
                    height: buttonSize
                )
            }

            if let cancel = cancelButton {
                cancel.sizeToFit()
                let topY = safe.top + 12
                cancel.frame = CGRect(
                    x: 20,
                    y: topY,
                    width: max(80, cancel.bounds.width + 10),
                    height: 40
                )
            }
        }

        // MARK: - Actions

        @objc private func capturePressed() {
            takePhoto()
        }

        @objc private func cancelPressed() {
            captureSession.stopRunning()
            dismiss(animated: true) {
                self.onCancel?()
            }
        }

        private func takePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        // MARK: - Photo capture (no cropping)

        func photoOutput(_ output: AVCapturePhotoOutput,
                         didFinishProcessingPhoto photo: AVCapturePhoto,
                         error: Error?) {
            if let error = error {
                onError?(error)
                return
            }
            guard let data = photo.fileDataRepresentation(),
                  let rawImage = UIImage(data: data) else {
                onError?(NSError(domain: "PhotoError", code: -2, userInfo: nil))
                return
            }

            let image = rawImage.fixedOrientation()
            // No cropping — return the full image
            onComplete?([image])
        }
    }
}

// MARK: - UIImage orientation helper
private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}

