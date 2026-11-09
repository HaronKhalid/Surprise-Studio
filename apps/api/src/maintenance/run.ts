import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { MaintenanceModule } from './maintenance.module';
import { MaintenanceService } from './maintenance.service';

/** Entry point for schedulers: `npm run maintenance` (or `node dist/maintenance/run.js`). */
async function main() {
  const app = await NestFactory.createApplicationContext(MaintenanceModule);
  try {
    const report = await app.get(MaintenanceService).run();
    console.log(JSON.stringify({ ok: true, ...report }));
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error(JSON.stringify({ ok: false, error: err instanceof Error ? err.message : String(err) }));
  process.exit(1);
});
