import { appendFileSync, existsSync } from 'node:fs';
export default function (pi: any) {
  let turns = 0;
  let started = false;
  const record = (event: string) => appendFileSync(process.env.LIVE_OBSERVATIONS!, JSON.stringify({event, turns, names:pi.getAllTools().map((t:any)=>t.name)})+'\n');
  pi.on('before_agent_start', async () => {
    if (process.env.LIVE_READY === '1' || (process.env.LIVE_SECOND_START === '1' && started)) {
      for (let i=0; i<500; i++) {
        if (pi.getAllTools().some((t:any)=>t.name==='mcp__lab_tracker__readIssue')) break;
        await new Promise(r=>setTimeout(r,10));
      }
    }
  });
  pi.on('agent_start', () => { record('agent_start'); started = true; });
  pi.on('turn_end', () => { turns++; record('turn_end'); });
  pi.on('agent_settled', () => record('agent_settled'));
}
