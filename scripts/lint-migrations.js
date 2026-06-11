const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const migrationsDir = path.join(repoRoot, "supabase", "migrations");

function listSqlFiles(dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.toLowerCase().endsWith(".sql"))
    .map((e) => path.join(dir, e.name));
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

if (!fs.existsSync(migrationsDir)) {
  fail(`Missing migrations directory: ${migrationsDir}`);
}

const files = listSqlFiles(migrationsDir);
if (!files.length) {
  fail("No SQL migrations found.");
}

const bannedPatterns = [
  /NEXT_PUBLIC_SUPABASE_URL/i,
  /NEXT_PUBLIC_SUPABASE_ANON_KEY/i,
  /SUPABASE_SERVICE_ROLE_KEY/i,
  /SUPABASE_URL=/i,
  /ANON_KEY=/i
];

for (const file of files) {
  const content = fs.readFileSync(file, "utf8");
  for (const p of bannedPatterns) {
    if (p.test(content)) {
      fail(`Banned env-like content found in migration: ${path.relative(repoRoot, file)}`);
    }
  }
  const trimmed = content.trim();
  if (!trimmed) {
    fail(`Empty migration file: ${path.relative(repoRoot, file)}`);
  }
}

process.stdout.write(`OK: ${files.length} migrations checked\n`);

