#!/usr/bin/env node

/**
 * mac-switcher: Autonomous, cross-platform, single-file CLI to change MAC address
 * Author: BenzoXdev
 * License: MIT
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

// Auto-install missing dependencies
const modules = ['commander','chalk','inquirer','boxen','clipboardy','ora','which'];
(function ensureModules(){
  const missing = modules.filter(m=>{ try{ require.resolve(m); return false;}catch{return true;} });
  if(missing.length){
    console.log(`Installing missing modules: ${missing.join(', ')}`);
    execSync(`npm install ${missing.join(' ')}`,{stdio:'inherit'});
  }
})();

// Imports
const commander = require('commander');
const chalk = require('chalk');
const inquirer = require('inquirer');
const boxen = require('boxen');
const clipboardy = require('clipboardy');
const ora = require('ora');
const which = require('which');

// Constants
const MAC_REGEX = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/;
const isWin = process.platform === 'win32';

// ASCII Art Banner
const BANNER = `
 /$$      /$$  /$$$$$$   /$$$$$$         /$$$$$$  /$$      /$$ /$$$$$$ /$$$$$$$$ /$$$$$$  /$$   /$$ /$$$$$$$$ /$$$$$$$       
| $$$    /$$$ /$$__  $$ /$$__  $$       /$$__  $$| $$  /$ | $$|_  $$_/|__  $$__//$$__  $$| $$  | $$| $$_____/| $$__  $$      
| $$$$  /$$$$| $$  \ $$| $$  \__/      | $$  \__/| $$ /$$$| $$  | $$     | $$  | $$  \__/| $$  | $$| $$      | $$  \ $$      
| $$ $$/$$ $$| $$$$$$$$| $$            |  $$$$$$ | $$/$$ $$ $$  | $$     | $$  | $$      | $$$$$$$$| $$$$$   | $$$$$$$/      
| $$  $$$| $$| $$__  $$| $$             \____  $$| $$$$_  $$$$  | $$     | $$  | $$      | $$__  $$| $$__/   | $$__  $$      
| $$\  $ | $$| $$  | $$| $$    $$       /$$  \ $$| $$$/ \  $$$  | $$     | $$  | $$    $$| $$  | $$| $$      | $$  \ $$      
| $$ \/  | $$| $$  | $$|  $$$$$$/      |  $$$$$$/| $$/   \  $$ /$$$$$$   | $$  |  $$$$$$/| $$  | $$| $$$$$$$$| $$  | $$      
|__/     |__/|__/  |__/ \______/        \______/ |__/     \__/|______/   |__/   \______/ |__/  |__/|________/|__/  |__/      
`;

// Show banner
function showBanner(disable){ if(!disable) console.log(chalk.green(BANNER) + chalk.green.bold('\n    Ultimate MAC Switcher CLI by BenzoXdev\n')); }

// List network interfaces
function listIfaces(){
  const nets = os.networkInterfaces();
  const arr = [];
  Object.entries(nets).forEach(([name,addrs])=>{
    addrs.filter(a=>!a.internal && a.mac && a.family==='IPv4').forEach(a=>{
      arr.push({ name:`${name} | IP:${a.address} | MAC:${a.mac}`, value:{iface:name,oldMac:a.mac} });
    });
  });
  return arr;
}

// Generate random MAC
function randMac(){ return Array.from({length:6},()=>Math.floor(Math.random()*256).toString(16).padStart(2,'0')).join(':'); }

// Execute command with spinner and error handling
function execWithSpinner(cmd, dry){
  const spin = ora({ text: `${dry?'[DRY]':'[RUN]'} ${cmd}`, color: 'cyan' }).start();
  try{ if(!dry) execSync(cmd, { stdio: 'ignore' }); spin.succeed(); }
  catch(err){ spin.fail(); console.error(chalk.red(`[×] Command failed:`), cmd); console.error(err.message); process.exit(1); }
}

// Change MAC on Windows
function changeWin(iface,newMac,dry){
  const stripped = newMac.replace(/:/g,'');
  execWithSpinner(`powershell -Command "Set-NetAdapterAdvancedProperty -Name '${iface}' -RegistryValue '${stripped}' -DisplayName 'Network Address'"`,dry);
  execWithSpinner(`powershell -Command "Disable-NetAdapter -Name '${iface}' -Confirm:$false"`,dry);
  execWithSpinner(`powershell -Command "Enable-NetAdapter -Name '${iface}' -Confirm:$false"`,dry);
}

// Change MAC on Unix
function changeUnix(iface,newMac,dry){
  let tool;
  try{ tool = which.sync('ip'); } catch{ tool = which.sync('ifconfig'); }
  if(tool.endsWith('ip')){
    execWithSpinner(`sudo ip link set dev ${iface} down`,dry);
    execWithSpinner(`sudo ip link set dev ${iface} address ${newMac}`,dry);
    execWithSpinner(`sudo ip link set dev ${iface} up`,dry);
  } else {
    execWithSpinner(`sudo ifconfig ${iface} down`,dry);
    execWithSpinner(`sudo ifconfig ${iface} hw ether ${newMac}`,dry);
    execWithSpinner(`sudo ifconfig ${iface} up`,dry);
  }
}

// Logging
function logChange(iface,oldMac,newMac){
  const logDir = path.join(__dirname,'logs'); if(!fs.existsSync(logDir)) fs.mkdirSync(logDir);
  const entry = `${new Date().toISOString()} | ${iface} | ${oldMac} -> ${newMac}\n`;
  fs.appendFileSync(path.join(logDir,'changes.log'),entry);
}

// Display result
function display(oldMac,newMac,json){
  if(json) console.log(JSON.stringify({oldMac,newMac},null,2));
  else{
    const tbl = `
+--------------+-------------------+
| Previous MAC | New MAC           |
+--------------+-------------------+
| ${oldMac.padEnd(12)} | ${newMac.padEnd(17)} |
+--------------+-------------------+`;
    console.log(boxen(tbl,{ padding:1, borderColor:'green', borderStyle:'round'}));
  }
  try{ clipboardy.writeSync(newMac); console.log(chalk.green('[+] New MAC copied to clipboard')); }
  catch{ /* ignore clipboard errors */ }
}

