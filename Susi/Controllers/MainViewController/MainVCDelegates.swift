//
//  MainVCDelegates.swift
//  Susi
//
//  Created by Chashmeet Singh on 2017-06-04.
//  Copyright © 2017 FOSSAsia. All rights reserved.
//

import UIKit
import Popover
import AVFoundation
import CoreLocation
import RSKGrowingTextView
import RealmSwift
import Speech
import NVActivityIndicatorView

extension MainViewController: CLLocationManagerDelegate {

    // Configures Location Manager
    func configureLocationManager() {
        locationManager.delegate = self
        if CLLocationManager.authorizationStatus() == .notDetermined || CLLocationManager.authorizationStatus() == .denied {
            self.locationManager.requestWhenInUseAuthorization()
        }

        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

}

extension MainViewController: UIImagePickerControllerDelegate {

    // Show image picker to set/reset wallpaper
    func showImagePicker() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.savedPhotosAlbum) {
            imagePicker.allowsEditing = false
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.savedPhotosAlbum
            self.present(imagePicker, animated: true, completion: nil)
        } else {
            // Show error dialog if no photo is available in photo album
            let errorDialog = UIAlertController(title: ControllerConstants.errorDialogTitle, message: ControllerConstants.errorDialogMessage, preferredStyle: UIAlertControllerStyle.alert)
            errorDialog.addAction(UIAlertAction(title: ControllerConstants.dialogCancelAction, style: .cancel, handler: { (_: UIAlertAction!) in
                errorDialog.dismiss(animated: true, completion: nil)
            }))
            self.present(errorDialog, animated: true, completion: nil)
        }

    }

    // Set chat background image
    func setBackgroundImage(image: UIImage!) {
        let bgView = UIImageView()
        bgView.contentMode = .scaleAspectFill
        bgView.image = image
        self.collectionView?.backgroundView = bgView
    }

    // Clear chat background image
    func clearBackgroundImage() {
        self.collectionView?.backgroundView = nil
    }

    // Save image selected by user to user defaults
    func saveWallpaperInUserDefaults(image: UIImage!) {
        let imageData = UIImageJPEGRepresentation(image!, 1.0)
        let defaults = UserDefaults.standard
        defaults.set(imageData, forKey: ControllerConstants.UserDefaultsKeys.wallpaper)
    }

    // Check if user defaults have an image data saved else return nil/Any
    func getWallpaperFromUserDefaults() -> Any? {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: ControllerConstants.UserDefaultsKeys.wallpaper)
    }

    // Remove wallpaper from user defaults
    func removeWallpaperFromUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: ControllerConstants.UserDefaultsKeys.wallpaper)
        clearBackgroundImage()
    }

    // Callback when image is selected from gallery
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        let chosenImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        if let image = chosenImage {
            setBackgroundImage(image: image)
            saveWallpaperInUserDefaults(image: image)
        }
    }

    // Callback if cancel selected from picker
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    // Show wallpaper options to set wallpaper or clear wallpaper
    func showWallpaperOptions() {
        let imageDialog = UIAlertController(title: ControllerConstants.wallpaperOptionsTitle, message: nil, preferredStyle: UIAlertControllerStyle.alert)

        imageDialog.addAction(UIAlertAction(title: ControllerConstants.wallpaperOptionsPickAction, style: .default, handler: { (_: UIAlertAction!) in
            imageDialog.dismiss(animated: true, completion: nil)
            self.showImagePicker()
        }))

        imageDialog.addAction(UIAlertAction(title: ControllerConstants.wallpaperOptionsNoWallpaperAction, style: .default, handler: { (_: UIAlertAction!) in
            imageDialog.dismiss(animated: true, completion: nil)
            self.removeWallpaperFromUserDefaults()
        }))

        imageDialog.addAction(UIAlertAction(title: ControllerConstants.dialogCancelAction, style: .cancel, handler: { (_: UIAlertAction!) in
            imageDialog.dismiss(animated: true, completion: nil)
        }))

        self.present(imageDialog, animated: true, completion: nil)
    }

}

extension MainViewController: UITableViewDelegate {

    // Enum for menu options in main chat screen
    enum MenuOptions: Int {
        case setttings = 0
        case wallpaper = 1
        case share = 2
        case logout = 3
    }

    // Handles item click
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.popover.dismiss()

        let index = indexPath.row
        switch index {
        case MenuOptions.setttings.rawValue:
            let settingsController = SettingsViewController(collectionViewLayout: UICollectionViewFlowLayout())
            self.navigationController?.pushViewController(settingsController, animated: true)
            break
        case MenuOptions.wallpaper.rawValue:
            showWallpaperOptions()
            break
        case MenuOptions.logout.rawValue:
            logoutUser()
            break
        default:
            break
        }
    }

    func logoutUser() {

        let realm = try! Realm()
        try! realm.write {
            realm.deleteAll()
        }

        Client.sharedInstance.logoutUser { (success, error) in
            DispatchQueue.main.async {
                if success {
                    self.dismiss(animated: true, completion: nil)
                } else {
                    debugPrint(error)
                }
            }
        }
        self.messages.removeAll()
    }

}

extension MainViewController: UITableViewDataSource {

    // Number of options in popover
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ControllerConstants.Settings.settingsList.count
    }

    // Configure setting cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

        let item = ControllerConstants.Settings.settingsList[indexPath.row]
        cell.textLabel?.text = item
        cell.imageView?.image = UIImage(named: item.lowercased())
        return cell
    }

}

