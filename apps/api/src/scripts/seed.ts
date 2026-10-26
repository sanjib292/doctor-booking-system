/**
 * Seed demo data (doctors, clinics, categories, availability).
 * CLI only — never exposed over HTTP.
 *
 * Usage:
 *   ALLOW_SEED=true SEED_ADMIN_PASSWORD=... SEED_DOCTOR_PASSWORD=... npx tsx src/scripts/seed.ts
 */
import { connectDatabase, disconnectDatabase } from '../config/database';
import { AuthService } from '../auth/auth.service';

async function main() {
  if (process.env.ALLOW_SEED !== 'true') {
    console.error('[seed] Refusing to run: set ALLOW_SEED=true to enable seeding.');
    process.exit(1);
  }

  await connectDatabase();
  const result = await new AuthService().seedDemoData();
  console.log('[seed] ✅ Demo data seeded:', JSON.stringify(result, null, 2));
  await disconnectDatabase();
}

main().catch((err) => {
  console.error('[seed] FATAL:', err);
  process.exit(1);
});
