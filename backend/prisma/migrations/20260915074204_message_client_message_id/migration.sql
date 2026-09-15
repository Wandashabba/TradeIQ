-- #308: an idempotency key per composed message, so a POST /messages retry
-- after a lost response returns the original row instead of a 409 or a
-- duplicate. The column is new and every existing row is NULL, and Postgres
-- treats NULLs as distinct in a unique index, so this cannot fail on existing
-- data.

-- AlterTable
ALTER TABLE "messages" ADD COLUMN     "client_message_id" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "messages_sender_id_client_message_id_key" ON "messages"("sender_id", "client_message_id");
