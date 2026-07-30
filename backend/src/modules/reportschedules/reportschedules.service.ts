import { Prisma, ReportSchedule } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError } from '../../middleware/errorHandler';
import { findReportForClient, generateReport } from '../reports/reports.service';

// The cadences a schedule may fire on. Free-text at the schema level; this is
// the runtime allow-list.
export const CADENCES = ['daily', 'weekly'] as const;
export type Cadence = (typeof CADENCES)[number];

export function isCadence(value: unknown): value is Cadence {
  return typeof value === 'string' && (CADENCES as readonly string[]).includes(value);
}

// A non-empty array of string recipients (emails/webhook targets).
export function isRecipients(value: unknown): value is string[] {
  return Array.isArray(value) && value.length > 0 && value.every((r) => typeof r === 'string');
}

export interface CreateScheduleInput {
  clientId: string;
  reportDefinitionId: string;
  cadence: Cadence;
  recipients: string[];
}

export async function createSchedule(input: CreateScheduleInput): Promise<ReportSchedule> {
  // The report definition must belong to the caller's client (404 otherwise).
  await findReportForClient(input.reportDefinitionId, input.clientId);
  return prisma.reportSchedule.create({
    data: {
      clientId: input.clientId,
      reportDefinitionId: input.reportDefinitionId,
      cadence: input.cadence,
      recipients: input.recipients as Prisma.InputJsonValue,
    },
  });
}

export async function listSchedules(input: {
  clientId: string;
  limit: number;
  cursor?: string;
}) {
  const rows = await prisma.reportSchedule.findMany({
    where: { clientId: input.clientId },
    include: { reportDefinition: { select: { name: true } } },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, input.limit);
}

export async function findScheduleForClient(id: string, clientId: string): Promise<ReportSchedule> {
  const schedule = await prisma.reportSchedule.findFirst({ where: { id, clientId } });
  if (!schedule) {
    throw new NotFoundError('Report schedule not found');
  }
  return schedule;
}

export interface UpdateScheduleInput {
  active?: boolean;
  cadence?: Cadence;
  recipients?: string[];
}

export async function updateSchedule(
  id: string,
  clientId: string,
  input: UpdateScheduleInput,
): Promise<ReportSchedule> {
  // Tenant check first — a cross-tenant id must 404, not update.
  await findScheduleForClient(id, clientId);
  return prisma.reportSchedule.update({
    where: { id },
    data: {
      ...(input.active !== undefined ? { active: input.active } : {}),
      ...(input.cadence !== undefined ? { cadence: input.cadence } : {}),
      ...(input.recipients !== undefined
        ? { recipients: input.recipients as Prisma.InputJsonValue }
        : {}),
    },
  });
}

export async function deleteSchedule(id: string, clientId: string): Promise<void> {
  // Tenant check first — a cross-tenant id must 404, not delete.
  await findScheduleForClient(id, clientId);
  await prisma.reportSchedule.delete({ where: { id } });
}

export interface ScheduleRunResult {
  schedule: ReportSchedule;
  generatedAt: string;
  rowCount: number;
  deliveredTo: string[];
}

export async function runSchedule(id: string, clientId: string): Promise<ScheduleRunResult> {
  const schedule = await findScheduleForClient(id, clientId);
  // Generate the linked report through the reports service (tenant-scoped).
  const report = await generateReport(schedule.reportDefinitionId, clientId);
  const updated = await prisma.reportSchedule.update({
    where: { id },
    data: { lastRunAt: new Date() },
  });

  // Actual email/webhook delivery of the generated report is Phase-4 infra;
  // this endpoint performs the generation and records the run. `deliveredTo`
  // echoes the schedule's configured recipients.
  const recipients = isRecipients(updated.recipients) ? updated.recipients : [];

  return {
    schedule: updated,
    generatedAt: report.generatedAt,
    rowCount: report.rowCount,
    deliveredTo: recipients,
  };
}
