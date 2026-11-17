  // MongoDB initialization script for Nebron
// Idempotent: safe to run multiple times.

// 1. Initialize nebron_auth
const authDb = db.getSiblingDB('nebron_auth');

// Create dedicated user for auth if not exists
try {
  authDb.createUser({
    user: 'nebron_auth_user',
    pwd: 'auth_password_dev',
    roles: [{ role: 'readWrite', db: 'nebron_auth' }]
  });
  print('[init-mongo] Created user nebron_auth_user');
} catch (e) {
  if (e.code === 51003 || (e.message && e.message.includes('already exists'))) {
    print('[init-mongo] User nebron_auth_user already exists');
  } else {
    print('[init-mongo] Notice on createUser nebron_auth_user: ' + e.message);
  }
}

// Create unique index on users.email
authDb.users.createIndex({ email: 1 }, { unique: true, background: true });

// Create sessions indexes as per auth-service spec
authDb.sessions.createIndex({ refreshTokenHash: 1 }, { unique: true, background: true });
authDb.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, background: true });
authDb.sessions.createIndex({ userId: 1 }, { background: true });
authDb.sessions.createIndex({ familyId: 1 }, { background: true });
print('[init-mongo] Indexes created for nebron_auth');

// 2. Initialize nebron_core
const coreDb = db.getSiblingDB('nebron_core');

// Create dedicated user for core if not exists
try {
  coreDb.createUser({
    user: 'nebron_core_user',
    pwd: 'core_password_dev',
    roles: [{ role: 'readWrite', db: 'nebron_core' }]
  });
  print('[init-mongo] Created user nebron_core_user');
} catch (e) {
  if (e.code === 51003 || (e.message && e.message.includes('already exists'))) {
    print('[init-mongo] User nebron_core_user already exists');
  } else {
    print('[init-mongo] Notice on createUser nebron_core_user: ' + e.message);
  }
}

// Create unique indexes on profiles.userId and profiles.username
coreDb.profiles.createIndex({ userId: 1 }, { unique: true, background: true, name: 'idx_profiles_userId_unique' });
coreDb.profiles.createIndex({ username: 1 }, { unique: true, background: true, name: 'idx_profiles_username_unique' });
print('[init-mongo] Indexes created for nebron_core');

// 3. Create role 'nebron' in admin with readWrite on both, dbAdmin only on these two
const adminDb = db.getSiblingDB('admin');
try {
  adminDb.createRole({
    role: 'nebron',
    privileges: [],
    roles: [
      { role: 'readWrite', db: 'nebron_auth' },
      { role: 'dbAdmin', db: 'nebron_auth' },
      { role: 'readWrite', db: 'nebron_core' },
      { role: 'dbAdmin', db: 'nebron_core' }
    ]
  });
  print('[init-mongo] Created role nebron');
} catch (e) {
  if (e.code === 51002 || (e.message && e.message.includes('already exists'))) {
    print('[init-mongo] Role nebron already exists, updating...');
    try {
      adminDb.updateRole('nebron', {
        roles: [
          { role: 'readWrite', db: 'nebron_auth' },
          { role: 'dbAdmin', db: 'nebron_auth' },
          { role: 'readWrite', db: 'nebron_core' },
          { role: 'dbAdmin', db: 'nebron_core' }
        ]
      });
      print('[init-mongo] Updated role nebron');
    } catch (updateErr) {
      print('[init-mongo] Notice on updateRole nebron: ' + updateErr.message);
    }
  } else {
    print('[init-mongo] Notice on createRole nebron: ' + e.message);
  }
}

print('[init-mongo] MongoDB initialization finished successfully.');
