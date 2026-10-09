"""Freeze candidate campaign splits before fitting. Human review still required."""
import argparse, difflib, re
from collections import Counter
from pathlib import Path
from common import canonical, digest, read, write, SEED
ROOT = Path(__file__).resolve().parents[1]

def template(text):
    text = re.sub(r'https?://\S+', '<url>', text.lower())
    text = re.sub(r'\b[\w.+-]+@[\w.-]+\b','<email>',text)
    text = re.sub(r'\d+', '#',text)
    return re.sub(r'\s+',' ',text).strip()

def prepare(ordinary):
    rows = []
    for filename in ('ask_examples.json','scam_examples.json'):
        for i,r in enumerate(read(ROOT/'data'/filename)):
            rows.append({'id': f'{filename}:{i}', 'text':r['text'], 'labels':r.get('labels',r.get('ask_labels')),
              'source':'synthetic','split':'train','group':f'synthetic:{filename}:{i}', 'reviewed':True,'scam':bool(r.get('labels',r.get('ask_labels')))})
    # Connected components, not independent row shuffling. Variations of a
    # template/campaign remain in one partition; semantic campaigns need review.
    groups = []
    for text in ordinary:
        key = template(text)
        matches = [g for g in groups if any(difflib.SequenceMatcher(None,key,k).ratio() >= .8 for k,_ in g)]
        if matches:
            merged = [(key,text)]
            for g in matches: merged.extend(g); groups.remove(g)
            groups.append(merged)
        else: groups.append([(key,text)])
    groups.sort(key=lambda g:digest(str(SEED)+canonical(sorted(k for k,_ in g))))
    counts = Counter()
    targets = {'final':max(100,round(len(ordinary)*.5)), 'calibration':max(1,round(len(ordinary)*.25))}
    for g in groups:
        split = 'final' if counts['final'] < targets['final'] else 'calibration' if counts['calibration'] < targets['calibration'] else 'train'
        campaign = 'ordinary:'+digest(canonical(sorted(k for k,_ in g)))[:20]
        for _,text in g:
            rows.append({'id':'ordinary:'+digest(text), 'text':text,'labels':[], 'source':'inbox', 'split':split,
              'group':campaign,'reviewed':False,'scam':False})
            counts[split] += 1
    # Existing 20-scam set is regression only. No synthetic ordinary test rows.
    regression_labels = read(Path(__file__).parent/'regression_labels.json')['labels']
    for i,r in enumerate(read(ROOT/'data/check_messages.json')):
        if r['scam']:
            rows.append({'id':f'regression:{i}', 'text':r['text'],'labels':regression_labels[f'regression:{i}'], 'source':'regression',
              'split':'regression','group':f'regression:{i}','reviewed':True,'scam':True})
    # Remove exact duplicate ordinary texts while preserving their assigned split.
    unique = {r['id']:r for r in rows}
    return list(unique.values())

if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('--ordinary',required=True);p.add_argument('--out',required=True);a=p.parse_args()
    rows=prepare(read(a.ordinary));write(a.out,rows)
    print(canonical({'rows':len(rows),'counts':dict(Counter((r['source']+':'+r['split']) for r in rows)),
        'corpus_sha256':digest(canonical(rows)), 'status':'real campaign and ordinary-label review required; no training performed'}))
