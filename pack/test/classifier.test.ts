import { describe, expect, test } from 'bun:test';
import fixture from '../classifier/score_fixture.json';
import { validateClassifier, type ClassifierEnvelope } from '../src/classifier';
const released = (): ClassifierEnvelope => ({...fixture.artifact, release:{
  artifact_version:fixture.artifact.version, evaluation_passed:true, phone_verified:true,
  regression_scams:20, regression_detected:13, final_scams:20, final_ordinary:100, final_detected:15, baseline_detected:12,
  additional_ordinary_warnings:0, report_sha256:'a'.repeat(64),
  phone_checks:{offline:true,responsive:true,resumable:true,fallback:true},
}});
describe('optional classifier release',()=>{
  test('numerically valid fixture is rejected without release evidence',()=>{
    expect(()=>validateClassifier(fixture.artifact)).toThrow('release gate');
    expect(()=>validateClassifier(released())).not.toThrow();
  });
  test('failed or incomplete evidence blocks shipping',()=>{
    for (const patch of [{regression_detected:12},{final_scams:19},{final_ordinary:99},{final_detected:12},{additional_ordinary_warnings:1},{phone_verified:false},{phone_checks:{offline:true}}]) {
      const a=released();Object.assign(a.release!,patch);
      expect(()=>validateClassifier(a)).toThrow();
    }
  });
  test('payload cannot be altered after calibration',()=>{
    const a=released();a.payload+=' ';
    expect(()=>validateClassifier(a)).toThrow('hash');
  });
});

import { Database } from 'bun:sqlite';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import reasons from '../data/scam_reasons.json';
import { writePack } from '../src/write';

test('approved classifier round trips through pack; AI edits leave rule identity unchanged',()=>{
  const dir=mkdtempSync(join(tmpdir(),'hudyat-classifier-'));
  const a=join(dir,'a.sqlite'), b=join(dir,'b.sqlite');
  const contents={meta:{name:'Test',area:'Test',buildDate:'2026-10-09',bbox:[0,0,1,1] as [number,number,number,number],sources:[]},records:[],intents:[],
    scam:{senders:[],examples:[],reasons,shorteners:[],neutralHosts:[],senderIds:[]}};
  try {
    writePack(a,contents);
    writePack(b,{...contents,classifier:released(),scam:{...contents.scam,reasons:reasons.map(r=>({...r,tl:r.tl+' reviewed'})), examples:[{text:'synthetic training change',type:'test',type_label:'test'}]}});
    const first=new Database(a),second=new Database(b);
    try {
      const value=(db:Database,key:string)=>(db.query('SELECT value FROM meta WHERE key=?').get(key) as {value:string}|null)?.value;
      expect(value(first,'suspicious_classifier')).toBeUndefined();
      expect(JSON.parse(value(second,'suspicious_classifier')!).version).toBe(fixture.artifact.version);
      expect(value(first,'rules_version')).toBe(value(second,'rules_version'));
    } finally {first.close();second.close();}
  } finally {rmSync(dir,{recursive:true});}
});
