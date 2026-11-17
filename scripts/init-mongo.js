  // MongoDB initialization script for Zenuxs
// Idempotent: safe to run multiple times.

// 1. Initialize zenuxs_auth
const authDb = db.getSiblingDB('zenuxs_auth');

// Create dedicated user for auth if not exists
try {
  authDb.createUser({
    user: 'zenuxs_auth_user',
    pwd: 'auth_password_dev',
    roles: [{ role: 'readWrite', db: 'zenuxs_auth' }]
  });
  print('[init-mongo] Created user zenuxs_auth_user');
} catch (e) {
  if (e.code === 51003 || (e.message && e.message.includes('already exists'))) {
    print('[init-mongo] User zenuxs_auth_user already exists');
  } else {
    print('[init-mongo] Notice on createUser zenuxs_auth_user: ' + e.message);
  }
}

// Create unique index on users.email
authDb.users.createIndex({ email: 1 }, { unique: true, background: true });

// Create sessions indexes as per auth-service spec
authDb.sessions.createIndex({ refreshTokenHash: 1 }, { unique: true, background: true });
authDb.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, background: true });
authDb.sessions.createIndex({ userId: 1 }, { background: true });
authDb.sessions.createIndex({ familyId: 1 }, { background: true });
print('[init-mongo] Indexes created for zenuxs_auth');

// 2. Initialize zenuxs_core
const coreDb = db.getSiblingDB('zenuxs_core');

// Create dedicated user for core if not exists
try {
  coreDb.createUser({
    user: 'zenuxs_core_user',
    pwd: 'core_password_dev',
    roles: [{ role: 'readWrite', db: 'zenuxs_core' }]
  });
  print('[init-mongo] Created user zenuxs_core_user');
} catch (e) {
  if (e.code === 51003 || (e.message && e.message.includes('already exists'))) {
    print('[init-mongo] User zenuxs_core_user already exists');
  } else {
    print('[init-mongo] Notice on createUser zenuxs_core_user: ' + e.message);
  }
}

// Create unique indexes on profiles.userId and profiles.username
coreDb.profiles.createIndex({ userId: 1 }, { unique: true, background: true, name: 'idx_profiles_userId_unique' });
coreDb.profiles.createIndex({ username: 1 }, { unique: true, background: true, name: 'idx_profiles_username_unique' });
print('[init-mongo] Indexes created for zenuxs_core');

// 3. Create role 'zenuxs' in admin with readWrite on both, dbAdmin only on these two
const adminDb = db.getSiblingDB('admin');
try {
  adminDb.createRole({
    role: 'zenuxs',
    privileges: [],
    roles: [
      { role: 'readWrite', db: 'zenuxs_auth' },
      { role: 'dbAdmin', db: 'zenuxs_auth' },
      { role: 'readWrite', db: 'zenuxs_core' },
      { role: 'dbAdmin', db: 'zenuxs_core' }
    ]
  });
  print('[init-mongo] Created role zenuxs');
} catch (e) {
  if (e.code === 51002 || (e.message && e.message.includes('already exists'))) {
    print('[init-mongo] Role zenuxs already exists, updating...');
    try {
      adminDb.updateRole('zenuxs', {
        roles: [
          { role: 'readWrite', db: 'zenuxs_auth' },
          { role: 'dbAdmin', db: 'zenuxs_auth' },
          { role: 'readWrite', db: 'zenuxs_core' },
          { role: 'dbAdmin', db: 'zenuxs_core' }
        ]
      });
      print('[init-mongo] Updated role zenuxs');
    } catch (updateErr) {
      print('[init-mongo] Notice on updateRole zenuxs: ' + updateErr.message);
    }
  } else {
    print('[init-mongo] Notice on createRole zenuxs: ' + e.message);
  }
}

print('[init-mongo] MongoDB initialization finished successfully.');
