import json,hashlib,pathlib,datetime,sys
root=pathlib.Path('docs/feedback/scanner-review-20261017');current='--current' in sys.argv
p=root/('b-transport-325aabc7.json' if current else 'b-transport-actual-ha-v1.json');d=json.loads(p.read_bytes());raw_examples=d['examples']
# Current capture inserts three renewals before revoke and adds discovery/config-error reads.
# Preserve the original semantic case numbering for the common checks below.
e=[raw_examples[i] for i in list(range(15))+list(range(18,24))] if current else raw_examples
checks=[]
def check(name,ok):
 if not ok:raise AssertionError(name)
 checks.append(name)
check('exact source provenance',d['producer_code_pin']==('3cb9cf129f31d419e8b2027e4dc1ba08fafdb9d8' if current else '951da5d0d7943aa672d60b93f5dfe1d32489b93c') and d['scope']=='actual_isolated_HA_B_transport')
check('nonfunctional captured credentials',d['credentials']=='replaced_nonfunctional_examples_not_replayable')
check('A explicitly unavailable',d['A']=='unavailable')
check('exact captured example count',len(raw_examples)==(26 if current else 21))
http=[x for x in e if x['transport']=='HTTP'];check('HTTP reads/writes no-store',all(x['cache_control']=='no-store' for x in http))
check('version1 requests and responses',all(x['request']['contract_version']==x['response']['contract_version']==1 for x in http))
context=e[0];check('paired context permits absent native Origin',context['authentication']=='ordinary_paired_owner' and context['origin'] is None and context['status']==200)
check('context contains route but no admission',context['response']['route_trust']=='paired_owner_response' and 'display_entry_url' in context['response'] and not {'grant_token','claim_secret','share_id'}&context['response'].keys())
check('paired identity body excludes bearer',all(set(x['request']['identity'])=={'client_type','device_id'} for x in http if 'identity' in x['request']))
check('browser Origin missing/foreign denied',all(e[i]['status']==403 and e[i]['response']['error']=='display_origin_denied' for i in [2,3]))
claim=e[1]['response'];resolve=e[4]['response'];approve=e[5]['response'];collect=e[7]['response']
check('claim resolve binding',all(claim[k]==resolve[k] for k in ['claim_id','browser_generation','issuer_epoch']))
check('approval binds exact resolved generation and session',all(e[5]['request'][k]==resolve[k] for k in ['claim_id','browser_generation','issuer_epoch']) and e[5]['request']['session_id']==context['response']['session_id'])
check('share creation uses explicit consent',e[5]['request']['share']=={'mode':'create','consent':True})
check('repeated approval returns same display/share/generation',all(approve[k]==e[6]['response'][k] for k in ['display_id','share_id','share_generation','session_id']))
check('only browser collects dedicated grant',e[7]['authentication']=='none' and e[7]['request']['claim_secret']==claim['claim_secret'] and collect['grant_token'].startswith('djcd_'))
check('one-time collect failure captured',e[8]['status']==404 and e[8]['response']['error']=='display_claim_unavailable')
check('display cannot become owner via copied identity',e[9]['authentication']=='dedicated_display' and e[9]['status']==401)
check('read-only capability surface',collect['capabilities']=={'view_display':True,'owner_controls':False,'audience_signals':False,'ask_dj':False,'session_end':False,'share_close':False})
snapshot=e[10]['response']['snapshot'];live=e[11]['frame']['snapshot']
check('HTTP and WSS same subject bindings',all(snapshot[k]==live[k]==collect[k] for k in ['issuer_epoch','display_id','share_id','share_generation','session_id','lease_revision']))
check('only compact current presentation labels',set(snapshot['session_presentation'])=={'mood','persona','presence'})
check('renew retry same sequence/revision',e[12]['request']==e[13]['request'] and e[12]['response']['lease_revision']==e[13]['response']['lease_revision']==1)
check('out-of-order renew denied',e[14]['request']['renew_sequence']==3 and e[14]['status']==409)
check('revoked grant denied',e[16]['status']==401 and e[16]['response']['error']=='display_grant_invalid')
check('existing share explicit and no consent creation',e[18]['request']['share']=={'mode':'existing','share_id':approve['share_id'],'share_generation':1})
check('Session end invalidates display',e[20]['status']==401 and e[20]['response']['error']=='display_grant_invalid')
c=json.loads((root/'native-copy.json').read_text());check('five language copy parity',c['languages']==['en','nl','de','fr','es'] and all(set(v)==set(c['languages']) and all(isinstance(t,str) and t.strip() for t in v.values()) for v in c['strings'].values()))
if current:
 capability=raw_examples[24]['response_projection']['session_broadcast']['paired_display_admission']
 check('discovery does not enable A',capability['supported'] is True and capability['rendezvous_a'] is False and capability['availability']=='owner_context_required')
 check('discovery requires current paired route and HTTPS',capability['owner_context_path']=='/api/djconnect/v1/display/owner/context' and capability['requires_external_https'] is True and capability['read_only'] is True)
 check('discovery never releases concrete route or credential',not {'display_entry_url','grant_token','session_id','ha_install_id'}&capability.keys())
 check('missing external route fails closed',raw_examples[25]['status']==503 and raw_examples[25]['response']['error']=='display_external_url_unavailable' and 'display_entry_url' not in raw_examples[25]['response'])
 check('continued renewals advance exact revision',all(raw_examples[i]['status']==200 and raw_examples[i]['request']['renew_sequence']==raw_examples[i]['response']['lease_revision']==i-13 for i in [15,16,17]))
report={'scope':'offline consumer inspection of producer-captured examples; no native/HTTP/WSS execution','fixture_commit':('325aabc7205f1f18928bc2c809817956d91609f8' if current else '0f3d64028eaa456f643d5fb7633f6741846663ca'),'producer_code_pin':d['producer_code_pin'],'fixture_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'checks_passed':checks,'copy_strings':len(c['strings']),'languages':c['languages'],'unrepresented_cases':['expired claim','Profile/pairing ABA withdrawal','missing external configuration','owner permission denied','wrong six-digit code','cancel/rotate race','source withdrawal while awaiting','actual A App Attest/JWE wire'],'native_acceptance':'NOT_RUN','crypto_interoperability':'NOT_RUN','independent_ux_language_review':'OPEN'}
if current: report['unrepresented_cases'].remove('missing external configuration')
(root/('inspection-current-result.json' if current else 'inspection-result.json')).write_text(json.dumps(report,indent=2)+'\n');print(len(checks),'offline corpus/copy checks PASS; native/crypto not run; missing cases recorded')
