-- CreateTable
CREATE TABLE "assistant_actions" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "conversation_id" TEXT,
    "tool_name" TEXT NOT NULL,
    "tier" TEXT NOT NULL,
    "args" JSONB NOT NULL,
    "outcome" TEXT NOT NULL,
    "detail" TEXT,
    "undo_context" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMP(3),

    CONSTRAINT "assistant_actions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "assistant_actions_client_id_created_at_idx" ON "assistant_actions"("client_id", "created_at");

-- CreateIndex
CREATE INDEX "assistant_actions_client_id_user_id_created_at_idx" ON "assistant_actions"("client_id", "user_id", "created_at");

-- AddForeignKey
ALTER TABLE "assistant_actions" ADD CONSTRAINT "assistant_actions_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
