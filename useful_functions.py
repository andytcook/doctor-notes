import sounddevice as sd
import numpy as np
import scipy.io.wavfile as wav
import threading
import openai
import os

openai_api_key = os.getenv('OPENAI_API_KEY')

def record_audio_webm(filename="output.webm", fs=44100):
    """
    Records audio from the microphone until Enter is pressed,
    then saves it as a compressed WebM file.
    """

    import tempfile
    import subprocess

    print("Recording... Press Enter to stop.")

    recording = {'active': True}
    audio_chunks = []

    def record_thread():
        with sd.InputStream(samplerate=fs, channels=1, dtype='int16') as stream:
            while recording['active']:
                data, _ = stream.read(1024)
                audio_chunks.append(data)

    thread = threading.Thread(target=record_thread)
    thread.start()

    input("Press Enter to stop recording: ")
    recording['active'] = False
    thread.join()

    if not audio_chunks:
        print("No audio recorded.")
        return None, 0

    audio = np.concatenate(audio_chunks)
    # Save to a temporary WAV file first
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_wav:
        wav_path = tmp_wav.name
        import scipy.io.wavfile as wav
        wav.write(wav_path, fs, audio)

    # Use ffmpeg to convert to webm (Opus codec for compression)
    ffmpeg_cmd = [
        "ffmpeg",
        "-y",  # Overwrite output file if exists
        "-i", wav_path,
        "-c:a", "libopus",
        "-b:a", "32k",  # Low bitrate for compression
        filename
    ]
    try:
        subprocess.run(ffmpeg_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"Recording saved to {filename}")
    except Exception as e:
        print("Error during conversion to webm:", e)
        os.remove(wav_path)
        return None, 0

    os.remove(wav_path)
    audio_length_seconds = len(audio) / fs
    print(f"Audio length: {audio_length_seconds:.2f} seconds")
    return filename, audio_length_seconds



def record_audio_wav(filename="output.wav", fs=44100):
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


def audio_to_text(audio_file):
    client = openai.OpenAI(api_key=openai_api_key)
    with open(audio_file, "rb") as audio_file:
        transcript_response = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file
        )
    return transcript_response.text


def ask_openai(system_prompt,user_prompt,model="o3"):
    client = openai.OpenAI(api_key=openai_api_key)
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role":"system","content":system_prompt},
            {"role":"user","content":user_prompt}
        ]
        #service_tier="standard"
    )
    return response.choices[0].message.content


def load_text_file(textfile):
    with open(textfile, "r", encoding="utf-8") as f:
        return f.read()


def save_string_to_file(text,filename):
    with open(filename, "w", encoding="utf-8") as f:
        f.write(text)