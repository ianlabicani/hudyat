"""Train and calibrate, freeze, then evaluate using separate invocations."""
import argparse, math, warnings
from collections import Counter
from common import LABELS, PREPROCESSING, SEED, artifact, canonical, digest, payload, read, score, validate_corpus, validate_vectors, verdict, write

def fit(rows, bundle):
    import numpy as np
    import sklearn
    from sklearn.exceptions import ConvergenceWarning
    from sklearn.linear_model import LogisticRegression
    validate_corpus(rows)
    vectors = validate_vectors(bundle, rows)
    training = [r for r in rows if r['split']=='train']
    calibration = [r for r in rows if r['split']=='calibration']
    ordinary = [r for r in calibration if not r['scam']]
    if not ordinary or not any(r['scam'] for r in calibration): raise ValueError('Separate real scam and ordinary calibration required')
    from common import normalize
    x = np.array([normalize(vectors[r['id']]) for r in training])
    heads = {}
    with warnings.catch_warnings():
        warnings.simplefilter('error',ConvergenceWarning)
        for label in LABELS:
            y = [int(label in r['labels']) for r in training]
            if len(set(y)) != 2: raise ValueError('Each label requires positives and negatives')
            model = LogisticRegression(C=1, penalty='l2', solver='liblinear', class_weight='balanced', random_state=SEED, max_iter=2000)
            model.fit(x,y)
            head = {'weights':model.coef_[0].tolist(),'bias':float(model.intercept_[0]),'threshold':1.0}
            highest = max(score(head,vectors[r['id']]) for r in ordinary)
            # Margin exceeds Python/Dart summation rounding; still chosen only
            # from calibration negatives, before final testing.
            threshold = math.nextafter(highest + 1e-6,math.inf)
            if threshold > 1: raise ValueError('No threshold above ordinary calibration scores')
            head['threshold'] = threshold
            heads[label] = head
    return artifact({'schema':1,'preprocessing':PREPROCESSING,'dimension':bundle['dimension'], 'fingerprint':bundle['fingerprint'],
      'heads':heads,'training':{'threshold_margin':1e-6,'seed':SEED,'C':1,'class_weight':'balanced','max_iter':2000,'solver':'liblinear','penalty':'l2',
       'scikit_learn':sklearn.__version__, 'numpy':np.__version__, 'corpus_sha256':bundle['corpus_sha256'],
       'vectors_sha256':digest(canonical(bundle)), 'train_ids_sha256':digest(canonical(sorted(r['id'] for r in training))),
       'calibration_ids_sha256':digest(canonical(sorted(r['id'] for r in calibration)))}})

def evaluate(rows, bundle, envelope, rules):
    validate_corpus(rows); vectors=validate_vectors(bundle,rows); p=payload(envelope)
    if p['fingerprint'] != bundle['fingerprint'] or p['training']['corpus_sha256'] != bundle['corpus_sha256'] or p['training']['vectors_sha256'] != digest(canonical(bundle)):
        raise ValueError('Frozen corpus/model/vector mismatch')
    if rules['corpus_sha256'] != bundle['corpus_sha256']: raise ValueError('Rules corpus mismatch')
    rule_rows={r['id']:r['reasons'] for r in rules['records']}
    if set(rule_rows) != set(vectors): raise ValueError('Incomplete rule results')
    final=[r for r in rows if r['split']=='final']; regression=[r for r in rows if r['split']=='regression' and r['scam']]
    if len(regression) != 20: raise ValueError('Expected the existing 20-scam regression set')
    counts = Counter(); label_counts={l:Counter({'tp':0,'fn':0,'fp':0,'tn':0}) for l in LABELS}; complete=Counter(); reg_detected=0
    for r in final+regression:
        v=vectors[r['id']]; labels=[l for l in LABELS if score(p['heads'][l],v)>=p['heads'][l]['threshold']]
        if r['split']=='regression': reg_detected+=bool(labels); continue
        baseline = bundle['baseline_scores'][r['id']] >= bundle['baseline_threshold']
        kind='scams' if r['scam'] else 'ordinary'
        counts[kind]+=1
        counts['detected' if r['scam'] else 'ordinary_warnings']+=bool(labels)
        counts['baseline_detected' if r['scam'] else 'baseline_ordinary_warnings']+=baseline
        if not r['scam'] and labels and not baseline: counts['additional_ordinary_warnings']+=1
        for l in LABELS:
            gold=l in r['labels']; detected=l in labels
            label_counts[l]['tp' if gold and detected else 'fn' if gold else 'fp' if detected else 'tn']+=1
        new=verdict(rule_rows[r['id']],bool(labels)); old=verdict(rule_rows[r['id']],baseline)
        complete[kind+':'+new]+=1; complete['baseline:'+kind+':'+old]+=1
        if not r['scam'] and ((new!='clear' and old=='clear') or (new=='scam' and old!='scam')): complete['additional_ordinary_warnings']+=1
    passed=(counts['scams']>=20 and counts['ordinary']>=100 and reg_detected>=13 and counts['detected']>counts['baseline_detected']
      and counts['additional_ordinary_warnings']==0 and complete['additional_ordinary_warnings']==0)
    return {'artifact_version':envelope['version'], 'corpus_sha256':bundle['corpus_sha256'],'vectors_sha256':digest(canonical(bundle)),
     'rules_sha256':digest(canonical(rules)), 'model_fingerprint':bundle['fingerprint'], 'baseline_version':bundle.get('baseline_version'), 'regression_scams':20,'regression_detected':reg_detected,
     'final_scams':counts['scams'],'final_ordinary':counts['ordinary'],'final_detected':counts['detected'],'baseline_detected':counts['baseline_detected'],
     'ordinary_warnings':counts['ordinary_warnings'],'baseline_ordinary_warnings':counts['baseline_ordinary_warnings'],
     'additional_ordinary_warnings':counts['additional_ordinary_warnings']+complete['additional_ordinary_warnings'],
     'label_results':{l:dict(c) for l,c in label_counts.items()},'complete_checker_verdicts':dict(complete), 'evaluation_passed':passed}

def release(envelope, report, phone):
    payload(envelope)
    if report['artifact_version'] != envelope['version'] or not report['evaluation_passed']: raise ValueError('Evaluation gate failed')
    if phone.get('artifact_version') != envelope['version'] or phone.get('user_initiated') is not True or not phone.get('tested_at'):
        raise ValueError('User-initiated phone receipt required for this artifact')
    checks = phone.get('checks',{})
    if any(checks.get(k) is not True for k in ('offline','responsive','resumable','fallback')): raise ValueError('Phone gate failed')
    return {**envelope,'release':{**report,'report_sha256':digest(canonical(report)), 'phone_verified':True,'phone_checks':checks,
      'phone_receipt_sha256':digest(canonical(phone))}}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['fit','evaluate','release'])
    for name in ('corpus','vectors','artifact','rules','report','phone','out'):parser.add_argument('--'+name)
    a=parser.parse_args()
    if a.command=='fit':
        from pathlib import Path
        if Path(a.out).exists(): parser.error('Frozen artifact already exists; do not refit after final testing')
        result=fit(read(a.corpus),read(a.vectors))
    elif a.command=='evaluate': result=evaluate(read(a.corpus),read(a.vectors),read(a.artifact),read(a.rules))
    else: result=release(read(a.artifact),read(a.report),read(a.phone))
    write(a.out,result);print(canonical({'command':a.command,'artifact_version':result.get('version',result.get('artifact_version')),
      'evaluation_passed':result.get('evaluation_passed'), 'output_sha256':digest(canonical(result))}))
