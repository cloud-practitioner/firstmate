import { appendFileSync, writeFileSync } from 'node:fs';
export default function(pi) {
  const log = (type, data) => appendFileSync(`${process.env.FM_HOME}/observed.jsonl`, JSON.stringify({at:Date.now(), type, ...data})+'\n');
  pi.on('session_start', () => {
    writeFileSync(`${process.env.FM_HOME}/state/.lock`, `${process.pid}\n`);
    log('session_start', {pid:process.pid});
  });
  pi.on('message_start', (e) => {if (e.message.role === 'user') log('user', {content:e.message.content});});
  pi.on('agent_start', () => log('agent_start', {}));
  pi.on('agent_end', () => log('agent_end', {}));
  pi.on('session_shutdown', (e) => log('session_shutdown', {reason:e.reason}));
}
