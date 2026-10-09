"""Shared validation/scoring; no private messages or vectors in public output."""
import hashlib, json, math, re
from pathlib import Path
LABELS = ('credentials', 'money', 'action', 'pressure', 'bait')
PREPROCESSING = 'query-l2-v1'
SEED = 42

def digest(value):
    return hashlib.sha256(value.encode() if isinstance(value,str) else value).hexdigest()

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',',':'), allow_nan=False)

def read(path): return json.loads(Path(path).read_text())
def write(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(canonical(value)+'\n')

def normalize(vector):
    if not vector or any(not math.isfinite(v) for v in vector): raise ValueError('Invalid embedding')
    norm = math.sqrt(sum(v*v for v in vector))
    if not math.isfinite(norm) or norm == 0: raise ValueError('Zero embedding')
    return [v/norm for v in vector]

def score(head, vector):
    z = head['bias'] + sum(a*b for a,b in zip(head['weights'], normalize(vector)))
    if math.isnan(z): raise ValueError('Invalid classifier score')
    return 1/(1+math.exp(-z)) if z >= 0 else math.exp(z)/(1+math.exp(z))

def artifact(payload):
    raw = canonical(payload)
    return {'payload':raw,'version':digest(raw)}

def payload(envelope):
    raw = envelope['payload']
    if digest(raw) != envelope['version']: raise ValueError('Artifact hash mismatch')
    result = json.loads(raw)
    if result['schema'] != 1 or result['preprocessing'] != PREPROCESSING: raise ValueError('Preprocessing mismatch')
    if not re.fullmatch(r'sha256:[a-f0-9]{64}:[a-f0-9]{64}',result['fingerprint']): raise ValueError('Missing model/tokenizer hashes')
    if set(result['heads']) != set(LABELS): raise ValueError('Missing heads')
    dim = result['dimension']
    if not isinstance(dim,int) or not 0 < dim <= 4096: raise ValueError('Invalid dimension')
    for head in result['heads'].values():
        if len(head['weights']) != dim or not all(math.isfinite(v) for v in head['weights']+[head['bias'],head['threshold']]): raise ValueError('Invalid head')
        if not 0 < head['threshold'] <= 1: raise ValueError('Invalid threshold')
    return result

def validate_corpus(rows):
    ids, groups, texts = set(), {}, {}
    for row in rows:
        if row['id'] in ids: raise ValueError('Duplicate id')
        ids.add(row['id'])
        if set(row['labels'])-set(LABELS): raise ValueError('Invalid label')
        if row['source'] == 'synthetic' and row['split'] != 'train': raise ValueError('Synthetic test data')
        if not row['reviewed']: raise ValueError('Unreviewed campaign/labels')
        if row['split'] not in ('train','calibration','final','regression'): raise ValueError('Invalid split')
        if row['group'] in groups and groups[row['group']] != row['split']: raise ValueError('Campaign leakage')
        groups[row['group']] = row['split']
        key = re.sub(r'\W+','',row['text'].lower())
        if key in texts and texts[key] != row['split']: raise ValueError('Duplicate leakage')
        texts[key] = row['split']
        if row['source'] == 'official' and (not row.get('source_url','').startswith('https://') or not row.get('complete',False)):
            raise ValueError('Incomplete official sample')

def validate_vectors(bundle, rows):
    if bundle.get('baseline_threshold') != .56: raise ValueError('Baseline threshold mismatch')
    if bundle['preprocessing'] != PREPROCESSING or bundle['task'] != 'retrievalQuery': raise ValueError('Query task required')
    if not re.fullmatch(r'sha256:[a-f0-9]{64}:[a-f0-9]{64}',bundle['fingerprint']): raise ValueError('Model hashes required')
    if bundle['corpus_sha256'] != digest(canonical(rows)): raise ValueError('Corpus changed after export')
    vectors = {r['id']:r['vector'] for r in bundle['records']}
    if len(vectors) != len(bundle['records']) or set(vectors) != {r['id'] for r in rows}: raise ValueError('Incomplete vectors')
    for vector in vectors.values():
        if len(vector) != bundle['dimension']: raise ValueError('Dimension mismatch')
        normalize(vector)
    return vectors

def verdict(reason_ids, ai):
    groups = set(reason_ids)
    if ai: groups.add('ai')
    if groups & {'link_lookalike','link_hidden','link_not_official'} or len(groups) >= 2: return 'scam'
    return 'caution' if groups else 'clear'
