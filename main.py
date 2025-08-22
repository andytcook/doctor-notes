

import sounddevice as sd
import numpy as np
import scipy.io.wavfile as wav
import threading
import math
import openai
import os

openai_api_key = os.getenv('OPENAI_API_KEY')

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


def load_text_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()


def save_string_to_file(text, filename):
    with open(filename, "w", encoding="utf-8") as f:
        f.write(text)




system_prompt_get_info_from_conversation = "Your job is to extract medical information from a conversation transcript and format it in json format. The json should have the following keys: name, age, gender, main complaint, other symptoms, negative symptoms (all the symptoms which the patient denies having), risk factors, recent medical history, past medical history, medication history, allergies, family history, social history, review of systems, physical examination results, diagnosis, and differential diagnosis. Only return the json, no other text. Include all the json keys in the order they are listed. If the main complaint is any type of pain, extract all the relevant information regarding: exact site, onset (how the pain began), character (ex. throbbing, burning, aching, pulsating, electric), radiation to other parts of the body, associated symptoms, timing or evolution, exacerbating/relieving factors, and severity. If the are other symptoms, for each of them extract information about onset (particularly if acute, subacute, insidious), evolution, severity and the relation to the main symptom. List all the negative symptoms in a structered way and according to similar organ systems like \"denies X and Y\" where X and Y are related symptom of the same organ, \"also denies Z\". In recent medical history store recent health information that could influence the main complaint (ex. hospitalizations, treatments). In past medical history store information of previous, known and current diseases (usually chronic). If none are are to be found state \"generally healthy\". In social history store information about the job, relationships and general lifestyle (ex. physically active or sedentary). In review of system list all the positive and negative symptoms for each organ system in a structured way. If you cannot find the information for certain fields, put \"unknown\" for the value. Write the values in 3rd person in consise and medically accurate ways. For each symptom use the medically accurate translation (for example shortness of breath = dyspnea, or head spinning = vertigo)."



conversation=load_text_file("transcript_zeno_2.txt")
info=ask_openai(system_prompt=system_prompt_get_info_from_conversation,user_prompt=conversation,model="o3")
print(info)

