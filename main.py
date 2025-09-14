import useful_functions as uf
import instruction_collection as prompts

# These are the functions that we can use:

# uf.record_audio_webm(filename,fs)
# This records audio in a small compressed format. fs is the quality of the recording. The higher the quality the larger the file size gets. I have found that 10000 is the lowest with which I get ok quality. The recording gets saved as a file. The function returns 2 variables, the filename and the recording duration in seconds.

# uf.record_audio_wav(filename,fs)
# This records audio in a large uncompressed format. We should avoid using this one.

# uf.audio_to_text(audio_file)
# Takes an audio file and outputs a string variable using openai's transcription feature.

# uf.ask_openai(system_prompt,user_prompt,model)
# This is like asking something from chatgpt. We've been putting the instructions into system_prompt and the conversation transcript into user_prompt. I don't know if this is the best way to do it, but I suggest we continue like this for now. The model could be "gpt-4o-mini", "gpt-4o", "gpt-5", "o1", "o3", etc. Here is a list of all the models that can be used: https://platform.openai.com/docs/pricing?latest-pricing=standard

# uf.load_text_file(textfile)
# This takes a text file and returns a string variable. It is useful if we have sample conversations stored as files.

# uf.save_string_to_file(text,filename)
# With this you can save a string variable into a file.


uf.record_audio_webm(filename="patient-recording.webm",fs=10000)
patient_transcript=uf.audio_to_text(audio_file="patient-recording.webm")
print(patient_transcript)
complaints=uf.ask_openai(system_prompt="You are a doctor trying to diagnose a patient based on complaints. You only repond with a comma separated list of possible diagnoses",user_prompt=patient_transcript,model="o3")
print(complaints)
uf.save_string_to_file(text=patient_transcript,filename="patient_transcript.txt")
