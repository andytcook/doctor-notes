//
//  ContentView.swift
//  doctor-listener-notes
//
//  Created by Andras Cook on 9/2/25.
//

import SwiftUI
import AVFoundation
import AVFAudio

private let openaikey = "secret"

// MARK: - Default Prompt Strings

private let defaultTranscriptionPrompt = "This is a medical consultation recording between a doctor and a patient."
private let defaultDiagnosePrompt = "You are given a conversation between a doctor and a patient and your job is to return a comma separated list of each potential diagnosis that the doctor finds. Do not return diagnoses that the doctor does not mention. If no diagnoses are found, return \"none\"."
private let defaultDiagnosisSuggestionsPrompt = "You are given a conversation between a doctor and a patient and your job is to return a comma separated list of any likely diagnoses based on the anamnesis but which the doctor did not suggest in the conversation. If no diagnoses are likely in addition to what the doctor recommended, return \"none\"."
private let defaultAnamnesePrompt = "You are given a conversation between a doctor and a patient and your job is to generate an anamnesis summary."
private let defaultFurtherPrompt = "You are given a conversation between a doctor and a patient and your job is to suggest additional questions the doctor should ask the patient and recommend further investigations or tests that might be helpful."

// MARK: - RecordingsFileManager

class RecordingsFileManager {
    static let shared = RecordingsFileManager()
    private let fileName = "recordingslist"
    
    private init() {}
    
    private func getFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    func ensureFileExists() {
        let fileURL = getFileURL()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            // Create empty file
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    func addRecordingTimestamp(_ timestamp: String) {
        let fileURL = getFileURL()
        do {
            let data = "\(timestamp)\n".data(using: .utf8)!
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try data.write(to: fileURL)
            }
        } catch {
            print("Failed to add recording timestamp: \(error)")
        }
    }
    
    func loadRecordings() -> [String] {
        let fileURL = getFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            return content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
        } catch {
            print("Failed to load recordings: \(error)")
            return []
        }
    }
}

// MARK: - PromptFileManager

class PromptFileManager {
    static let shared = PromptFileManager()
    private init() {}
    
    private let transcriptionFileName = "transcriptionprompt.txt"
    private let diagnoseFileName = "diagnoseprompt.txt"
    private let diagnosisSuggestionsFileName = "diagnosissuggestions.txt"
    private let anamneseFileName = "anamnese.txt"
    private let furtherPromptFileName = "furtherprompt.txt"
    
    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func url(for fileName: String) -> URL {
        documentsDirectory().appendingPathComponent(fileName)
    }
    
