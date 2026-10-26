const { app, BrowserWindow, Menu, session } = require('electron');
const path = require('path');
const fs = require('fs');

// The UI is a single HTML file. It is refreshed from the repository on every
// launch so improvements arrive without reinstalling the app.
const UPDATE_URL =
  'https://raw.githubusercontent.com/hamad191/skills/claude/youthful-goldberg-qzab7o/video-studio/index.html';

const bundled = path.join(__dirname, 'index.html');
const cached = () => path.join(app.getPath('userData'), 'index.html');
const currentPage = () => (fs.existsSync(cached()) ? cached() : bundled);

async function checkForUpdate(win) {
  try {
    const res = await fetch(UPDATE_URL, { signal: AbortSignal.timeout(10000), cache: 'no-store' });
    if (!res.ok) return;
    const html = await res.text();
    if (html.length < 50000 || !html.includes('ستوديو الفيديو')) return;
    const now = fs.readFileSync(currentPage(), 'utf8');
    if (html === now) return;
    fs.writeFileSync(cached(), html);
    if (!win.isDestroyed()) win.loadFile(cached());
  } catch {
    // offline: keep the version we already have
  }
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1000,
    minHeight: 650,
    backgroundColor: '#0e1015',
    title: 'ستوديو الفيديو',
    webPreferences: { contextIsolation: true, sandbox: true, backgroundThrottling: false },
  });
  Menu.setApplicationMenu(null);
  win.loadFile(currentPage());
  win.webContents.once('did-finish-load', () => checkForUpdate(win));
}

app.whenReady().then(() => {
  // allow the microphone (voice recording) only
  session.defaultSession.setPermissionRequestHandler((_wc, permission, cb) => cb(permission === 'media'));
  createWindow();
  app.on('activate', () => BrowserWindow.getAllWindows().length === 0 && createWindow());
});

app.on('window-all-closed', () => process.platform !== 'darwin' && app.quit());
