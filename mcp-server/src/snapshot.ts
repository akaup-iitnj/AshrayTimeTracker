import { z } from 'zod';

const datePattern = /^\d{4}-\d{2}-\d{2}$/;

const rangeSchema = z.object({
  start_date: z.string().regex(datePattern),
  end_date: z.string().regex(datePattern),
  days: z.number().int().positive(),
});

const entrySchema = z.object({
  date: z.string().regex(datePattern),
  hour_start: z.number().int().min(0).max(23),
  hour_end: z.number().int().min(0).max(23),
  task: z.string(),
  category_id: z.string().nullable(),
  category_name: z.string(),
  category_color_value: z.number().int().nullable(),
  updated_at: z.string(),
});

const categorySchema = z.object({
  id: z.string(),
  name: z.string(),
  color_value: z.number().int(),
  sort_order: z.number().int(),
  updated_at: z.string(),
});

const dailyCompletionSchema = z.object({
  date: z.string().regex(datePattern),
  logged_hours: z.number().int().min(0).max(24),
  completion_percent: z.number().min(0).max(100),
});

const categorySummarySchema = z.object({
  category_id: z.string().nullable(),
  category_name: z.string(),
  category_color_value: z.number().int().nullable(),
  logged_hours: z.number().int().positive(),
  percentage: z.number().min(0).max(100),
});

const settingsSchema = z.object({
  reminders_enabled: z.boolean(),
  reminder_start_hour: z.number().int().min(0).max(23),
  reminder_end_hour: z.number().int().min(1).max(24),
  timezone: z.string(),
  updated_at: z.string().nullable(),
});

export const dashboardSnapshotSchema = z.object({
  schema_version: z.literal(1),
  source: z.literal('time_tracker'),
  generated_at: z.string(),
  range: rangeSchema,
  entries: z.array(entrySchema),
  categories: z.array(categorySchema),
  daily_completion: z.array(dailyCompletionSchema),
  category_summary: z.array(categorySummarySchema),
  settings: settingsSchema,
});

export type DashboardSnapshot = z.infer<typeof dashboardSnapshotSchema>;

export interface RpcError {
  message: string;
  code?: string;
  details?: string;
  hint?: string;
}

export interface RpcResponse {
  data: unknown;
  error: RpcError | null;
}

export type SnapshotRpc = (parameters: {
  p_start_date: string;
  p_end_date: string;
}) => Promise<RpcResponse>;

function parseDate(value: string, label: string): Date {
  if (!datePattern.test(value)) {
    throw new Error(`${label} must use YYYY-MM-DD format.`);
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw new Error(`${label} is not a valid calendar date.`);
  }
  return parsed;
}

export function validateDateRange(startDate: string, endDate: string): void {
  const start = parseDate(startDate, 'start_date');
  const end = parseDate(endDate, 'end_date');
  const dayDifference = Math.round(
    (end.getTime() - start.getTime()) / 86_400_000,
  );
  if (dayDifference < 0) {
    throw new Error('start_date must be on or before end_date.');
  }
  if (dayDifference > 366) {
    throw new Error('Date ranges cannot exceed 367 days.');
  }
}

export function defaultDateRange(now: Date = new Date()): {
  startDate: string;
  endDate: string;
} {
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const start = new Date(end);
  start.setUTCDate(start.getUTCDate() - 6);
  return {
    startDate: start.toISOString().slice(0, 10),
    endDate: end.toISOString().slice(0, 10),
  };
}

export class DashboardSnapshotReader {
  constructor(private readonly rpc: SnapshotRpc) {}

  async get(startDate: string, endDate: string): Promise<DashboardSnapshot> {
    validateDateRange(startDate, endDate);
    const response = await this.rpc({
      p_start_date: startDate,
      p_end_date: endDate,
    });
    if (response.error) {
      const suffix = response.error.code ? ` (${response.error.code})` : '';
      throw new Error(`Time Tracker dashboard API failed${suffix}: ${response.error.message}`);
    }
    return dashboardSnapshotSchema.parse(response.data);
  }
}
