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
  conversation_id uuid,
  type text,
  title text,
  metadata text,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY (conversation_id)
);

-- 2. Messages table (clustered by message_id DESC for latest-first chat queries)
CREATE TABLE IF NOT EXISTS messages (
  conversation_id uuid,
  message_id timeuuid,
  sender_id text,
  content text,
  type text,
  media_url text,
  created_at timestamp,
  PRIMARY KEY (conversation_id, message_id)
) WITH CLUSTERING ORDER BY (message_id DESC);

-- 3. Receipts table (read/delivery receipts per user and conversation)
CREATE TABLE IF NOT EXISTS receipts (
  conversation_id uuid,
  user_id text,
  message_id timeuuid,
  status text,
  read_at timestamp,
  PRIMARY KEY ((conversation_id, user_id), message_id)
);

-- 4. User conversations table (inbox view per user sorted by recent activity)
CREATE TABLE IF NOT EXISTS user_conversations (
  user_id text,
  last_message_at timestamp,
  conversation_id uuid,
  unread_count int,
  PRIMARY KEY (user_id, last_message_at, conversation_id)
) WITH CLUSTERING ORDER BY (last_message_at DESC, conversation_id ASC);
