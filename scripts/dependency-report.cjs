const { spawnSync } = require('node:child_process');
const a = spawnSync('npm', ['audit', '--json'], { encoding: 'utf8' });
const report = JSON.parse(a.stdout);
for (const [name, v] of Object.entries(report.vulnerabilities || {}))
  console.log(
    JSON.stringify({
      name,
      severity: v.severity,
      range: v.range,
      fix: v.fixAvailable,
      advisories: v.via
        .filter((x) => typeof x === 'object')
        .map((x) => ({ name: x.name, range: x.range, url: x.url })),
    }),
  );
for (const name of [
  '@nestjs/common',
  '@nestjs/swagger',
  'bullmq',
  'vite',
  '@vitejs/plugin-react',
  'react',
  'react-dom',
  'effect',
  'deepmerge-ts',
  'express',
]) {
  const p = spawnSync('npm', ['view', name, 'version'], { encoding: 'utf8' });
  console.log(name + ' latest ' + p.stdout.trim());
}
