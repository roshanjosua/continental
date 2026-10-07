import { randomBytes, randomUUID } from "node:crypto";
import { execSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { createClient } from "@supabase/supabase-js";

const projectRoot = process.cwd();

function runSupabase(command) {
  return execSync(`npx --yes supabase@2.120.0 ${command}`, {
    cwd: projectRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
    windowsHide: true,
  });
}

function readEnvValue(output, name) {
  const line = output.split(/\r?\n/).find((entry) => entry.startsWith(`${name}=`));
  if (!line) throw new Error(`Local Supabase status did not provide ${name}.`);
  const value = line.slice(name.length + 1).trim();
  return value.startsWith('"') ? JSON.parse(value) : value;
}

function makePassword() {
  return `C0ntinental-${randomBytes(24).toString("base64url")}!`;
}

async function createUser(adminClient, label) {
  const suffix = randomUUID();
  const email = `e2e-${label}-${suffix}@example.test`;
  const password = makePassword();
  const { data, error } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      username: `e2e-${label}-${suffix.slice(0, 8)}`,
      display_name: `E2E ${label}`,
    },
  });

  if (error || !data.user) {
    throw new Error(`Could not provision local ${label} auth user.`);
  }

  return { id: data.user.id, email, password };
}

async function main() {
  runSupabase("db reset --local --yes");
  const status = runSupabase(
    "status -o env --override-name api.url=NEXT_PUBLIC_SUPABASE_URL " +
      "--override-name auth.anon_key=NEXT_PUBLIC_SUPABASE_ANON_KEY " +
      "--override-name auth.service_role_key=E2E_LOCAL_SERVICE_ROLE_KEY",
  );
  const supabaseUrl = readEnvValue(status, "NEXT_PUBLIC_SUPABASE_URL");
  const anonKey = readEnvValue(status, "NEXT_PUBLIC_SUPABASE_ANON_KEY");
  const serviceRoleKey = readEnvValue(status, "E2E_LOCAL_SERVICE_ROLE_KEY");
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  const admin = await createUser(adminClient, "admin");
  const bootstrapSql = resolve(projectRoot, "supabase/.temp/e2e-bootstrap-admin.sql");
  mkdirSync(dirname(bootstrapSql), { recursive: true });
  writeFileSync(
    bootstrapSql,
    `DO $bootstrap$ BEGIN\n` +
      `  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);\n` +
      `  PERFORM private.bootstrap_first_admin('${admin.id}'::uuid);\n` +
      `END $bootstrap$;\n`,
    { mode: 0o600 },
  );
  runSupabase("db query --local --file supabase/.temp/e2e-bootstrap-admin.sql");

  const user = await createUser(adminClient, "user");
  const disabled = await createUser(adminClient, "disabled");
  const { error: disableError } = await adminClient
    .from("profiles")
    .update({ is_active: false })
    .eq("auth_user_id", disabled.id);
  if (disableError) {
    throw new Error("Could not disable the local E2E test profile.");
  }

  const testEnv = [
    `NEXT_PUBLIC_SUPABASE_URL=${supabaseUrl}`,
    `NEXT_PUBLIC_SUPABASE_ANON_KEY=${anonKey}`,
    `E2E_ADMIN_EMAIL=${admin.email}`,
    `E2E_ADMIN_PASSWORD=${admin.password}`,
    `E2E_USER_EMAIL=${user.email}`,
    `E2E_USER_PASSWORD=${user.password}`,
    `E2E_DISABLED_EMAIL=${disabled.email}`,
    `E2E_DISABLED_PASSWORD=${disabled.password}`,
    "",
  ].join("\n");
  writeFileSync(resolve(projectRoot, ".env.test.local"), testEnv, { mode: 0o600 });

  console.log("Local E2E accounts prepared in ignored .env.test.local.");
}

main().catch(() => {
  console.error("Could not prepare local E2E accounts. Confirm the local Supabase stack is running.");
  process.exitCode = 1;
});
