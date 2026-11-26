-- ScyllaDB Keyspace and Table Initialization for Nebron
-- Idempotent: safe to run multiple times.

CREATE KEYSPACE IF NOT EXISTS nebron
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
};

USE nebron;

-- 1. Conversations table
CREATE TABLE IF NOT EXISTS conversations (
  id           uuid,
  kind         text,
  created_at   timestamp,
  created_by   uuid,
  name         text,
  owner_id     uuid,
  member_count int,
  member_ids   set<uuid>,
  space_id     text,
  channel_id   text,
  PRIMARY KEY (id)
);

-- 2. Conversation members table
CREATE TABLE IF NOT EXISTS conversation_members (
  conversation_id uuid,
  user_id         uuid,
  joined_at       timestamp,
  role            text,
  PRIMARY KEY ((conversation_id), joined_at, user_id)
) WITH CLUSTERING ORDER BY (joined_at ASC, user_id ASC);

-- 3. Messages table (clustered by message_id DESC for latest-first chat queries)
CREATE TABLE IF NOT EXISTS messages (
  conversation_id uuid,
  message_id      timeuuid,
  sender_id       uuid,
  body            text,
  created_at      timestamp,
  edited_at       timestamp,
  deleted         boolean,
  PRIMARY KEY ((conversation_id), message_id)
) WITH CLUSTERING ORDER BY (message_id DESC);

-- 4. Receipts table (read/delivery receipts per user and conversation)
CREATE TABLE IF NOT EXISTS receipts (
  conversation_id uuid,
  user_id         uuid,
  last_read_id    timeuuid,
  last_read_at    timestamp,
  PRIMARY KEY ((conversation_id), user_id)
);

-- 5. User conversations table (inbox view per user sorted by recent activity)
CREATE TABLE IF NOT EXISTS user_conversations (
  user_id           uuid,
  conversation_id   uuid,
  last_message_at   timestamp,
  last_message_id   timeuuid,
  last_message_body text,
  other_user_id     uuid,
  unread_count      int,
  PRIMARY KEY ((user_id), last_message_at, conversation_id)
) WITH CLUSTERING ORDER BY (last_message_at DESC, conversation_id ASC);
