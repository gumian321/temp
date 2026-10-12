"""Verify local archive integrity and record actual exported-runtime acceptance."""
import json,hashlib,subprocess,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[1];D=Path('/workspace/centipede-deliverables');manifest=json.loads((D/'checksums.json').read_text());files=[]
for entry in manifest['files']:
 p=D/entry['name'];valid=p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256'];record={'name':entry['name'],'sha256_matches':valid,'bytes':p.stat().st_size if p.exists() else 0}
 if p.suffix=='.zip':
  with zipfile.ZipFile(p) as z:record['zip_crc_ok']=z.testzip() is None;record['entries']=len(z.infolist())
 files.append(record)
bundle=subprocess.run(['git','bundle','verify',str(D/'centipede-local-history.bundle')],cwd=R,capture_output=True,text=True)
log=(R/'artifacts/packed-runtime-smoke.log').read_text();smoke=json.loads((R/'artifacts/packed-runtime-smoke-report.json').read_text())
runtime='SMOKE_FLOW_COMPLETE'in log and 'ERROR:'not in log and hashlib.sha256((D/'linux-runtime/game.pck').read_bytes()).hexdigest()==smoke['tested_game_pck_sha256']
suite=json.loads((R/'artifacts/consolidated-test-report.json').read_text());source=json.loads((R/'artifacts/source-integrity.json').read_text());save=json.loads((R/'artifacts/restart-save-report.json').read_text());campaign=json.loads((R/'artifacts/balanced-campaign-report.json').read_text())
report={'revision':manifest['revision'],'files':files,'bundle_verify_ok':bundle.returncode==0,'actual_packed_runtime_smoke_passed':runtime,'automatic_suites':len(suite['suites']),'automatic_suites_passed':suite['passed'],'fresh_process_save_passed':save['passed'],'source_integrity':source,'mission_results':campaign['results'],'worktree_clean':not subprocess.check_output(['git','status','--porcelain'],cwd=R,text=True),'full_parity_accepted':False,'latest_library_ids':[],'library_blocker':'Previously denied official upload (403); explicit instruction prohibits retry or alternate route. Early data-only backup is not runnable.'}
report['local_delivery_verified']=all(f['sha256_matches'] and f.get('zip_crc_ok',True) for f in files) and bundle.returncode==0 and runtime and suite['passed'] and save['passed'] and source['source_untouched']
(D/'delivery-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in report.items() if k not in ['mission_results','source_integrity','files']},ensure_ascii=False));raise SystemExit(0 if report['local_delivery_verified'] else 1)
