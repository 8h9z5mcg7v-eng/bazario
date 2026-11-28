import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { runInNewContext } from 'node:vm';

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

  const sqlFiles = Object.fromEntries(expectedMigrations.map(name => [
    name,
    readFileSync(join(migrationsDir, name), 'utf8')
  ]));
  const initialSql = sqlFiles['20261109000000_initial_schema.sql'];
  const storageSql = sqlFiles['20261110000000_product_image_storage.sql'];
  const orderSql = sqlFiles['20261111000000_seller_order_status_workflow.sql'];
  const adminSql = sqlFiles['20261115000000_admin_approval_api.sql'];
  const checkoutSql = sqlFiles['20261115100000_public_checkout_protection.sql'];

  for (const table of ['profiles', 'admin_users', 'stores', 'products', 'orders', 'order_items']) {
    const rlsEnabled = new RegExp('alter\\s+table\\s+public\\.' + table + '\\s+enable\\s+row\\s+level\\s+security', 'i').test(initialSql);
    check(rlsEnabled, table + ': Row Level Security aktivdir');
  }

  const adminGrantLines = initialSql.split('\n').filter(line =>
    line.toLowerCase().includes('grant') && line.toLowerCase().includes('public.admin_users'));
  check(!initialSql.toLowerCase().includes('on public.admin_users for') && adminGrantLines.length === 0,
    'Admin allow-list üçün brauzer rollarına birbaşa cədvəl siyasəti/icazəsi yoxdur');

  function checkSqlContract(sql, fragments, label) {
    const missing = fragments.filter(fragment => !sql.toLowerCase().includes(fragment.toLowerCase()));
    check(missing.length === 0, missing.length
      ? label + ': çatışmayan qaydalar: ' + missing.join(' | ')
      : label + ': təhlükəsizlik qaydaları mövcuddur');
  }

  checkSqlContract(storageSql, [
    "'bazario-products'", '1048576', 'image/jpeg', 'image/png', 'image/webp',
    'for insert', 'for update', 'for delete', 'storage.foldername(storage.objects.name)'
  ], 'Məhsul şəkillərinin Storage məhdudiyyətləri');
  check((storageSql.match(/storage\.foldername\(storage\.objects\.name\)/gi) || []).length === 4,
    'Storage siyasətləri xarici objects.name sütununa açıq istinad edir');

  checkSqlContract(orderSql, [
    'revoke update on public.orders from authenticated',
    'create or replace function public.seller_update_order_status',
    'revoke all on function public.seller_update_order_status(uuid, public.order_status) from public, anon;',
    'security definer', "set search_path = ''",
    'v_owner_id <> auth.uid()', 'invalid order status transition'
  ], 'Satıcı sifariş statusunun qorunan keçidləri');

  checkSqlContract(adminSql, [
    'create or replace function public.admin_review_store',
    'auth.uid() is null or not private.is_admin()',
    "v_current_status <> 'pending'::public.store_status",
    'revoke update on public.stores from authenticated',
    'grant update (name, slug, description) on public.stores to authenticated'
  ], 'Admin təsdiqi və mağaza statusu icazələri');

  checkSqlContract(checkoutSql, [
    'revoke all on function public.create_order(text, text, text, jsonb)',
    'from public, anon, authenticated;',
    'create or replace function public.create_order_protected',
    "set search_path = ''",
    "coalesce(p_honeypot, '') <> ''",
    'regexp_replace(p_buyer_phone',
    'pg_advisory_xact_lock',
    "now() - interval '1 hour'",
    'v_recent_orders >= 3'
  ], 'İctimai sifarişin honeypot, telefon normallaşdırma və limit qoruması');

  const productUi = readFileSync(join(root, 'index.html'), 'utf8');
  check(productUi.includes('data-edit-product=') && productUi.includes('function editBackendProduct(')
    && productUi.includes('function saveBackendProduct()') && productUi.includes('image_path:imagePath'),
    'Satıcı panelində məhsul redaktəsi mövcuddur');

  const authFrontend = readFileSync(join(root, 'index.html'), 'utf8');
  check(authFrontend.includes('id="forgotPasswordBtn"')
    && authFrontend.includes('resetPasswordForEmail')
    && authFrontend.includes("event==='PASSWORD_RECOVERY'")
    && authFrontend.includes('auth.updateUser({password})'),
    'Satıcı şifəsinin e-poçtla bərpası və yeni şifrə təyin etmə axını mövcuddur');

  const shareUi = readFileSync(join(root, 'index.html'), 'utf8');
  check(shareUi.includes('id="shareStoreLink"')
    && shareUi.includes("navigator.share")
    && shareUi.includes('async function shareStoreShareUrl')
    && shareUi.includes("$('#shareStoreLink').onclick")
    && shareUi.includes('await copyStoreShareUrl(url)'),
    'iPhone mağaza linki native paylaşım pəncərəsini və kopyalama ehtiyat yolunu dəstəkləyir');

  const shareStart = productUi.indexOf('function storeShareUrl(slug){');
  const shareEnd = productUi.indexOf('async function refreshBackendData(){', shareStart);
  check(shareStart >= 0 && shareEnd > shareStart,
    'Mağaza paylaşım funksiyaları ayrıca davranış sınağı üçün tapıldı');
  if (shareStart >= 0 && shareEnd > shareStart) {
    const shareSource = productUi.slice(shareStart, shareEnd);
    function shareHarness({ nativeShare = false, clipboard = false, secure = true, shareError = null, clipboardError = null } = {}) {
      const events = { shares: [], copies: [], prompts: [], alerts: [] };
      const context = {
        URL,
        data: { shop: 'Sınaq mağazası' },
        window: {
          location: { href: 'https://bazario.example/?campaign=summer#top' },
          isSecureContext: secure,
          prompt: (message, value) => events.prompts.push({ message, value })
        },
        navigator: {},
        alert: message => events.alerts.push(message)
      };
      if (nativeShare) {
        context.navigator.share = async payload => {
          events.shares.push(payload);
          if (shareError) throw shareError;
        };
      }
      if (clipboard) {
        context.navigator.clipboard = {
          writeText: async value => {
            events.copies.push(value);
            if (clipboardError) throw clipboardError;
          }
        };
      }
      runInNewContext(shareSource, context);
      return { context, events };
    }
    async function runShareCase(name, action) {
      try {
        await action();
        check(true, name);
      } catch (error) {
        check(false, name + ': ' + error.message);
      }
    }

    await runShareCase('Mağaza linki mövcud query parametrini saxlayır, shop parametrini əlavə edir və hash-i silir', async () => {
      const harness = shareHarness();
      const url = new URL(harness.context.storeShareUrl('test-store'));
      if (url.searchParams.get('shop') !== 'test-store'
        || url.searchParams.get('campaign') !== 'summer'
        || url.hash !== '') throw new Error('URL gözlənilən formada qurulmadı');
    });

    await runShareCase('iPhone native paylaşımı düzgün başlıq, mətn və linklə çağırılır', async () => {
      const harness = shareHarness({ nativeShare: true, clipboard: true });
      const url = 'https://bazario.example/?shop=test-store';
      await harness.context.shareStoreShareUrl(url);
      const payload = harness.events.shares[0];
      if (harness.events.shares.length !== 1 || payload?.url !== url
        || payload?.title !== 'Sınaq mağazası — BAZARIO'
        || payload?.text !== 'Mağazama bax:' || harness.events.copies.length !== 0) {
        throw new Error('Native paylaşım payload-u və ya çağırış sayı yanlışdır');
      }
    });

    await runShareCase('İstifadəçi native paylaşımı ləğv etdikdə ehtiyat kopyalama açılmır', async () => {
      const abort = new Error('İstifadəçi paylaşımı bağladı');
      abort.name = 'AbortError';
      const harness = shareHarness({ nativeShare: true, clipboard: true, shareError: abort });
      await harness.context.shareStoreShareUrl('https://bazario.example/?shop=test-store');
      if (harness.events.copies.length || harness.events.prompts.length) {
        throw new Error('Ləğv edilmiş paylaşım kopyalama pəncərəsi açdı');
      }
    });

    await runShareCase('Native paylaşım olmadıqda təhlükəsiz clipboard kopyalaması işləyir', async () => {
      const harness = shareHarness({ clipboard: true, secure: true });
      const url = 'https://bazario.example/?shop=test-store';
      await harness.context.shareStoreShareUrl(url);
      if (harness.events.copies[0] !== url
        || harness.events.alerts.length !== 1 || harness.events.prompts.length) {
        throw new Error('Clipboard ehtiyat yolu işləmədi');
      }
    });

    await runShareCase('Native paylaşım xətası clipboard ehtiyat yoluna keçir', async () => {
      const harness = shareHarness({
        nativeShare: true, clipboard: true, shareError: new Error('Share unavailable')
      });
      const url = 'https://bazario.example/?shop=test-store';
      await harness.context.shareStoreShareUrl(url);
      if (harness.events.shares.length !== 1 || harness.events.copies[0] !== url) {
        throw new Error('Native paylaşım xətasından sonra kopyalama baş vermədi');
      }
    });

    await runShareCase('HTTPS olmayan kontekstdə link prompt vasitəsilə təqdim olunur', async () => {
      const harness = shareHarness({ clipboard: true, secure: false });
      const url = 'http://localhost/?shop=test-store';
      await harness.context.copyStoreShareUrl(url);
      if (harness.events.prompts.length !== 1
        || harness.events.prompts[0].value !== url || harness.events.copies.length) {
        throw new Error('Təhlükəsiz olmayan kontekst üçün prompt ehtiyat yolu işləmədi');
      }
    });

    await runShareCase('Clipboard xətası linki prompt ilə əl ilə kopyalamağa imkan verir', async () => {
      const harness = shareHarness({
        clipboard: true, secure: true, clipboardError: new Error('Clipboard blocked')
      });
      const url = 'https://bazario.example/?shop=test-store';
      await harness.context.copyStoreShareUrl(url);
      if (harness.events.prompts.length !== 1
        || harness.events.prompts[0].value !== url) {
        throw new Error('Clipboard xətasından sonra prompt açılmadı');
      }
    });
  }

  const storeSettingsUi = readFileSync(join(root, 'index.html'), 'utf8');
  check(storeSettingsUi.includes('data-tab="settings"')
    && storeSettingsUi.includes('id="storeSettingsForm"')
    && storeSettingsUi.includes('async function saveBackendStoreSettings')
    && storeSettingsUi.includes(".eq('id',data.storeId).eq('owner_id',currentUser.id)")
    && storeSettingsUi.includes("normalizeSlug($('#settingsStoreSlug').value)"),
    'Satıcı mağaza adını, unikal ünvanını və təsvirini təhlükəsiz yeniləyə bilir');

  const adminUi = readFileSync(join(root, 'admin.html'), 'utf8');
  const adminRoleCheck = adminUi.indexOf("client.rpc('current_user_is_admin')");
  const adminPanelReveal = adminUi.indexOf("$('#adminPanel').classList.remove('hidden')");
  check(adminRoleCheck >= 0 && adminPanelReveal > adminRoleCheck
    && adminUi.includes("client.rpc('admin_review_store'")
    && adminUi.includes("await client.auth.signOut()")
    && !adminUi.includes(".from('stores').update("),
    'Admin paneli rolu serverdə yoxlayır, qərarı qorunan RPC ilə verir və birbaşa status yazmır');

  const adminEscapedFields = [
    'escapeHtml(store.name)',
    'escapeHtml(store.slug)',
    'escapeHtml(store.description||',
    'escapeHtml(store.owner_id)',
    'escapeHtml(date)'
  ];
  check(adminEscapedFields.every(fragment => adminUi.includes(fragment)),
    'Admin müraciətlərində mağaza adı, ünvan, təsvir, satıcı ID-si və tarix HTML kimi escape edilir');

  const escapeHtmlSource = adminUi.match(/function escapeHtml\\(value\\)\\s*\\{[\\s\\S]*?\\n\\}/)?.[0];
  if (escapeHtmlSource) {
    const hostileAdminText = '<img src=x onerror="alert(1)"> & \'store\'';
    const escapedAdminText = runInNewContext(
      escapeHtmlSource + '\\nescapeHtml(' + JSON.stringify(hostileAdminText) + ')'
    );
    check(escapedAdminText === '&lt;img src=x onerror=&quot;alert(1)&quot;&gt; &amp; &#39;store&#39;',
      'Admin HTML escape funksiyası XSS payload-unu mətnə çevirir');
  } else {
    check(false, 'Admin HTML escape funksiyası sınaq üçün tapıldı');
  }

  const publicFiles = ['index.html', 'admin.html', 'supabase/config.js'];
  for (const file of publicFiles) {
    const source = readFileSync(join(root, file), 'utf8');
    const exposesServiceRole = /(?:service_role|SUPABASE_SERVICE_ROLE_KEY)\s*[:=]\s*["']/i.test(source);
    check(!exposesServiceRole, file + ': service_role açarı brauzer faylında yoxdur');
  }

  const readme = readFileSync(join(root, 'supabase', 'README.md'), 'utf8');
  check(readme.includes('create_order_protected')
    && readme.includes('not full CAPTCHA or IP-based throttling')
    && !readme.includes('Customer checkout is intentionally not exposed yet'),
    'README checkout status matches the implemented protected draft flow');

  const postgresFixture = readFileSync(join(root, 'tests', 'postgres', 'supabase_stub.sql'), 'utf8');
  const postgresSmoke = readFileSync(join(root, 'tests', 'postgres', 'smoke.sql'), 'utf8');
  const workflow = readFileSync(join(root, '.github', 'workflows', 'validate.yml'), 'utf8');
  check(postgresFixture.includes('create role anon') && postgresFixture.includes('create role authenticated')
    && postgresFixture.includes('auth.uid()') && postgresFixture.includes('storage.foldername'),
    'PostgreSQL CI fixture supplies Supabase Auth, roles and Storage compatibility');
  check(postgresSmoke.includes('public.create_order_protected')
    && postgresSmoke.includes('public.seller_update_order_status')
    && postgresSmoke.includes('public.admin_review_store')
    && postgresSmoke.includes('storage.objects')
    && postgresSmoke.includes('another seller'),
    'PostgreSQL smoke tests cover checkout, tenant isolation, order workflow, admin and Storage');
  check(workflow.includes('image: postgres:16')
    && workflow.includes('tests/postgres/supabase_stub.sql')
    && workflow.includes('supabase/verify_installation.sql')
    && workflow.includes('tests/postgres/smoke.sql'),
    'GitHub Actions runs real PostgreSQL migrations and integration smoke tests');
} catch (error) {
  errors.push('Yoxlama icra edilərkən xəta: ' + error.message);
} finally {
  rmSync(tempDir, { recursive: true, force: true });
}

for (const item of report) console.log('PASS  ' + item);
for (const item of errors) console.error('FAIL  ' + item);
console.log('Nəticə: ' + report.length + ' uğurlu, ' + errors.length + ' uğursuz yoxlama.');
if (errors.length) process.exitCode = 1;
