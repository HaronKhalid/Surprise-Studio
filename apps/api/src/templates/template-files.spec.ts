import * as fs from 'fs';
import * as path from 'path';
import { validateTemplateConfig } from './template-config';

// Guards the files that scripts/seed-templates.js loads: a bad template should fail CI, not production.
const TEMPLATES_DIR = path.resolve(__dirname, '../../../../templates');

const files = fs
  .readdirSync(TEMPLATES_DIR, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .flatMap((d) =>
    fs
      .readdirSync(path.join(TEMPLATES_DIR, d.name))
      .filter((f) => /^v\d+\.json$/.test(f))
      .map((f) => ({ folder: d.name, file: f, json: JSON.parse(fs.readFileSync(path.join(TEMPLATES_DIR, d.name, f), 'utf8')) })),
  );

describe('template definition files', () => {
  it('ships the four launch templates', () => {
    expect(files.map((f) => f.json.slug).sort()).toEqual(['cinematic', 'cute', 'luxury', 'memories']);
  });

  it('has unique (slug, version) pairs and unique display orders', () => {
    const pairs = files.map((f) => `${f.json.slug}@${f.json.version}`);
    expect(new Set(pairs).size).toBe(pairs.length);
    const orders = files.map((f) => f.json.configuration.displayOrder);
    expect(new Set(orders).size).toBe(orders.length);
  });

  describe.each(files.map((f) => [`${f.folder}/${f.file}`, f] as const))('%s', (_name, f) => {
    it('has a slug and version matching its path', () => {
      expect(f.json.slug).toBe(f.folder);
      expect(f.json.version).toBe(Number(f.file.slice(1, -5)));
    });

    it('has a name and occasion', () => {
      expect(typeof f.json.name).toBe('string');
      expect(f.json.name.length).toBeGreaterThan(0);
      expect(typeof f.json.occasion).toBe('string');
    });

    it('has a valid, readable configuration', () => {
      expect(validateTemplateConfig(f.json.configuration)).toEqual([]);
    });
  });
});
