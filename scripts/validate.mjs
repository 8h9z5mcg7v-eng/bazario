import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = process.cwd();
const errors = [];
const report = [];
const tempDir = mkdtempSync(join(tmpdir(), 'bazario-check-'));

function check(condition, message) {
  if (!condition) errors.push(message);
  else report.push(message);
}

try {
  for (const file of ['index.html', 'admin.html']) {
    const html = readFileSync(join(root, file), 'utf8');
    const staticHtml = html.split(/<script\b/i, 1)[0];
    const ids = [...staticHtml.matchAll(/\bid=["']([^"']+)["']/gi)].map(match => match[1]);
    const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index);
    check(duplicateIds.length === 0, duplicateIds.length
      ? file + ': təkrarlanan id: ' + [...new Set(duplicateIds)].join(', ')
      : file + ': id-lər təkrarsızdır');

    const idSet = new Set(ids);
    const labelTargets = [...staticHtml.matchAll(/<label\b[^>]*\bfor=["']([^"']+)["'][^>]*>/gi)].map(match => match[1]);
    const missingLabels = [...new Set(labelTargets.filter(id => !idSet.has(id)))];
    check(missingLabels.length === 0, missingLabels.length
      ? file + ': mövcud olmayan label hədəfi: ' + missingLabels.join(', ')
      : file + ': label bağlantıları düzgündür');

    const blocks = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
      .filter(match => !/\bsrc\s*=/i.test(match[1]));
    check(blocks.length > 0, file + ': daxili JavaScript tapıldı');
    for (let i = 0; i < blocks.length; i++) {
      const tempFile = join(tempDir, file.replace(/[^a-z0-9]/gi, '_') + '-' + i + '.js');
      writeFileSync(tempFile, blocks[i][2], 'utf8');
      const result = spawnSync(process.execPath, ['--check', tempFile], { encoding: 'utf8' });
      check(result.status === 0, result.status === 0
        ? file + ': daxili JavaScript #' + (i + 1) + ' sintaksis yoxlamasından keçdi'
        : file + ': JavaScript sintaksis xətası: ' + (result.stderr || result.stdout).trim());
    }
  }

  const migrationsDir = join(root, 'supabase', 'migrations');
  const actualMigrations = readdirSync(migrationsDir).filter(name => name.endsWith('.sql')).sort();
  const expectedMigrations = [
    '20261109000000_initial_schema.sql',
    '20261110000000_product_image_storage.sql',
    '20261111000000_seller_order_status_workflow.sql',
    '20261115000000_admin_approval_api.sql',
    '20261115100000_public_checkout_protection.sql'
  ];
  check(JSON.stringify(actualMigrations) === JSON.stringify(expectedMigrations),
    'SQL miqrasiyaları: ' + actualMigrations.length + '/5 gözlənilən fayl mövcuddur və ardıcıllıq düzgündür');

  for (const migration of actualMigrations) {
    const sql = readFileSync(join(migrationsDir, migration), 'utf8');
    // Strip standalone SQL comments so trailing comments remain allowed, but
    // executable tokens after COMMIT are rejected.
    const executableSql = sql.replace(/^\s*--.*$/gm, '').replace(/\/\*[\s\S]*?\*\//g, '').trim();
    const commitStatements = [...executableSql.matchAll(/\bcommit\s*;/gi)];
    check(/^begin\s*;[\s\S]*commit\s*;\s*$/i.test(executableSql) && commitStatements.length === 1,
      migration + ': vahid BEGIN/COMMIT transactiondır və COMMIT-dən sonra SQL yoxdur');
  }

  const publicFiles = ['index.html', 'admin.html', 'supabase/config.js'];
  for (const file of publicFiles) {
    const source = readFileSync(join(root, file), 'utf8');
    const exposesServiceRole = /(?:service_role|SUPABASE_SERVICE_ROLE_KEY)\s*[:=]\s*["']/i.test(source);
    check(!exposesServiceRole, file + ': service_role açarı brauzer faylında yoxdur');
  }
} catch (error) {
  errors.push('Yoxlama icra edilərkən xəta: ' + error.message);
} finally {
  rmSync(tempDir, { recursive: true, force: true });
}

for (const item of report) console.log('PASS  ' + item);
for (const item of errors) console.error('FAIL  ' + item);
console.log('Nəticə: ' + report.length + ' uğurlu, ' + errors.length + ' uğursuz yoxlama.');
if (errors.length) process.exitCode = 1;
