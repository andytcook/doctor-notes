

import sounddevice as sd
import numpy as np
import scipy.io.wavfile as wav
import threading
import math


def record_audio(filename="output.wav", fs=44100):
    print("Recording... Press Enter to stop.")
    
    recording = True
    audio_chunks = []
    
    def record_thread():
        nonlocal audio_chunks
        with sd.InputStream(samplerate=fs, channels=1, dtype='int16') as stream:
            while recording:
                data, _ = stream.read(1024)
                audio_chunks.append(data)
    
    # Start recording thread
    thread = threading.Thread(target=record_thread)
    thread.start()
    
    # Wait for user input
    input("Press Enter to stop recording: ")
    nonlocal_vars = {'recording': recording}
    recording = False
    thread.join()
    
    # Combine all chunks and save
    if audio_chunks:
        audio = np.concatenate(audio_chunks)
        wav.write(filename, fs, audio)
        audio_length_seconds = len(audio) / fs
        print(f"Recording saved to {filename}")
        print(f"Audio length: {audio_length_seconds:.2f} seconds")
        return filename, audio_length_seconds
    else:
        print("No audio recorded.")
        return None, 0


_, length = record_audio("audio_conversation.wav")

import openai

openai_api_key = "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"

def audio_to_text(audio_path):
    client = openai.OpenAI(api_key=openai_api_key)
    with open(audio_path, "rb") as audio_file:
        transcript_response = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file
        )
    return transcript_response.text


transcript = audio_to_text("audio_conversation.wav")
print(transcript)

def extract_patient_info(transcript):
    client = openai.OpenAI(api_key=openai_api_key)
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are given a conversation between a doctor and a patient. Your job is to extract information about the patient and return it in json format. The json should have the following keys: name, age, gender, height, weight, main complaint, recent medical history, past medical history, drugs taken, risk factors, allergies, family history, social history, physical examination results, and consultation time. For consultation time use " + str(math.ceil(length/60)) + " minutes as the value. Only return the json, no other text. Include all the json keys in the order they are listed. Do not include any other keys or nested keys. If you cannot find the information for certain fields, put \"unknown\" for the value. Write the values in 3rd person in a consise and medically accurate way and include units like cm, kg, years, etc."},
            {"role": "user", "content": transcript}
        ]
    )
    return response.choices[0].message.content

info = extract_patient_info(transcript)
print(info)



