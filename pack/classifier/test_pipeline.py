import copy, math, unittest
from common import LABELS, PREPROCESSING, artifact, canonical, digest, payload, read, score, validate_corpus, validate_vectors
from prepare import prepare
from train import fit, evaluate, release
from pathlib import Path

class PipelineTests(unittest.TestCase):
    def sample(self):
        rows=[]; vectors=[]; baseline={}; rules=[]
        for split,n in [('train',50),('calibration',20),('final',120),('regression',20)]:
            for i in range(n):
                scam = i>=100 if split=='final' else True if split=='regression' else i%2==1
                labels=list(LABELS) if scam else []
                r={'id':f'{split}:{i}','text':f'fixture {split} {i}','labels':labels, 'scam':scam,
                 'source':'synthetic' if split=='train' else 'official' if scam and split!='regression' else 'inbox' if not scam else 'regression',
                 'source_url':'https://example.gov/warning','complete':True,'split':split,'group':f'{split}:{i}','reviewed':True}
                rows.append(r);vectors.append({'id':r['id'],'vector':[1.,.1] if scam else [-1.,.1]})
                baseline[r['id']]=.2;rules.append({'id':r['id'],'reasons':[]})
        bundle={'task':'retrievalQuery','preprocessing':PREPROCESSING,'fingerprint':'sha256:'+('a'*64)+':'+('b'*64),
          'baseline_threshold':.56,'dimension':2,'records':vectors,'baseline_scores':baseline,'corpus_sha256':digest(canonical(rows))}
        return rows,bundle,{'corpus_sha256':bundle['corpus_sha256'],'records':rules}
    def test_fit_calibration_and_final_gate(self):
        rows,bundle,rules=self.sample();frozen=fit(rows,bundle);p=payload(frozen)
        for label,h in p['heads'].items():
            highest=max(score(h,v['vector']) for v in bundle['records'] if v['id'].startswith('calibration:') and int(v['id'].split(':')[1])%2==0)
            self.assertGreater(h['threshold'],highest)
        report=evaluate(rows,bundle,frozen,rules)
        self.assertTrue(report['evaluation_passed']);self.assertEqual(report['regression_detected'],20)
        self.assertEqual(report['final_ordinary'],100);self.assertEqual(report['final_detected'],20)
        self.assertEqual(report['label_results']['credentials']['fp'],0)
        self.assertEqual(report['complete_checker_verdicts']['scams:caution'],20)
        phone={'artifact_version':frozen['version'],'user_initiated':True,'tested_at':'fixture', 'checks':{k:True for k in ['offline','responsive','resumable','fallback']}}
        self.assertTrue(release(frozen,report,phone)['release']['phone_verified'])
        phone['checks']['fallback']=False
        with self.assertRaises(ValueError): release(frozen,report,phone)
    def test_final_labels_never_change_fitted_weights(self):
        rows,bundle,_=self.sample();a=payload(fit(rows,bundle))
        for r in rows:
            if r['split']=='final':r['labels']=[];r['scam']=False
        bundle['corpus_sha256']=digest(canonical(rows));b=payload(fit(rows,bundle))
        self.assertEqual(a['heads'],b['heads'])
    def test_campaign_and_synthetic_leakage_rejected(self):
        rows,_,_=self.sample();rows[0]['split']='final'
        with self.assertRaises(ValueError): validate_corpus(rows)
        rows,_,_=self.sample();rows[-1]['group']=rows[0]['group']
        with self.assertRaises(ValueError): validate_corpus(rows)
        rows,_,_=self.sample();rows[-1]['text']=rows[0]['text']
        with self.assertRaises(ValueError): validate_corpus(rows)
    def test_unreviewed_and_incomplete_examples_rejected(self):
        rows,_,_=self.sample();rows[-1]['reviewed']=False
        with self.assertRaises(ValueError): validate_corpus(rows)
        rows,_,_=self.sample();rows[-1].update(source='official',complete=False)
        with self.assertRaises(ValueError): validate_corpus(rows)
    def test_query_fingerprint_and_dimension_required(self):
        rows,bundle,_=self.sample()
        for patch in [{'task':'retrievalDocument'},{'fingerprint':'wrong'},{'dimension':3},{'corpus_sha256':'wrong'}]:
            with self.assertRaises(ValueError): validate_vectors({**bundle,**patch},rows)
    def test_python_fixture_is_reproducible(self):
        f=read(Path(__file__).parent/'score_fixture.json');p=payload(f['artifact'])
        for l in LABELS:self.assertAlmostEqual(score(p['heads'][l],f['vector']),f['scores'][l],places=12)
    def test_near_duplicates_stay_in_one_partition(self):
        rows=prepare(['Your OTP is 123456. Do not share.','Your OTP is 999999. Do not share.','Your OTP is 123456. Do not share.'])
        ordinary=[r for r in rows if r['source']=='inbox']
        self.assertEqual(len(ordinary),2)
        self.assertEqual(len({r['group'] for r in ordinary}),1)
        self.assertEqual(len({r['split'] for r in ordinary}),1)
    def test_calibration_needs_real_scam_examples(self):
        rows,bundle,_=self.sample()
        for r in rows:
            if r['split']=='calibration':r['scam']=False;r['labels']=[]
        bundle['corpus_sha256']=digest(canonical(rows))
        with self.assertRaises(ValueError):fit(rows,bundle)

if __name__=='__main__':unittest.main()
