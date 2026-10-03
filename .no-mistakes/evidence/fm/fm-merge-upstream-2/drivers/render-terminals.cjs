const {Terminal}=require('./visual-tools/node_modules/@xterm/headless');
const fs=require('fs');
const ev='/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C';
const base=['#000000','#cd3131','#0dbc79','#e5e510','#2472c8','#bc3fbc','#11a8cd','#e5e5e5','#666666','#f14c4c','#23d18b','#f5f543','#3b8eea','#d670d6','#29b8db','#ffffff'];
const esc=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
function pal(n){ if(n<16)return base[n];if(n>=232){let v=8+(n-232)*10;return `rgb(${v},${v},${v})`;}n-=16;let levels=[0,95,135,175,215,255];return `rgb(${levels[Math.floor(n/36)]},${levels[Math.floor(n/6)%6]},${levels[n%6]})`;}
function color(c,bg=false){let mode=bg?'Bg':'Fg';let v=c['get'+mode+'Color']();return c['is'+mode+'RGB']()? '#'+v.toString(16).padStart(6,'0'):c['is'+mode+'Palette']()?pal(v):(bg?'#151718':'#dddddd');}
(async()=>{
for(const file of ['claude-titled','claude-slash','pi-seeded-stall','pi-seeded-approved','pi-unseeded-stall','primary-final']){
  const term=new Terminal({cols:120,rows:40,allowProposedApi:true,scrollback:200});
  let raw=fs.readFileSync(`${ev}/${file}.ansi`,'utf8');
  if(file!=='pi-unseeded-stall')raw=raw.replace(/\r?\n/g,'\r\n');
  await new Promise(resolve=>term.write(raw,resolve));
  let svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1180" height="850" viewBox="0 0 1180 850"><rect width="1180" height="850" fill="#151718"/><g font-family="DejaVu Sans Mono" font-size="16">`;
  let html='<html><meta charset="utf-8"><title>Live terminal: '+file+'</title><body style="margin:0;background:#151718;color:#ddd"><pre style="font:16px/20px monospace;white-space:pre;padding:12px">';
  for(let y=0;y<40;y++){
    const line=term.buffer.active.getLine(term.buffer.active.viewportY+y);if(!line)continue;
    for(let x=0;x<120;x++){
      const c=line.getCell(x);if(!c||c.getWidth()===0)continue;
      const text=c.getChars()||' ';let fg=color(c),bg=color(c,true);if(c.isInverse())[fg,bg]=[bg,fg];
      const xx=12+x*9.6, yy=12+y*20;
      if(bg!=='#151718')svg+=`<rect x="${xx}" y="${yy}" width="${9.6*c.getWidth()}" height="20" fill="${bg}"/>`;
      if(text!==' ')svg+=`<text x="${xx}" y="${yy+16}" fill="${fg}"${c.isBold()?' font-weight="bold"':''}>${esc(text)}</text>`;
      html+=`<span style="color:${fg};background:${bg}${c.isBold()?';font-weight:bold':''}">${esc(text)}</span>`;
    }
    html+='\n';
  }
  svg+='</g></svg>';html+='</pre></body></html>';
  fs.writeFileSync(`${ev}/${file}.svg`,svg);fs.writeFileSync(`${ev}/${file}.html`,html);term.dispose();
}
})();
