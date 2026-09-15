-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "audit_template_id" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "clients_audit_template_id_key" ON "clients"("audit_template_id");

-- AddForeignKey
ALTER TABLE "clients" ADD CONSTRAINT "clients_audit_template_id_fkey" FOREIGN KEY ("audit_template_id") REFERENCES "audit_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