    func ensurePromptFilesExist() {
        let transcriptionURL = url(for: transcriptionFileName)
        let diagnoseURL = url(for: diagnoseFileName)
        let diagnosisSuggestionsURL = url(for: diagnosisSuggestionsFileName)
        let anamneseURL = url(for: anamneseFileName)
        let furtherPromptURL = url(for: furtherPromptFileName)
        
        if !FileManager.default.fileExists(atPath: transcriptionURL.path) {
            try? defaultTranscriptionPrompt.write(to: transcriptionURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: diagnoseURL.path) {
            try? defaultDiagnosePrompt.write(to: diagnoseURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: diagnosisSuggestionsURL.path) {
            try? defaultDiagnosisSuggestionsPrompt.write(to: diagnosisSuggestionsURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: anamneseURL.path) {
            try? defaultAnamnesePrompt.write(to: anamneseURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: furtherPromptURL.path) {
            try? defaultFurtherPrompt.write(to: furtherPromptURL, atomically: true, encoding: .utf8)
        }
    }
    
    func readTranscriptionPrompt() -> String {
        read(fileName: transcriptionFileName)
    }
    
    func readDiagnosePrompt() -> String {
        read(fileName: diagnoseFileName)
    }
    
    func readDiagnosisSuggestionsPrompt() -> String {
        read(fileName: diagnosisSuggestionsFileName)
    }
    
    func readAnamnesePrompt() -> String {
        read(fileName: anamneseFileName)
    }
    
    func readFurtherPrompt() -> String {
        read(fileName: furtherPromptFileName)
    }
    
    func writeTranscriptionPrompt(_ text: String) {
        write(text: text, fileName: transcriptionFileName)
    }
    
    func writeDiagnosePrompt(_ text: String) {
        write(text: text, fileName: diagnoseFileName)
    }
    
    func writeDiagnosisSuggestionsPrompt(_ text: String) {
        write(text: text, fileName: diagnosisSuggestionsFileName)
    }
    
    func writeAnamnesePrompt(_ text: String) {
        write(text: text, fileName: anamneseFileName)
    }
    
    func writeFurtherPrompt(_ text: String) {
        write(text: text, fileName: furtherPromptFileName)
    }
    
    private func read(fileName: String) -> String {
        let fileURL = url(for: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return "" }
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }
    
    private func write(text: String, fileName: String) {
        let fileURL = url(for: fileName)
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write to \(fileName): \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var recordings: [RecordingEntry] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top recording button
                Button(action: {
                    switch audioRecorder.state {
                    case .idle:
                        audioRecorder.startRecording()
                    case .recording:
                        audioRecorder.stopRecording()
                    case .finished:
                        break
                    }
                }) {
                    Text(audioRecorder.state == .recording ? "Finish Recording" : "Start Recording")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Scrollable list of recordings
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recordings) { recording in
                            NavigationLink(destination: RecordingDetailView(recording: recording)) {
                                HStack {
                                    Text(recording.timestamp)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .safeAreaInset(edge: .bottom) {
                NavigationLink(destination: EditPromptsView()) {
                    Text("Edit Prompts")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            loadExistingRecordings()
        }
        .onChange(of: audioRecorder.state) { _, newState in
            if newState == .finished {
                addRecordingToList()
                // Reset to idle after a short delay to allow for new recordings
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioRecorder.resetToIdle()
                }
            }
        }
    }
}

struct RecordingEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let url: URL
}

struct RecordingDetailView: View {
    let recording: RecordingEntry
    @State private var audioPlayer: AVAudioPlayer?
    @Environment(\.presentationMode) var presentationMode
    @State private var transcriptText: String = "Transcript"
    @State private var isTranscribing: Bool = false
    @State private var diagnosesText: String = "Doctor's diagnoses will appear here"
    @State private var isGeneratingDiagnoses: Bool = false
    @State private var diagnosisSuggestionsText: String = "AI suggested diagnoses will appear here"
    @State private var isGeneratingDiagnosisSuggestions: Bool = false
    @State private var anamneseText: String = "Anamnesis will appear here"
    @State private var isGeneratingAnamnese: Bool = false
    @State private var furtherPromptText: String = "Further suggestions will appear here"
    @State private var isGeneratingFurtherPrompt: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Play button at the top
                Button(action: {
                    playRecording()
                }) {
                    Text("Play")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // Generate Transcript button
                Button(action: {
                    Task { await generateTranscript() }
                }) {
                    Text("Generate Transcript")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 16)
                .disabled(isTranscribing)
                
                // Transcript text box
                TextEditor(text: .constant(transcriptText))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .disabled(true)

                // List Diagnoses button
                Button(action: {
                    Task { await generateDiagnoses() }
                }) {
                    Text("List Doctor's Diagnoses")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 16)
                .disabled(isGeneratingDiagnoses)

                TextEditor(text: .constant(diagnosesText))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .disabled(true)
                
                // Diagnosis Suggestions button
                Button(action: {
                    Task { await generateDiagnosisSuggestions() }
                }) {
                    Text("List AI suggested diagnoses")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 16)
                .disabled(isGeneratingDiagnosisSuggestions)

                TextEditor(text: .constant(diagnosisSuggestionsText))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .disabled(true)
                
                // Anamnese button
                Button(action: {
                    Task { await generateAnamnese() }
                }) {
                    Text("Anamnesis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 16)
                .disabled(isGeneratingAnamnese)

                TextEditor(text: .constant(anamneseText))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .disabled(true)
                
                // Further Prompt button
                Button(action: {
                    Task { await generateFurtherPrompt() }
                }) {
                    Text("Further Questions")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 16)
                .disabled(isGeneratingFurtherPrompt)

                TextEditor(text: .constant(furtherPromptText))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .disabled(true)
                
                // Bottom padding for scroll
                Spacer(minLength: 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadExistingTranscriptIfAvailable()
        }
    }
    
    private func playRecording() {
        guard FileManager.default.fileExists(atPath: recording.url.path) else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            // Silently fail for now
        }
    }

    private func generateBoundary() -> String {
        "Boundary-\(UUID().uuidString)"
    }

    private func makeMultipartBody(fileURL: URL, boundary: String, model: String, prompt: String) throws -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"

        // model field
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // prompt field
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(prompt)\r\n".data(using: .utf8)!)

        // file field
        let filename = fileURL.lastPathComponent
        let mimeType = "audio/m4a"
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        let fileData = try Data(contentsOf: fileURL)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // end boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
    }

    private func updateTranscript(_ text: String) {
        transcriptText = text.isEmpty ? "(No transcription text returned)" : text
    }

    private func setTranscribing(_ value: Bool) {
        isTranscribing = value
    }

    private func setError(_ message: String) {
        transcriptText = message
    }

    private func resetIfNeeded() {}

    private func validateFileExists() -> Bool {
        FileManager.default.fileExists(atPath: recording.url.path)
    }

    private func buildRequest(apiKey: String, boundary: String, body: Data) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private func decodeTranscription(data: Data) -> String? {
        try? JSONDecoder().decode(TranscriptionResponse.self, from: data).text
    }

    private func handleHTTPResponse(_ response: URLResponse, data: Data) -> String? {
        guard let http = response as? HTTPURLResponse else { return nil }
        guard 200...299 ~= http.statusCode else { return String(data: data, encoding: .utf8) }
        return nil
    }

    private func performTranscriptionRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    private func buildMultipartBody() throws -> (Data, String) {
        let boundary = generateBoundary()
        let promptFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("transcriptionprompt.txt")
        let prompt: String = {
            if let content = try? String(contentsOf: promptFileURL, encoding: .utf8), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            } else {
                return defaultTranscriptionPrompt
            }
        }()
        let body = try makeMultipartBody(fileURL: recording.url, boundary: boundary, model: "whisper-1", prompt: prompt)
        return (body, boundary)
    }

    private func onTranscriptionStart() {
        setTranscribing(true)
        updateTranscript("Transcribing…")
    }

    private func onTranscriptionFinish() {
        setTranscribing(false)
    }

    private func onTranscriptionSuccess(_ text: String) {
        updateTranscript(text)
    }

    private func onTranscriptionFailure(_ message: String) {
        setError("Transcription failed: \(message)")
    }

    private func createErrorMessage(_ error: Error) -> String {
        (error as NSError).localizedDescription
    }

    private func prepareRequest() throws -> URLRequest {
        guard validateFileExists() else { throw NSError(domain: "RecordingDetailView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording file not found"]) }
        let apiKey = openaikey
        let (body, boundary) = try buildMultipartBody()
        return buildRequest(apiKey: apiKey, boundary: boundary, body: body)
    }

    private func processResponse(data: Data, response: URLResponse) throws -> String {
        if let errorText = handleHTTPResponse(response, data: data) { throw NSError(domain: "RecordingDetailView", code: 3, userInfo: [NSLocalizedDescriptionKey: errorText]) }
        guard let text = decodeTranscription(data: data) else { throw NSError(domain: "RecordingDetailView", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to decode transcription response"]) }
        return text
    }

    private func generateTranscript() async {
        onTranscriptionStart()
        defer { onTranscriptionFinish() }
        do {
            let request = try prepareRequest()
            let (data, response) = try await performTranscriptionRequest(request: request)
            let text = try processResponse(data: data, response: response)
            onTranscriptionSuccess(text)
            // Save transcript to file
            saveTranscriptToFile(text)
        } catch {
            onTranscriptionFailure(createErrorMessage(error))
        }
    }
    
    // MARK: - File Management Functions
    
    private func getTranscriptFileName() -> String {
        // Extract timestamp from recording URL filename
        let filename = recording.url.lastPathComponent
        let timestamp = filename.replacingOccurrences(of: "recording_", with: "").replacingOccurrences(of: ".m4a", with: "")
        return "\(timestamp)_transcript.txt"
    }
    
    private func getTranscriptFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(getTranscriptFileName())
    }
    
    private func saveTranscriptToFile(_ transcript: String) {
        let fileURL = getTranscriptFileURL()
        do {
            try transcript.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save transcript to file: \(error)")
        }
    }
    
    private func loadExistingTranscript() -> String? {
        let fileURL = getTranscriptFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Failed to load transcript from file: \(error)")
            return nil
        }
    }
    
    private func loadExistingTranscriptIfAvailable() {
        if let existingTranscript = loadExistingTranscript() {
            transcriptText = existingTranscript
        } else {
            transcriptText = "Transcript"
        }
        
        // Also load existing diagnoses if available
        if let existingDiagnoses = loadExistingDiagnoses() {
            diagnosesText = existingDiagnoses
        } else {
            diagnosesText = "Diagnoses will appear here"
        }
        
        // Load existing diagnosis suggestions if available
        if let existingDiagnosisSuggestions = loadExistingDiagnosisSuggestions() {
            diagnosisSuggestionsText = existingDiagnosisSuggestions
        } else {
            diagnosisSuggestionsText = "Diagnosis suggestions will appear here"
        }
        
        // Load existing anamnese if available
        if let existingAnamnese = loadExistingAnamnese() {
            anamneseText = existingAnamnese
        } else {
            anamneseText = "Anamnese will appear here"
        }
        
        // Load existing further prompt results if available
        if let existingFurtherPrompt = loadExistingFurtherPrompt() {
            furtherPromptText = existingFurtherPrompt
        } else {
            furtherPromptText = "Further suggestions will appear here"
        }
    }
    
    // MARK: - Diagnoses File Management Functions
    
    private func getDiagnosesFileName() -> String {
        // Extract timestamp from recording URL filename
        let filename = recording.url.lastPathComponent
        let timestamp = filename.replacingOccurrences(of: "recording_", with: "").replacingOccurrences(of: ".m4a", with: "")
        return "\(timestamp)_diagnoses.txt"
    }
    
    private func getDiagnosesFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(getDiagnosesFileName())
    }
    
    private func saveDiagnosesToFile(_ diagnoses: String) {
        let fileURL = getDiagnosesFileURL()
        do {
            try diagnoses.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save diagnoses to file: \(error)")
        }
    }
    
    private func loadExistingDiagnoses() -> String? {
        let fileURL = getDiagnosesFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Failed to load diagnoses from file: \(error)")
            return nil
        }
    }
    
    // MARK: - Diagnosis Suggestions File Management Functions
    
    private func getDiagnosisSuggestionsFileName() -> String {
        // Extract timestamp from recording URL filename
        let filename = recording.url.lastPathComponent
        let timestamp = filename.replacingOccurrences(of: "recording_", with: "").replacingOccurrences(of: ".m4a", with: "")
        return "\(timestamp)_diagnosis_suggestions.txt"
    }
    
    private func getDiagnosisSuggestionsFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(getDiagnosisSuggestionsFileName())
    }
    
    private func saveDiagnosisSuggestionsToFile(_ suggestions: String) {
        let fileURL = getDiagnosisSuggestionsFileURL()
        do {
            try suggestions.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save diagnosis suggestions to file: \(error)")
        }
    }
    
    private func loadExistingDiagnosisSuggestions() -> String? {
        let fileURL = getDiagnosisSuggestionsFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Failed to load diagnosis suggestions from file: \(error)")
            return nil
        }
    }
    
