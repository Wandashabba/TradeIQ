-- CreateTable
CREATE TABLE "assistant_artifacts" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "conversation_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "tool_name" TEXT NOT NULL,
    "params" JSONB NOT NULL,
    "params_history" JSONB NOT NULL DEFAULT '[]',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "assistant_artifacts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "assistant_artifacts_client_id_user_id_conversation_id_idx" ON "assistant_artifacts"("client_id", "user_id", "conversation_id");

-- AddForeignKey
ALTER TABLE "assistant_artifacts" ADD CONSTRAINT "assistant_artifacts_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
