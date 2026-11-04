#!/usr/bin/env python3
"""Build a signed, data-only Veyrath content envelope; the private key stays offline."""
import argparse, base64, hashlib, json, pathlib, subprocess

def b64(data): return base64.b64encode(data).decode('ascii')
p=argparse.ArgumentParser()
p.add_argument('--key', required=True, help='private key path, never commit')
p.add_argument('--bundle', required=True)
p.add_argument('--output', required=True)
p.add_argument('--version', required=True, type=int)
p.add_argument('--channel', required=True, choices=['beta','stable'])
p.add_argument('--rollout', type=int, default=100)
p.add_argument('--min-native', type=int, default=7)
p.add_argument('--max-native', type=int, default=7)
a=p.parse_args()
if not 0<=a.rollout<=100 or a.version<1 or a.min_native>a.max_native: p.error('invalid parameters')
bundle=pathlib.Path(a.bundle).read_bytes()
if len(bundle)>1000000: p.error('bundle exceeds limit')
json.loads(bundle)
manifest={'format':1,'version':a.version,'min_native':a.min_native,'max_native':a.max_native,'channel':a.channel,'rollout_percent':a.rollout,'size':len(bundle),'sha256':hashlib.sha256(bundle).hexdigest()}
raw=json.dumps(manifest,ensure_ascii=False,separators=(',',':')).encode()
signature=subprocess.run(['openssl','dgst','-sha256','-sign',a.key],input=raw,stdout=subprocess.PIPE,check=True).stdout
out=json.dumps({'manifest':b64(raw),'signature':b64(signature),'bundle':b64(bundle)},separators=(',',':'))
if len(out.encode())>1500000: p.error('envelope exceeds limit')
pathlib.Path(a.output).write_text(out,encoding='utf-8')
