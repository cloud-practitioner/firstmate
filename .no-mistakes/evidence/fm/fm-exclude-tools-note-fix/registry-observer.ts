import { appendFileSync } from 'node:fs';
export default function(pi: any) {
  const record = (event: string) => appendFileSync(process.env.LAB_ROOT + '/registry.jsonl', JSON.stringify({event, tools: pi.getAllTools().map((t: any) => t.name)}) + '\n');
  pi.on('agent_start', () => record('agent_start'));
  pi.on('turn_end', () => record('turn_end'));
  pi.on('agent_settled', () => record('agent_settled'));
}
