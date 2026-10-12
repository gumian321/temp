"""Independent mission simulations with isolated save paths and individual reports."""
import subprocess,os,json,concurrent.futures,time
from pathlib import Path
R=Path(__file__).resolve().parents[1]
names=['Station Protector','Bounty Hunter','Gardian Angel','Endless','Survival','Station Hunter']
def run(name):
 prefix=('balanced-' if os.environ.get('RBPEW_BALANCED_FIXTURE')=='1' else '')+name.lower().replace(' ','-')+'-';env=os.environ|{'XDG_DATA_HOME':'/workspace/scratch/campaign-data','XDG_CONFIG_HOME':'/workspace/scratch/campaign-config','XDG_CACHE_HOME':'/workspace/scratch/cache','RBPEW_TEST_MISSION':name,'RBPEW_REPORT_NAME':prefix}
 with open(R/f'artifacts/{prefix}campaign.log','w') as f:p=subprocess.run(['godot','--headless','--path',str(R),'--script','res://tests/test_campaign.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1500)
 result=json.loads((R/f'artifacts/{prefix}campaign-report.json').read_text());print(name,p.returncode,json.dumps(result['results']),flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:results=list(ex.map(run,names))
report={'fixture':results[0]['fixture'],'step_seconds':results[0]['step_seconds'],'results':sum([r['results'] for r in results],[])}
(R/('artifacts/balanced-campaign-report.json' if os.environ.get('RBPEW_BALANCED_FIXTURE')=='1' else 'artifacts/campaign-report.json')).write_text(json.dumps(report,indent=2));print('CAMPAIGN_COMPLETE',flush=True)