    // MARK: - Anamnese File Management Functions
    
    private func getAnamneseFileName() -> String {
        // Extract timestamp from recording URL filename
        let filename = recording.url.lastPathComponent
        let timestamp = filename.replacingOccurrences(of: "recording_", with: "").replacingOccurrences(of: ".m4a", with: "")
        return "\(timestamp)_anamnese.txt"
    }
    
    private func getAnamneseFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(getAnamneseFileName())
    }
    
    private func saveAnamneseToFile(_ anamnese: String) {
        let fileURL = getAnamneseFileURL()
        do {
            try anamnese.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save anamnese to file: \(error)")
        }
    }
    
    private func loadExistingAnamnese() -> String? {
        let fileURL = getAnamneseFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Failed to load anamnese from file: \(error)")
            return nil
        }
    }
    
    // MARK: - Further Prompt File Management Functions
    
    private func getFurtherPromptFileName() -> String {
        // Extract timestamp from recording URL filename
        let filename = recording.url.lastPathComponent
        let timestamp = filename.replacingOccurrences(of: "recording_", with: "").replacingOccurrences(of: ".m4a", with: "")
        return "\(timestamp)_further_prompt.txt"
    }
    
    private func getFurtherPromptFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(getFurtherPromptFileName())
    }
    
    private func saveFurtherPromptToFile(_ furtherPrompt: String) {
        let fileURL = getFurtherPromptFileURL()
        do {
            try furtherPrompt.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save further prompt to file: \(error)")
        }
    }
    
    private func loadExistingFurtherPrompt() -> String? {
        let fileURL = getFurtherPromptFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Failed to load further prompt from file: \(error)")
            return nil
        }
    }
    
    // MARK: - Diagnoses Generation Functions
    
    private struct DiagnosesResponse: Decodable {
        let choices: [Choice]
        
        struct Choice: Decodable {
            let message: Message
            
            struct Message: Decodable {
                let content: String
            }
        }
    }
    
    private func generateDiagnoses() async {
        guard !transcriptText.isEmpty && transcriptText != "Transcript" && transcriptText != "(No transcription text returned)" else {
            diagnosesText = "Please generate a transcript first"
            return
        }
        
        isGeneratingDiagnoses = true
        diagnosesText = "Generating diagnoses..."
        
        defer { isGeneratingDiagnoses = false }
        
        do {
            let diagnoses = try await performDiagnosesRequest()
            diagnosesText = diagnoses.isEmpty ? "No diagnoses generated" : diagnoses
            // Save diagnoses to file
            saveDiagnosesToFile(diagnosesText)
        } catch {
            diagnosesText = "Error generating diagnoses: \(error.localizedDescription)"
        }
    }
    
    private func performDiagnosesRequest() async throws -> String {
        let apiKey = openaikey
        
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let diagnosePromptFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("diagnoseprompt.txt")
        let system_prompt: String = {
            if let content = try? String(contentsOf: diagnosePromptFileURL, encoding: .utf8), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            } else {
                return defaultDiagnosePrompt
            }
        }()
        
        let requestBody: [String: Any] = [
            "model": "o3",
            "messages": [
                [
                    "role": "system",
                    "content": system_prompt
                ],
                [
                    "role": "user",
                    "content": transcriptText
                ]
            ],
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RecordingDetailView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "RecordingDetailView", code: 4, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorMessage)"])
        }
        
        let diagnosesResponse = try JSONDecoder().decode(DiagnosesResponse.self, from: data)
        
        guard let firstChoice = diagnosesResponse.choices.first else {
            throw NSError(domain: "RecordingDetailView", code: 5, userInfo: [NSLocalizedDescriptionKey: "No response from API"])
        }
        
        return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Diagnosis Suggestions Generation Functions
    
    private func generateDiagnosisSuggestions() async {
        guard !transcriptText.isEmpty && transcriptText != "Transcript" && transcriptText != "(No transcription text returned)" else {
            diagnosisSuggestionsText = "Please generate a transcript first"
            return
        }
        
        isGeneratingDiagnosisSuggestions = true
        diagnosisSuggestionsText = "Generating diagnosis suggestions..."
        
        defer { isGeneratingDiagnosisSuggestions = false }
        
        do {
            let suggestions = try await performDiagnosisSuggestionsRequest()
            diagnosisSuggestionsText = suggestions.isEmpty ? "No diagnosis suggestions generated" : suggestions
            // Save diagnosis suggestions to file
            saveDiagnosisSuggestionsToFile(diagnosisSuggestionsText)
        } catch {
            diagnosisSuggestionsText = "Error generating diagnosis suggestions: \(error.localizedDescription)"
        }
    }
    
    private func performDiagnosisSuggestionsRequest() async throws -> String {
        let apiKey = openaikey
        
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let diagnosisSuggestionsPromptFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("diagnosissuggestions.txt")
        let system_prompt: String = {
            if let content = try? String(contentsOf: diagnosisSuggestionsPromptFileURL, encoding: .utf8), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            } else {
                return defaultDiagnosisSuggestionsPrompt
            }
        }()
        
        let requestBody: [String: Any] = [
            "model": "o3",
            "messages": [
                [
                    "role": "system",
                    "content": system_prompt
                ],
                [
                    "role": "user",
                    "content": transcriptText
                ]
            ],
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RecordingDetailView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "RecordingDetailView", code: 4, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorMessage)"])
        }
        
        let diagnosisSuggestionsResponse = try JSONDecoder().decode(DiagnosesResponse.self, from: data)
        
        guard let firstChoice = diagnosisSuggestionsResponse.choices.first else {
            throw NSError(domain: "RecordingDetailView", code: 5, userInfo: [NSLocalizedDescriptionKey: "No response from API"])
        }
        
        return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Anamnese Generation Functions
    
    private func generateAnamnese() async {
        guard !transcriptText.isEmpty && transcriptText != "Transcript" && transcriptText != "(No transcription text returned)" else {
            anamneseText = "Please generate a transcript first"
            return
        }
        
        isGeneratingAnamnese = true
        anamneseText = "Generating anamnese..."
        
        defer { isGeneratingAnamnese = false }
        
        do {
            let anamnese = try await performAnamneseRequest()
            anamneseText = anamnese.isEmpty ? "No anamnese generated" : anamnese
            // Save anamnese to file
            saveAnamneseToFile(anamneseText)
        } catch {
            anamneseText = "Error generating anamnese: \(error.localizedDescription)"
        }
    }
    
    private func performAnamneseRequest() async throws -> String {
        let apiKey = openaikey
        
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let anamnesePromptFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("anamnese.txt")
        let system_prompt: String = {
            if let content = try? String(contentsOf: anamnesePromptFileURL, encoding: .utf8), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            } else {
                return defaultAnamnesePrompt
            }
        }()
        
        let requestBody: [String: Any] = [
            "model": "o3",
            "messages": [
                [
                    "role": "system",
                    "content": system_prompt
                ],
                [
                    "role": "user",
                    "content": transcriptText
                ]
            ],
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RecordingDetailView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "RecordingDetailView", code: 4, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorMessage)"])
        }
        
        let anamneseResponse = try JSONDecoder().decode(DiagnosesResponse.self, from: data)
        
        guard let firstChoice = anamneseResponse.choices.first else {
            throw NSError(domain: "RecordingDetailView", code: 5, userInfo: [NSLocalizedDescriptionKey: "No response from API"])
        }
        
        return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Further Prompt Generation Functions
    
    private func generateFurtherPrompt() async {
        guard !transcriptText.isEmpty && transcriptText != "Transcript" && transcriptText != "(No transcription text returned)" else {
            furtherPromptText = "Please generate a transcript first"
            return
        }
        
        isGeneratingFurtherPrompt = true
        furtherPromptText = "Generating further suggestions..."
        
        defer { isGeneratingFurtherPrompt = false }
        
        do {
            let furtherPrompt = try await performFurtherPromptRequest()
            furtherPromptText = furtherPrompt.isEmpty ? "No further suggestions generated" : furtherPrompt
            // Save further prompt to file
            saveFurtherPromptToFile(furtherPromptText)
        } catch {
            furtherPromptText = "Error generating further suggestions: \(error.localizedDescription)"
        }
    }
    
    private func performFurtherPromptRequest() async throws -> String {
        let apiKey = openaikey
        
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let furtherPromptFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("furtherprompt.txt")
        let system_prompt: String = {
            if let content = try? String(contentsOf: furtherPromptFileURL, encoding: .utf8), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            } else {
                return defaultFurtherPrompt
            }
        }()
        
        let requestBody: [String: Any] = [
            "model": "o3",
            "messages": [
                [
                    "role": "system",
                    "content": system_prompt
                ],
                [
                    "role": "user",
                    "content": transcriptText
                ]
            ],
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RecordingDetailView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "RecordingDetailView", code: 4, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorMessage)"])
        }
        
        let furtherPromptResponse = try JSONDecoder().decode(DiagnosesResponse.self, from: data)
        
        guard let firstChoice = furtherPromptResponse.choices.first else {
            throw NSError(domain: "RecordingDetailView", code: 5, userInfo: [NSLocalizedDescriptionKey: "No response from API"])
        }
        
        return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct EditPromptsView: View {
    @State private var promptOne: String = ""
    @State private var promptTwo: String = ""
    @State private var promptThree: String = ""
    @State private var promptFour: String = ""
    @State private var promptFive: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // First prompt section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $promptOne)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                
                // Second prompt section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Doctor's diagnosis Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $promptTwo)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                
                // Third prompt section
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI suggested diagnoses Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $promptThree)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                
                // Fourth prompt section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Anamnese Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $promptFour)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                
                // Fifth prompt section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Missing information Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $promptFive)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load existing prompts when screen opens
            PromptFileManager.shared.ensurePromptFilesExist()
            promptOne = PromptFileManager.shared.readTranscriptionPrompt()
            promptTwo = PromptFileManager.shared.readDiagnosePrompt()
            promptThree = PromptFileManager.shared.readDiagnosisSuggestionsPrompt()
            promptFour = PromptFileManager.shared.readAnamnesePrompt()
            promptFive = PromptFileManager.shared.readFurtherPrompt()
        }
        .onChange(of: promptOne) { _, newValue in
            PromptFileManager.shared.writeTranscriptionPrompt(newValue)
        }
        .onChange(of: promptTwo) { _, newValue in
            PromptFileManager.shared.writeDiagnosePrompt(newValue)
        }
        .onChange(of: promptThree) { _, newValue in
            PromptFileManager.shared.writeDiagnosisSuggestionsPrompt(newValue)
        }
        .onChange(of: promptFour) { _, newValue in
            PromptFileManager.shared.writeAnamnesePrompt(newValue)
        }
        .onChange(of: promptFive) { _, newValue in
            PromptFileManager.shared.writeFurtherPrompt(newValue)
        }
    }
}

