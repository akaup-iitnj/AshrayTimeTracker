import assert from 'node:assert/strict';
import test from 'node:test';

import {
  DashboardSnapshotReader,
  defaultDateRange,
  validateDateRange,
} from '../src/snapshot.js';

const sampleSnapshot = {
  schema_version: 2,
  source: 'time_tracker',
  generated_at: '2026-07-11T12:00:00Z',
  range: {
    start_date: '2026-07-10',
    end_date: '2026-07-11',
    days: 2,
  },
  entries: [
    {
      date: '2026-07-10',
      hour_start: 9,
      hour_end: 10,
      task: 'Build dashboard API',
      category_id: 'work',
      category_name: 'Work',
      category_color_value: 4281624981,
      updated_at: '2026-07-10T14:00:00Z',
    },
  ],
  categories: [
    {
      id: 'work',
      name: 'Work',
      color_value: 4281624981,
      sort_order: 0,
      updated_at: '2026-07-10T14:00:00Z',
    },
  ],
  daily_completion: [
    { date: '2026-07-10', logged_hours: 1, completion_percent: 4.2 },
    { date: '2026-07-11', logged_hours: 0, completion_percent: 0 },
  ],
  category_summary: [
    {
      category_id: 'work',
      category_name: 'Work',
      category_color_value: 4281624981,
      logged_hours: 1,
      percentage: 100,
    },
  ],
  daily_reflections: [
    {
      date: '2026-07-10',
      mood: 4,
      energy: 3,
      calm: 4,
      note: 'A productive and grounded day.',
      updated_at: '2026-07-10T22:00:00Z',
    },
  ],
  settings: {
    reminders_enabled: true,
    reminder_start_hour: 8,
    reminder_end_hour: 23,
    morning_videos_enabled: true,
    morning_videos_hour: 8,
    timezone: 'America/New_York',
    updated_at: '2026-07-10T14:00:00Z',
  },
} as const;

test('validates dashboard date ranges', () => {
  assert.doesNotThrow(() => validateDateRange('2026-01-01', '2026-12-31'));
  assert.throws(
    () => validateDateRange('2026-02-30', '2026-03-01'),
    /valid calendar date/,
  );
  assert.throws(
    () => validateDateRange('2026-07-12', '2026-07-11'),
    /on or before/,
  );
  assert.throws(
    () => validateDateRange('2025-01-01', '2026-07-11'),
    /cannot exceed 367 days/,
  );
});

test('builds a seven-day default range', () => {
  assert.deepEqual(defaultDateRange(new Date('2026-07-11T18:00:00Z')), {
    startDate: '2026-07-05',
    endDate: '2026-07-11',
  });
});

test('fetches and validates the versioned dashboard snapshot', async () => {
  let received: Record<string, string> | undefined;
  const reader = new DashboardSnapshotReader(async (parameters) => {
    received = parameters;
    return { data: sampleSnapshot, error: null };
  });

  const snapshot = await reader.get('2026-07-10', '2026-07-11');

  assert.deepEqual(received, {
    p_start_date: '2026-07-10',
    p_end_date: '2026-07-11',
  });
  assert.equal(snapshot.schema_version, 2);
  assert.equal(snapshot.entries[0]?.task, 'Build dashboard API');
});

test('surfaces database errors without returning partial data', async () => {
  const reader = new DashboardSnapshotReader(async () => ({
    data: null,
    error: { code: '42501', message: 'Authentication is required.' },
  }));

  await assert.rejects(
    reader.get('2026-07-10', '2026-07-11'),
    /dashboard API failed \(42501\)/,
  );
});

test('rejects snapshots from an incompatible schema version', async () => {
  const reader = new DashboardSnapshotReader(async () => ({
    data: { ...sampleSnapshot, schema_version: 3 },
    error: null,
  }));

  await assert.rejects(reader.get('2026-07-10', '2026-07-11'));
});
