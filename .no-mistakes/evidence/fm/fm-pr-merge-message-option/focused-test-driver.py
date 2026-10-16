import pathlib, re, subprocess, os, json
root = pathlib.Path.cwd()
evidence = pathlib.Path('/home/node/.no-mistakes/evidence/01M523GGJHNFXBFZ3AEB4RK0A8')
selected = {
    'fm-pr-bitbucket': [
        'test_merge_sends_a_caller_supplied_message_with_the_strategy',
        'test_merge_message_refusals_never_reach_the_forge',
        'test_merge_message_file_validation',
        'test_merge_message_requires_utf8_validator',
        'test_merge_message_is_normalized_and_read_once',
    ],
    'fm-pr-merge': ['test_message_file_refuses_unsupported_forges'],
}
collector = root / '.validation/collect-fixtures.py'
collector.write_text('''import pathlib, os, json
base=pathlib.Path(os.environ['TMP_ROOT'])
items=[]
for case in sorted(base.iterdir()):
    if not case.is_dir(): continue
    item={'case':case.name,'live':False,'scope':'real fm-pr-merge.sh against synthetic forge command stubs'}
    for name in ['stdout','stderr','bb/merge-body.json','bb/pr-post.json','state/task-x1.meta']:
        path=case/name
        if path.is_file(): item[name]=path.read_text(errors='replace')
    item['merge_requested']=(case/'bb/merge-called').exists()
    item['merge_poll_armed']=(case/'state/task-x1.check.sh').exists()
    item['landed_receipt']=(case/'state/task-x1.pr-poll-merge-notified').exists()
    items.append(item)
pathlib.Path(os.environ['EVIDENCE_DEST']).write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\\n')
''')
env = dict(os.environ)
for key in list(env):
    if key.startswith(('FM_', 'TASKS_AXI_', 'NO_MISTAKES_BITBUCKET_')): env.pop(key)
env.update(TMPDIR=str(root/'.validation/tmp'), HOME=str(root/'.validation/home'), FM_TEST_SKIP_ORPHAN_REAP='1', GIT_CONFIG_NOSYSTEM='1')
for suite, names in selected.items():
    text = (root/'tests'/f'{suite}.test.sh').read_text()
    # Select executable tests without changing their bodies or assertions.
    text = re.sub(r'^test_[A-Za-z0-9_]+\s*$', '', text, flags=re.M)
    text = text.replace('. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"', '. '+str(root/'tests/lib.sh'))
    text += '\n# No spawn/lifecycle occurs in these selected merge-only cases.\nfm_test_remove_spawn_launch_dirs() { :; }\n'
    for name in names:
        text += f"printf '\\nTEST {name}\\n'\n{name}\n"
    if suite == 'fm-pr-bitbucket':
        text += '''
# Exercise every documented Bitbucket strategy through the executable CLI.
for strategy in merge_commit squash squash_fast_forward rebase_merge fast_forward rebase_fast_forward; do
  for selection in explicit default; do
    case_dir=$(make_case "matrix-$selection-$strategy")
    printf 'Generic message\\n\\nQuoted "text", backslash \\\\ and Unicode: Café ✓\\n' > "$case_dir/message.txt"
    if [ "$selection" = default ]; then
      printf '{"values":[{"name":"main","default_merge_strategy":"%s"}]}\\n' "$strategy" > "$case_dir/bb/branches.json"
      extra=()
    else
      extra=(-- --method "$strategy")
    fi
    rc=0
    run_merge "$case_dir" "$BB_URL" --message-file "$case_dir/message.txt" "${extra[@]}" || rc=$?
    case "$strategy" in
      fast_forward|rebase_fast_forward)
        if [ "$selection" = explicit ]; then expected=2; else expected=1; fi
        expect_code "$expected" "$rc" "matrix: $selection $strategy must refuse the message"
        assert_absent "$case_dir/bb/merge-called" "matrix: incompatible strategy submitted a merge"
        ;;
      *)
        expect_code 0 "$rc" "matrix: $selection $strategy should carry the message"
        assert_equals "$strategy" "$(jq -r .merge_strategy "$case_dir/bb/merge-body.json")" "matrix: strategy changed"
        assert_equals "$(cat "$case_dir/message.txt")" "$(jq -r .message "$case_dir/bb/merge-body.json")" "matrix: message changed"
        assert_present "$case_dir/state/task-x1.pr-poll-merge-notified" "matrix: confirmed merge not recorded"
        ;;
    esac
  done
done
pass "all Bitbucket strategies preserve the supplied message or refuse before submission"
# Additional focused guard regression checks, now carrying the new option.
run_merge() {
  local case_dir=$1 url=$2
  shift 2
  printf 'Guard regression message\\n' > "$case_dir/guard-message.txt"
  bb_env "$case_dir" "$ROOT/bin/fm-pr-merge.sh" task-x1 "$url" --message-file "$case_dir/guard-message.txt" "$@" \\
    > "$case_dir/stdout" 2> "$case_dir/stderr"
}
test_merge_refuses_a_head_that_moved_before_the_request
test_merge_reports_forge_refusal_unconfirmed_and_wrong_head
'''
    text += f'export TMP_ROOT\nexport EVIDENCE_DEST={evidence / (suite+"-fixture-results.json")}\npython3 {collector}\n'
    target = root/'.validation'/f'{suite}-selected.sh'
    target.write_text(text)
    result = subprocess.run(['bash', str(target)],cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    (evidence/(suite+'-targeted-tests.txt')).write_bytes(result.stdout)
    print(result.stdout.decode(errors='replace'))
    print(suite+': exit='+str(result.returncode))
    if result.returncode: raise SystemExit(result.returncode)
(evidence/'targeted-selection.json').write_text(json.dumps(selected,indent=2)+'\n')
