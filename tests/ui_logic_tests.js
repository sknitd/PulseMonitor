'use strict';
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
let passed=0;
function check(name,condition){assert.ok(condition,name);passed++;process.stdout.write(`PASS ${name}\n`);}

const app={innerHTML:''},toast={textContent:'',classList:{add(){},remove(){}}};
const document={
  activeElement:null,scrollY:0,
  documentElement:{theme:null,removeAttribute(){this.theme=null;},setAttribute(k,v){if(k==='data-theme')this.theme=v;}},
  querySelector(s){return s==='#app'?app:s==='#toast'?toast:null;},
  getElementById(){return null;},addEventListener(){},createElement(){return {};}
};
const window={scrollY:0,scrollTo(){}};
const context={window,document,location:{search:''},URLSearchParams,console,setTimeout,clearTimeout};
vm.runInNewContext(fs.readFileSync('ui/app.js','utf8'),context,{filename:'ui/app.js'});
const t=window.PulseTesting;
check('Byte conversion scales 1024 bytes as 1 KiB',t.byteText(1024)==='1 KiB');
check('Byte formatting keeps zero distinct from unavailable',t.byteText(0)==='0 B'&&t.byteText(null)==='—');
check('Decimal rate formatting appends bytes per second',t.rateText(1500)==='1.5 KB/s');
check('Percent formatting preserves zero and null',t.pct(0)==='0.0%'&&t.pct(null)==='—');
check('Duration formatter handles hours and negative input',t.duration(3661)==='1h 1m'&&t.duration(-5)==='0s');
check('HTML escaping leaves untrusted names inert',t.esc('<img src=x onerror=alert(1)>')==='&lt;img src=x onerror=alert(1)&gt;');

const unavailable={
  timestamp:1790210100,uptime:1234,model:'Test Mac',chip:'Test CPU',appCount:0,processCount:0,thermal:'Fair',
  cpu:{available:false,usage:null,user:null,system:null,idle:null,cores:8,load1:null,load5:null,load15:null},
  memory:{available:false,total:null,used:null,app:null,wired:null,compressed:null,cached:null,free:null,physicalFree:null,swap:null,pressure:'Not reported'},
  disk:{available:false,total:null,free:null,used:null,read:null,write:null,volume:'/tmp'},
  network:{available:false,download:null,upload:null,received:0,sent:0,interfaces:[]},
  gpu:{available:false,usage:null,name:'Apple GPU',deviceAvailable:true,unified:true},
  battery:{available:false,percent:null,charging:false,pluggedIn:false,minutes:null,cycles:null,health:null},
  apps:[],projects:[{pid:234,name:'Fixture server',runtime:'python3',elapsed:'00:03:00',cwd:'',ports:[8123],cpu:0,memory:0,lowSeconds:0}]
};
window.Pulse.receive({snapshot:unavailable,history:[{t:1790210100,cpu:12,memory:null,network:null,gpu:null,battery:null,disk:null}],settings:{interval:2,theme:'system',alerts:false,cpuThreshold:80,cpuDuration:60,growthMB:512,hideDock:false,launchAtLogin:false},alerts:[],paused:false,icons:{}});
window.Pulse.navigate('overview');
check('Unavailable CPU load renders an em dash without throwing',app.innerHTML.includes('Load average')&&app.innerHTML.includes('—'));
window.Pulse.navigate('cpu');
check('CPU chart has a metric-specific accessible name',app.innerHTML.includes('aria-label="CPU history"'));
window.Pulse.navigate('gpu');
check('GPU utilization stays unavailable without driver metrics',app.innerHTML.includes('SYSTEM-WIDE UTILIZATION')&&app.innerHTML.includes('System-wide utilization is unavailable')&&!app.innerHTML.includes('IOKit'));
window.Pulse.navigate('disk');
check('Unavailable disk capacity does not become 0 percent or NaN',app.innerHTML.includes('Storage data is unavailable')&&!app.innerHTML.includes('0.0%')&&!app.innerHTML.includes('NaN'));
window.Pulse.navigate('projects');
check('Missing project working directory is stated explicitly',app.innerHTML.includes('Working directory unavailable')&&!app.innerHTML.includes('data-reveal="234"'));
check('Project controls have meaningful accessible names',app.innerHTML.includes('aria-label="Open port 8123 in your browser"')&&app.innerHTML.includes('aria-label="Review and stop Fixture server"'));
console.log(`UI logic tests: ${passed} passed, 0 failed`);