// Main CLI
const program = new commander.Command();
program
  .name('mac-switcher')
  .description('Autonomous, single-script MAC changer')
  .option('-g, --generate', 'generate random MAC address')
  .option('-j, --json', 'output result as JSON')
  .option('-d, --dry-run', 'simulate without applying changes')
  .option('-n, --no-art', 'hide ASCII art banner')
  .option('-l, --log', 'enable logging of changes')
  .version('2.1.1');
program.parse(process.argv);
const opts = program.opts();

// Privilege check
if(!opts.dryRun && !isWin && process.getuid && process.getuid() !== 0){
  console.error(chalk.red('[×] Please run as root or using sudo')); process.exit(1);
}

(async()=>{
  showBanner(opts.noArt);
  const choices = listIfaces();
  if(!choices.length){ console.error(chalk.red('[×] No network interfaces found')); process.exit(1); }

  const { iface, oldMac } = (await inquirer.prompt([
    { type:'list', name:'iface', message:chalk.yellow('Select interface:'), choices }
  ])).iface;

  let newMac;
  if(opts.generate){ newMac = randMac(); console.log(chalk.green(`[+] Generated MAC: ${newMac}`)); }
  else{
    ({ newMac } = await inquirer.prompt([
      { type:'input', name:'newMac', message:chalk.yellow('Enter new MAC (XX:XX:XX:XX:XX:XX):'),
        validate: v => MAC_REGEX.test(v) || 'Invalid format (e.g. 00:11:22:33:44:55)'
      }
    ]));
  }

  console.log(chalk.green(`[+] Applying change to ${iface}`));
  if(isWin) changeWin(iface,newMac,opts.dryRun);
  else changeUnix(iface,newMac,opts.dryRun);

  if(opts.log && !opts.dryRun) logChange(iface,oldMac,newMac);
  display(oldMac,newMac,opts.json);
})();
