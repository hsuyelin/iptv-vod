// pm2 start deploy/pm2/ecosystem.config.cjs   (after scripts/build.sh)
const path = require('node:path');

const root = path.resolve(__dirname, '..', '..');

module.exports = {
  apps: [
    {
      name: 'iptv-rs',
      cwd: root,
      script: path.join(root, 'dist', 'bin', 'iptv-rs'),
      interpreter: 'none',
      args: [
        '--host', process.env.HOST || '127.0.0.1',
        '--port', process.env.PORT || '8787',
        '--channels', process.env.CHANNELS || path.join(root, 'channels.yaml'),
        '--assets-dir', path.join(root, 'dist', 'assets'),
        // Drop the next line when nginx serves the console.
        '--web-dir', path.join(root, 'dist', 'web'),
      ],
      autorestart: true,
      max_restarts: 20,
      restart_delay: 2000,
      time: true,
    },
  ],
};
