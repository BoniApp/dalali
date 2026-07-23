-- ═══════════════════════════════════════════════════════════════
-- DALALI SCHEMA — Phase 17: In-app chat + admin broadcast
--
-- WhatsApp-style 1:1 chat between users (seeker ↔ landlord/agent)
-- plus admin↔user conversations used by the admin-broadcast edge
-- function. One conversation per user pair, enforced by a
-- LEAST/GREATEST unique index regardless of who started it.
--
-- Design notes:
--   • Participant names are denormalized onto conversations
--     because users RLS only exposes a user's own row.
--   • last_message_* and unread counters are maintained ONLY by
--     the handle_new_chat_message trigger and the
--     mark_conversation_read RPC — clients get no UPDATE policy.
--   • New messages fan out a notifications row (type 'message')
--     to the recipient; the notifications type CHECK is extended
--     with 'message' and 'broadcast'.
-- Run after 016_withdrawal_verification_gate.sql
-- ═══════════════════════════════════════════════════════════════

-- ─── TABLES ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_a UUID NOT NåULL REFERENCES users(id) ON DELETE CASCADE,
  participant_b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participant_a_name TEXT NOT NULL DEFAULT '',
  participant_b_name TEXT NOT NULL DEFAULT '',
  -- Optional context: the property the chat started from.
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  property_title TEXT,
  last_message_text TEXT,
  last_message_at TIMESTAMPTZ,
  -- Unread counters, one per participant; trigger/RPC maintained.
  unread_a INT NOT NULL DEFAULT 0,
  unread_b INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One thread per user pair, either direction.
CREATE UNIQUE INDEX IF NOT EXISTS conversations_pair_key
  ON conversations (LEAST(participant_a, participant_b), GREATEST(participant_a, participant_b));
CREATE INDEX IF NOT EXISTS idx_conversations_a ON conversations(participant_a, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_b ON conversations(participant_b, last_message_at DESC);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at);

-- ─── RLS ──────────────────────────────────────────────────────

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants can read conversations" ON conversations;
CREATE POLICY "Participants can read conversations" ON conversations FOR SELECT
  USING (
    auth.uid() = participant_a
    OR auth.uid() = participant_b
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS "Participants can create conversations" ON conversations;
CREATE POLICY "Participants can create conversations" ON conversations FOR INSERT
  WITH CHECK (auth.uid() = participant_a OR auth.uid() = participant_b);

-- No client UPDATE/DELETE: last_message_* and unread counters are
-- maintained by the trigger/RPC only (anti-tamper).

DROP POLICY IF EXISTS "Participants can read messages" ON messages;
CREATE POLICY "Participants can read messages" ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
        AND (c.participant_a = auth.uid() OR c.participant_b = auth.uid())
    )
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS "Participants can send messages" ON messages;
CREATE POLICY "Participants can send messages" ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
        AND (c.participant_a = auth.uid() OR c.participant_b = auth.uid())
    )
  );

-- No client UPDATE/DELETE on messages: read-marking goes through
-- mark_conversation_read (SECURITY DEFINER).

-- ─── NEW-MESSAGE TRIGGER ──────────────────────────────────────
-- Maintains last_message_* + recipient unread counter, and fans
-- out a notifications row so the recipient's bell lights up.

CREATE OR REPLACE FUNCTION public.handle_new_chat_message()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv conversations%ROWTYPE;
  v_recipient UUID;
  v_sender_name TEXT;
BEGIN
  SELECT * INTO v_conv FROM conversations WHERE id = NEW.conversation_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF NEW.sender_id = v_conv.participant_a THEN
    v_recipient := v_conv.participant_b;
    v_sender_name := v_conv.participant_a_name;
    UPDATE conversations
    SET last_message_text = NEW.body,
        last_message_at = NEW.created_at,
        unread_b = unread_b + 1
    WHERE id = NEW.conversation_id;
  ELSE
    v_recipient := v_conv.participant_a;
    v_sender_name := v_conv.participant_b_name;
    UPDATE conversations
    SET last_message_text = NEW.body,
        last_message_at = NEW.created_at,
        unread_a = unread_a + 1
    WHERE id = NEW.conversation_id;
  END IF;

  INSERT INTO notifications (user_id, type, title, body, target_id, target_collection)
  VALUES (
    v_recipient,
    'message',
    COALESCE(NULLIF(v_sender_name, ''), 'New message'),
    LEFT(NEW.body, 100),
    NEW.conversation_id::text,
    'conversations'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_new_chat_message ON messages;
CREATE TRIGGER trg_new_chat_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_chat_message();

-- ─── MARK-READ RPC ────────────────────────────────────────────
-- Only a participant may mark a conversation read; flips incoming
-- messages to is_read and zeroes the caller's unread counter.

CREATE OR REPLACE FUNCTION public.mark_conversation_read(p_conversation_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM conversations
    WHERE id = p_conversation_id
      AND (participant_a = auth.uid() OR participant_b = auth.uid())
  ) THEN
    RAISE EXCEPTION 'Not a participant of this conversation';
  END IF;

  UPDATE messages
  SET is_read = true
  WHERE conversation_id = p_conversation_id
    AND sender_id <> auth.uid()
    AND is_read = false;

  UPDATE conversations
  SET unread_a = CASE WHEN participant_a = auth.uid() THEN 0 ELSE unread_a END,
      unread_b = CASE WHEN participant_b = auth.uid() THEN 0 ELSE unread_b END
  WHERE id = p_conversation_id;
END;
$$ LANGUAGE plpgsql;

-- ─── NOTIFICATION TYPE EXTENSION ──────────────────────────────

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'inquiry', 'appointment', 'propertyApproved', 'propertyRejected',
    'tenancyApplication', 'tenancyApproved', 'maintenanceUpdate',
    'rentDue', 'paymentReceived', 'withdrawalProcessed', 'system',
    'message', 'broadcast'
  ));

-- ─── REALTIME ─────────────────────────────────────────────────

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
