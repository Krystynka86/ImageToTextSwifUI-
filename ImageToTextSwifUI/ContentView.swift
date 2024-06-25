import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @State private var recognizedText = ""
    @State private var showCameraView = false

    var body: some View {
        VStack {
            Text("Live OCR using Vision")
                .font(.title)
            
            Button("Start Camera") {
                showCameraView.toggle()
            }
            
            if showCameraView {
                CameraView(recognizedText: $recognizedText)
                    .edgesIgnoringSafeArea(.all)
            }
            
            TextEditor(text: $recognizedText)
                .padding()
                .frame(height: 200)
        }
        .padding()
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController(recognizedText: $recognizedText)
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
    }
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Binding var recognizedText: String
    
    init(recognizedText: Binding<String>) {
        _recognizedText = recognizedText
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                self?.recognizedText = recognizedStrings.joined(separator: "\n")
            }
        }
        
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
        } catch {
            print(error)
        }
    }
}


#Preview {
  ContentView()
}
