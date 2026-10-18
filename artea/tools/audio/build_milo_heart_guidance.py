import os,json,random,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
os.environ['HF_HOME']=str(ROOT/'work/milo-speech-cache')
os.environ['HF_HUB_DISABLE_XET']='1'
os.environ['TOKENIZERS_PARALLELISM']='false'
import torch,numpy as np,soundfile as sf
from chatterbox.tts_turbo import ChatterboxTurboTTS
torch.set_num_threads(4)
torch.manual_seed(2603);random.seed(2603);np.random.seed(2603)
folder=ROOT/'artea/assets/audio/milo/heart_guidance'
manifest=json.loads((folder/'lines.json').read_text(encoding='utf-8'))
reference=ROOT/'artea/assets/audio/milo/milo_voice.ogg'
print('Loading CPU voice model',flush=True)
model=ChatterboxTurboTTS.from_pretrained(device='cpu',nano=True)
model.prepare_conditionals(str(reference),exaggeration=0.15)
print('Reference ready',flush=True)
for key,text in manifest['lines'].items():
    output=folder/(key+'.ogg')
    if output.exists(): continue
    print('Generating',key,flush=True);started=time.time()
    # Sentence-sized takes prevent truncation and keep the tutorial calm.
    import re
    chunks=re.split(r'(?<=[.!?])\s+',text)
    parts=[]
    for chunk in chunks:
        with torch.inference_mode(): wave=model.generate(chunk,temperature=0.65,exaggeration=0.15)
        parts.extend([wave.squeeze().cpu().numpy(),np.zeros(int(model.sr*0.22),dtype=np.float32)])
    data=np.concatenate(parts)
    peak=np.max(np.abs(data))
    if peak>0: data=data*(0.7/peak)
    sf.write(str(output),data,model.sr,format='OGG',subtype='VORBIS')
    print('Saved',key,round(len(data)/model.sr,1),'seconds in',round(time.time()-started,1),'seconds',flush=True)
print('ALL MILO GUIDANCE CLIPS READY',flush=True)