final class AudioRecorder: ObservableObject {
    enum RecordingState {
        case idle
        case recording
        case finished
    }

    @Published var state: RecordingState = .idle
    @Published var recordingStartTime: Date?
    @Published var currentRecordingURL: URL?

    private var recorder: AVAudioRecorder?

    func startRecording() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard granted else { return }
                    self?.configureAndStart()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard granted else { return }
                    self?.configureAndStart()
                }
            }
        }
    }

    private func configureAndStart() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            recordingStartTime = Date()
            let url = Self.generateUniqueRecordingURL()
            currentRecordingURL = url
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            recorder?.record()
            state = .recording
        } catch {
            // If recording setup fails, remain idle
            state = .idle
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch { }
        state = .finished
    }
    
    func resetToIdle() {
        state = .idle
        recordingStartTime = nil
        currentRecordingURL = nil
    }

    static func generateUniqueRecordingURL() -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "recording_\(timestamp).m4a"
        return directory.appendingPathComponent(filename)
    }
}

private extension ContentView {
    func loadExistingRecordings() {
        // Ensure the recordingslist file exists
        RecordingsFileManager.shared.ensureFileExists()
        
        // Load existing recordings from file
        let timestamps = RecordingsFileManager.shared.loadRecordings()
        
        // Convert timestamps to RecordingEntry objects
        recordings = timestamps.compactMap { timestamp in
            // Try to find the corresponding audio file
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            // Look for audio files that might match this timestamp
            do {
                let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                let audioFiles = files.filter { $0.pathExtension == "m4a" }
                
                // Try to find a matching file by checking if the timestamp appears in the filename
                for audioFile in audioFiles {
                    let filename = audioFile.lastPathComponent
                    if filename.contains("recording_") {
                        // Extract timestamp from filename and compare
                        let fileTimestamp = filename.replacingOccurrences(of: "recording_", with: "").replacingOccurrences(of: ".m4a", with: "")
                        
                        // Convert timestamp string back to date for comparison
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        formatter.timeStyle = .medium
                        
                        if let fileDate = formatter.date(from: timestamp) {
                            let fileTimestampInt = Int(fileDate.timeIntervalSince1970)
                            if fileTimestamp == String(fileTimestampInt) {
                                return RecordingEntry(timestamp: timestamp, url: audioFile)
                            }
                        }
                    }
                }
            } catch {
                print("Error loading existing recordings: \(error)")
            }
            
            return nil
        }
    }
    
    func addRecordingToList() {
        guard let startTime = audioRecorder.recordingStartTime,
              let recordingURL = audioRecorder.currentRecordingURL else { return }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        let timestampString = formatter.string(from: startTime)
        
        // Save timestamp to file
        RecordingsFileManager.shared.addRecordingTimestamp(timestampString)
        
        let recording = RecordingEntry(
            timestamp: timestampString,
            url: recordingURL
        )
        recordings.append(recording)
    }
}

#Preview {
    ContentView()
}
