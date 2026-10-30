const {Server} = require('./ssh/node_modules/ssh2');
const fs = require('fs');
const {spawn} = require('child_process');
const dir = process.argv[2];
const children = new Set();
const server = new Server({hostKeys:[fs.readFileSync(dir+'/host-key')]}, client => {
 client.on('authentication',ctx=>ctx.accept());
 client.on('ready',()=>client.on('session',accept=>{
  const session=accept();
  session.on('exec',(accept,reject,info)=>{
   const stream=accept();
   if(fs.existsSync(dir+'/transport-failure')) {
    stream.write('A\x00 connection attempt failed\x00 Error code: Bash/Service/WSAETIMEDOUT\n');
    stream.exit(255); stream.end(); return;
   }
   if(fs.existsSync(dir+'/invalid-success')) {
    stream.write('transport diagnostic, not a delta\n'); stream.exit(0);stream.end();return;
   }
   const child=spawn('/bin/bash',['-c',info.command],{cwd:dir,env:{...process.env,
    PATH:dir+'/remote-root/bin:'+process.env.PATH,
    TMPDIR:dir+'/tmp',HOME:dir+'/user',
    FM_REMOTE_JOB_STATE_ROOT:dir+'/jobs',FM_REMOTE_JOB_PLATFORM_OVERRIDE:'Linux',
    GIT_CONFIG_GLOBAL:dir+'/gitconfig',GIT_CONFIG_NOSYSTEM:'1'}});
   children.add(child);stream.on('data',d=>child.stdin.write(d));stream.on('end',()=>child.stdin.end());
   child.stdout.on('data',d=>stream.write(d));child.stderr.on('data',d=>stream.stderr.write(d));
   child.on('close',(code,signal)=>{children.delete(child);stream.exit(code??128);stream.end();});
  });
 }));
 client.on('error',()=>{});
});
server.listen(0,'127.0.0.1',()=>fs.writeFileSync(dir+'/port',String(server.address().port)));
process.on('SIGTERM',()=>{for(const child of children)child.kill();server.close();process.exit(0);});
