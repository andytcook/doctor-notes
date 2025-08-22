import openai

openai_api_key = "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"

audio_file = "/Users/acook/Andris/coding/doctor-summary/audio_conversation.wav"

def transcribe_audio_verbose(audio_path):
    client = openai.OpenAI(api_key=openai_api_key)
    with open(audio_path, "rb") as audio_file:
        transcript_response = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file,
            response_format="verbose_json"
        )
    return transcript_response


transcript = transcribe_audio_verbose(audio_file)
print(transcript)
