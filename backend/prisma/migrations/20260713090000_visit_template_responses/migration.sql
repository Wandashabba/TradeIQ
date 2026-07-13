-- CreateTable
CREATE TABLE "visit_template_responses" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "template_id" TEXT NOT NULL,
    "template_version" INTEGER NOT NULL,
    "answers" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "visit_template_responses_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "visit_template_responses_visit_id_template_id_key" ON "visit_template_responses"("visit_id", "template_id");

-- AddForeignKey
ALTER TABLE "visit_template_responses" ADD CONSTRAINT "visit_template_responses_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visit_template_responses" ADD CONSTRAINT "visit_template_responses_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "audit_templates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
