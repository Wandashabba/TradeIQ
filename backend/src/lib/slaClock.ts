export type TaskPriority = 'critical' | 'high' | 'normal';

const SLA_HOURS: Record<TaskPriority, number> = {
  critical: 24,
  high: 24 * 3,
  normal: 24 * 7,
};

export function computeSlaDueAt(priority: TaskPriority, from: Date): Date {
  const dueAt = new Date(from);
  dueAt.setUTCHours(dueAt.getUTCHours() + SLA_HOURS[priority]);
  return dueAt;
}
