// Loads templates/<slug>/v<N>.json from the repo root into the database.
//
//   npm run templates:seed
//
// Idempotent: unchanged files are skipped. A (slug, version) that already exists with DIFFERENT
// content is refused, because surprises were built (and published snapshots frozen) on that
// version. To change a template, add v<N+1>.json instead. Use --force only in local development.
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { PrismaClient } = require('@prisma/client');

const TEMPLATES_DIR = path.resolve(__dirname, '../../../templates');
const force = process.argv.includes('--force');

/** Key-order-independent JSON, because Postgres jsonb does not preserve key order. */
const canon = (v) =>
  JSON.stringify(v, (_k, val) =>
    val && typeof val === 'object' && !Array.isArray(val)
      ? Object.fromEntries(Object.entries(val).sort(([a], [b]) => a.localeCompare(b)))
      : val,
  );

function loadFiles() {
  const files = [];
  for (const dir of fs.readdirSync(TEMPLATES_DIR, { withFileTypes: true })) {
    if (!dir.isDirectory()) continue;
    for (const f of fs.readdirSync(path.join(TEMPLATES_DIR, dir.name))) {
      if (!/^v\d+\.json$/.test(f)) continue;
      const file = path.join(TEMPLATES_DIR, dir.name, f);
      const t = JSON.parse(fs.readFileSync(file, 'utf8'));
      const version = Number(f.slice(1, -5));
      const problems = [];
      if (t.slug !== dir.name) problems.push(`slug "${t.slug}" must match its folder "${dir.name}"`);
      if (t.version !== version) problems.push(`version ${t.version} must match its file name (v${version})`);
      for (const k of ['name', 'occasion']) if (typeof t[k] !== 'string' || !t[k]) problems.push(`${k} is required`);
      if (typeof t.configuration !== 'object' || !t.configuration) problems.push('configuration is required');
      if (problems.length) throw new Error(`${path.relative(TEMPLATES_DIR, file)}: ${problems.join('; ')}`);
      files.push(t);
    }
  }
  return files;
}

async function main() {
  const prisma = new PrismaClient();
  let created = 0, unchanged = 0, updated = 0;
  const conflicts = [];
  try {
    for (const t of loadFiles()) {
      const key = { slug: t.slug, version: t.version };
      const existing = await prisma.template.findUnique({ where: { slug_version: key } });
      const data = { name: t.name, occasion: t.occasion, configuration: t.configuration };
      if (!existing) {
        await prisma.template.create({ data: { ...key, ...data } });
        created++;
        console.log(`created    ${t.slug} v${t.version}`);
      } else if (
        existing.name === t.name &&
        existing.occasion === t.occasion &&
        canon(existing.configuration) === canon(t.configuration)
      ) {
        unchanged++;
        console.log(`unchanged  ${t.slug} v${t.version}`);
      } else if (force) {
        await prisma.template.update({ where: { id: existing.id }, data });
        updated++;
        console.log(`UPDATED    ${t.slug} v${t.version} (--force)`);
      } else {
        conflicts.push(`${t.slug} v${t.version}`);
        console.error(`CONFLICT   ${t.slug} v${t.version} exists with different content. Add v${t.version + 1}.json instead.`);
      }
    }
  } finally {
    await prisma.$disconnect();
  }
  console.log(`\n${created} created, ${unchanged} unchanged, ${updated} updated, ${conflicts.length} conflicts`);
  if (conflicts.length) process.exit(1);
}

main().catch((e) => {
  console.error('template seed failed:', e.message);
  process.exit(1);
});