extension MainViewController: AVAudioPlayerDelegate {

    func initSnowboy() {
        wrapper = SnowboyWrapper(resources: RESOURCE, modelStr: MODEL)
        wrapper.setSensitivity("0.5")
        wrapper.setAudioGain(1.0)
        //  print("Sample rate: \(wrapper?.sampleRate()); channels: \(wrapper?.numChannels()); bits: \(wrapper?.bitsPerSample())")
    }

    func startHotwordRecognition() {
        timer = Timer.scheduledTimer(timeInterval: 4, target: self, selector: #selector(startRecording), userInfo: nil, repeats: true)
        timer.fire()
    }

    func runSnowboy() {

        let file = try! AVAudioFile(forReading: soundFileURL)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))
        try! file.read(into: buffer)
        let array = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count:Int(buffer.frameLength)))

        // print("Frame capacity: \(AVAudioFrameCount(file.length))")
        // print("Buffer frame length: \(buffer.frameLength)")

        let result = wrapper.runDetection(array, length: Int32(buffer.frameLength))
        // print("Result: \(result)")

        if result == 1 {
            stopRecording()
            timer.invalidate()
            startSTT()
        }
    }

    func playAudio() {
        do {
            try audioPlayer = AVAudioPlayer(contentsOf:(soundFileURL))
            audioPlayer!.delegate = self
            audioPlayer!.prepareToPlay()
            audioPlayer!.play()
        } catch let error {
            print("Audio player error: \(error.localizedDescription)")
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // print("Audio Recorder did finish recording.")
        runSnowboy()
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio Recorder encode error.")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player did finish playing.")
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error.")
    }

}

extension MainViewController: AVAudioRecorderDelegate {

    func startRecording() {
        do {
            let fileMgr = FileManager.default
            let dirPaths = fileMgr.urls(for: .documentDirectory,
                                        in: .userDomainMask)
            soundFileURL = dirPaths[0].appendingPathComponent("temp.wav")
            let recordSettings =
                [AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                 AVEncoderBitRateKey: 128000,
                 AVNumberOfChannelsKey: 1,
                 AVSampleRateKey: 16000.0] as [String : Any]
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioRecorder = AVAudioRecorder(url: soundFileURL,
                                                settings: recordSettings as [String : AnyObject])
            audioRecorder.delegate = self
            audioRecorder.prepareToRecord()
            audioRecorder.record(forDuration: 2.0)

//             print("Started recording...")
        } catch let error {
            print("Audio session error: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        if audioRecorder != nil && audioRecorder.isRecording {
            audioRecorder.stop()
        }
    }

}

extension MainViewController: RSKGrowingTextViewDelegate, UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        if let message = inputTextView.text, message.isEmpty {
            self.sendButton.tag = 0
            self.sendButton.setImage(UIImage(named: ControllerConstants.mic), for: .normal)
        } else {
            self.sendButton.setImage(UIImage(named: ControllerConstants.send), for: .normal)
            self.sendButton.tag = 1
        }
        addTargetSendButton()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" && UserDefaults.standard.bool(forKey: ControllerConstants.UserDefaultsKeys.enterToSend) {
            handleSend()
            return false
        }
        return true
    }

}

extension MainViewController: SFSpeechRecognizerDelegate {

    func configureSpeechRecognizer() {
        speechRecognizer?.delegate = self

        SFSpeechRecognizer.requestAuthorization { (authStatus) in

            var isEnabled = false

            switch authStatus {
            case .authorized:
                print("Autorized speech")
                isEnabled = true

            case .denied:
                print("Denied speech")
                isEnabled = false

            case .restricted:
                print("speech restricted")
                isEnabled = false

            case .notDetermined:
                print("not determined")
                isEnabled = false
            }

            OperationQueue.main.addOperation {
                self.addTargetSendButton()
            }

        }

    }

    func startSTT() {

        configureSpeechRecognizer()

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        if audioEngine.isRunning {
            stopSTT()
            self.recognitionRequest = nil
            self.recognitionTask = nil
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }

        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in

            var isFinal = false

            if result != nil {

                self.inputTextView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }

            if error != nil || isFinal {
                self.handleSend()
            }

        })

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }

        print("Say something, I'm listening!")

        // Listening indicator swift
        self.indicatorView.frame = self.sendButton.frame

        self.indicatorView.isUserInteractionEnabled = true
        let gesture: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(startSTT))
        gesture.numberOfTapsRequired = 1
        self.indicatorView.addGestureRecognizer(gesture)

        self.sendButton.setImage(nil, for: .normal)
        indicatorView.startAnimating()
        self.sendButton.addSubview(indicatorView)
        self.sendButton.addConstraintsWithFormat(format: "V:|[v0(24)]|", views: indicatorView)
        self.sendButton.addConstraintsWithFormat(format: "H:|[v0(24)]|", views: indicatorView)

        self.inputTextView.isUserInteractionEnabled = false
    }

    func stopSTT() {
        print("audioEngine stopped")
        audioEngine.inputNode?.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioRecorder?.stop()
        indicatorView.removeFromSuperview()
        self.inputTextView.isUserInteractionEnabled = true

        textViewDidChange(inputTextView)

        if UserDefaults.standard.bool(forKey: ControllerConstants.UserDefaultsKeys.hotwordEnabled) {
            startHotwordRecognition()
        }
    }

}
