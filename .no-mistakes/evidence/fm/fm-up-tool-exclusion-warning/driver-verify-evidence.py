import json
from pathlib import Path
E=Path('/home/node/.no-mistakes/evidence/01M65MFBQHY7METR56JHMH28BV')
cases={r['scenario']:r for r in json.loads((E/'pi-live-results.json').read_text())}
excluded=['mcp__tracker__editIssue','mcp__tracker__createIssue']
for name,case in cases.items():
    assert case['exit']==0 and case['requests']>0,case
    assert not (E/f'pi-{name}-stderr.log').read_text(),name
    starts=[e for e in case['observed_events'] if e.get('event')=='agent_start']
    assert len(starts)==2,(name,starts)
    assert case['observed_events'][-1]['event']=='agent_settled',name
    executed=[e['executed'] for e in case['observed_events'] if 'executed' in e]
    assert not set(excluded)&set(executed),(name,executed)
    warnings=[l for l in case['status'].splitlines() if l.startswith('note [state=none]')]
    if name in ('absent','mcp-absent'):
        assert not warnings,(name,warnings)
        assert all(not set(excluded)&set(s['tools']) for s in starts),(name,starts)
    elif name in ('present','late'):
        assert len(warnings)==(2 if name=='present' else 1),(name,warnings)
        for tool in excluded: assert sum(w.count(tool) for w in warnings)==1,(name,tool,warnings)
        assert all('mcp__tracker__readIssue' not in w for w in warnings)
        ends=[e for e in case['observed_events'] if e.get('event')=='tool_execution_end']
        direct=next(e for e in ends if e['toolName']==excluded[0])
        nested=next(e for e in ends if e['toolName']==excluded[1])
        assert direct['isError'] and direct['result']['content'][0]['text']==excluded[0]+' is excluded by config/crew-exclude-tools'
        assert nested['isError'] and nested['parentToolCallId']=='call_2'
        assert nested['result']['content'][0]['text']==excluded[1]+' is excluded by config/crew-exclude-tools'
        assert executed==['mcp__tracker__readIssue'],(name,executed)
        assert excluded[0] in starts[1]['tools'] and excluded[1] in starts[1]['tools']
    else:
        assert name=='next-start' and len(warnings)==1
        assert excluded[0] not in starts[0]['tools'] and excluded[0] in starts[1]['tools']
        assert case['status'].index('resolved [key=shape]')<case['status'].index('note [state=none]')
mcp=[json.loads(l) for l in (E/'pi-mcp-server.jsonl').read_text().splitlines()]
assert [r['executed'] for r in mcp if 'executed' in r]==['readIssue']
assert any(r.get('request',{}).get('method')=='tools/list' for r in mcp)
readers=json.loads((E/'status-readers-live.json').read_text())
assert len(readers)==10
for r in readers: assert r['before']==r['after'],r
assert readers[0]['after'].startswith('state: done')
assert readers[-1]['voice']['worker_states']=={'no events yet':1}
assert readers[-2]['voice']['worker_states']=={'note':1}
assert 'STATUS OUTCOME BACKSTOP (' in (E/'wake-first-drain.txt').read_text()
assert 'STATUS OUTCOME BACKSTOP (' not in (E/'wake-second-drain.txt').read_text()
commands=json.loads((E/'status-readers-commands.json').read_text())
assert commands[-1]['command'][-2]=='teardown' and commands[-1]['exit']==0
spawn=json.loads((E/'spawn-live-commands.json').read_text())
assert spawn[-1]['command'][-2]=='teardown' and spawn[-1]['exit']==0
assert len(json.loads((E/'spawn-invalid-entries.json').read_text()))==3
assert json.loads((E/'spawn-local-endpoint-requests.json').read_text())
assert 'Disposable worker completed its isolated launch.' in (E/'spawn-valid-pane.txt').read_text()
assert (E/'pi-late-tools.html').stat().st_size>10000
print('Verified real registry filtering, late and next-start warnings, per-tool deduplication after reconnect, direct/nested denial, allowed calls, state-reader parity, unread warning visibility, spawn refusals/acceptance, and guarded lab cleanup.')
