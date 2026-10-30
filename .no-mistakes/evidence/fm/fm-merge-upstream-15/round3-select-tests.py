import pathlib,re,json
R=pathlib.Path.cwd()
E=pathlib.Path('/home/node/.no-mistakes/evidence/01M64ZPT5AJ4390HHRPB92ZDZC')
cases=json.loads((E/'round3-selected-cases.json').read_text())
for name,selected in cases.items():
    text=(R/'tests'/f'{name}.test.sh').read_text()
    if name=='fm-crew-state':
        text=text[:text.index('\ntest_captured_axi_status_shapes\n')]
    elif name=='fm-agy-primary':
        text=text[:text.rindex('\nfm_test_run ')]
    else:
        text='\n'.join(': # scoped-out invocation' if line.startswith('test_') and '()' not in line else line for line in text.split('\n'))
    text+='\nfm_test_run '+' '.join(selected)+'\n'
    (R/'tests'/f'.round3-{name}.sh').write_text(text)
