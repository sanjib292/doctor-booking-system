'use strict';

/**
 * pg-based Prisma client shim
 * Replaces the binary-requiring generated Prisma client with a direct pg Pool implementation.
 */

const { Pool } = require('pg');

// ─── Enum Values ────────────────────────────────────────────────────────────

const Role = { PATIENT: 'PATIENT', DOCTOR: 'DOCTOR', ADMIN: 'ADMIN', SUPER_ADMIN: 'SUPER_ADMIN' };
const Gender = { MALE: 'MALE', FEMALE: 'FEMALE', OTHER: 'OTHER', PREFER_NOT_TO_SAY: 'PREFER_NOT_TO_SAY' };
const AppointmentStatus = { PENDING: 'PENDING', CONFIRMED: 'CONFIRMED', CHECKED_IN: 'CHECKED_IN', IN_CONSULTATION: 'IN_CONSULTATION', COMPLETED: 'COMPLETED', CANCELLED: 'CANCELLED', NO_SHOW: 'NO_SHOW', RESCHEDULED: 'RESCHEDULED' };
const DayOfWeek = { MONDAY: 'MONDAY', TUESDAY: 'TUESDAY', WEDNESDAY: 'WEDNESDAY', THURSDAY: 'THURSDAY', FRIDAY: 'FRIDAY', SATURDAY: 'SATURDAY', SUNDAY: 'SUNDAY' };
const NotificationChannel = { FCM: 'FCM', EMAIL: 'EMAIL', SMS: 'SMS' };
const NotificationType = { BOOKING_CONFIRMED: 'BOOKING_CONFIRMED', BOOKING_REMINDER_24H: 'BOOKING_REMINDER_24H', BOOKING_REMINDER_1H: 'BOOKING_REMINDER_1H', BOOKING_CANCELLED: 'BOOKING_CANCELLED', BOOKING_RESCHEDULED: 'BOOKING_RESCHEDULED', DOCTOR_UNAVAILABLE: 'DOCTOR_UNAVAILABLE', NEW_APPOINTMENT: 'NEW_APPOINTMENT', NEW_REVIEW: 'NEW_REVIEW', SCHEDULE_REMINDER: 'SCHEDULE_REMINDER', SYSTEM: 'SYSTEM' };
const SlotStatus = { AVAILABLE: 'AVAILABLE', LOCKED: 'LOCKED', BOOKED: 'BOOKED' };
const VerificationStatus = { PENDING: 'PENDING', VERIFIED: 'VERIFIED', REJECTED: 'REJECTED' };
const MedicalRecordType = { CONDITION: 'CONDITION', ALLERGY: 'ALLERGY', MEDICATION: 'MEDICATION', SURGERY: 'SURGERY', VACCINATION: 'VACCINATION', NOTE: 'NOTE' };

// ─── SQL Query Builder ───────────────────────────────────────────────────────

let paramCount = 0;
const resetParams = () => { paramCount = 0; };
const nextParam = () => `$${++paramCount}`;

function col(name) {
  // Returns quoted column name
  if (name === 'id' || name === 'role' || name === 'type' || name === 'status' || name === 'date') return `"${name}"`;
  // Already contains quotes
  if (name.startsWith('"')) return name;
  // camelCase → quoted
  return `"${name}"`;
}

function buildConditions(where, params, tableAlias) {
  if (!where || Object.keys(where).length === 0) return '';
  const prefix = tableAlias ? `${tableAlias}.` : '';
  const clauses = [];
  for (const [key, val] of Object.entries(where)) {
    if (key === 'AND') {
      const sub = val.map(w => buildConditions(w, params, tableAlias)).filter(Boolean).join(' AND ');
      if (sub) clauses.push(`(${sub})`);
    } else if (key === 'OR') {
      const sub = val.map(w => buildConditions(w, params, tableAlias)).filter(Boolean).join(' OR ');
      if (sub) clauses.push(`(${sub})`);
    } else if (key === 'NOT') {
      const sub = buildConditions(val, params, tableAlias);
      if (sub) clauses.push(`NOT (${sub})`);
    } else if (val === null) {
      clauses.push(`${prefix}${col(key)} IS NULL`);
    } else if (val === undefined) {
      // skip
    } else if (typeof val === 'object' && !Array.isArray(val) && !(val instanceof Date)) {
      // Nested condition object — each branch owns its own nextParam/push
      const subClauses = [];
      for (const [op, opVal] of Object.entries(val)) {
        if (opVal === undefined || op === 'mode') continue;
        if (op === 'equals') {
          const p = nextParam(); params.push(opVal instanceof Date ? opVal.toISOString() : opVal);
          subClauses.push(`${prefix}${col(key)} = ${p}`);
        } else if (op === 'not') {
          if (opVal === null) {
            subClauses.push(`${prefix}${col(key)} IS NOT NULL`);
          } else {
            const p = nextParam(); params.push(opVal instanceof Date ? opVal.toISOString() : opVal);
            subClauses.push(`${prefix}${col(key)} != ${p}`);
          }
        } else if (op === 'in') {
          const placeholders = opVal.map(v => { const pp = nextParam(); params.push(v); return pp; });
          subClauses.push(`${prefix}${col(key)} IN (${placeholders.join(', ')})`);
        } else if (op === 'notIn') {
          const placeholders = opVal.map(v => { const pp = nextParam(); params.push(v); return pp; });
          subClauses.push(`${prefix}${col(key)} NOT IN (${placeholders.join(', ')})`);
        } else if (op === 'lt') {
          const p = nextParam(); params.push(opVal instanceof Date ? opVal.toISOString() : opVal);
          subClauses.push(`${prefix}${col(key)} < ${p}`);
        } else if (op === 'lte') {
          const p = nextParam(); params.push(opVal instanceof Date ? opVal.toISOString() : opVal);
          subClauses.push(`${prefix}${col(key)} <= ${p}`);
        } else if (op === 'gt') {
          const p = nextParam(); params.push(opVal instanceof Date ? opVal.toISOString() : opVal);
          subClauses.push(`${prefix}${col(key)} > ${p}`);
        } else if (op === 'gte') {
          const p = nextParam(); params.push(opVal instanceof Date ? opVal.toISOString() : opVal);
          subClauses.push(`${prefix}${col(key)} >= ${p}`);
        } else if (op === 'contains') {
          const p = nextParam(); params.push(`%${opVal}%`);
          subClauses.push(`${prefix}${col(key)} ILIKE ${p}`);
        } else if (op === 'startsWith') {
          const p = nextParam(); params.push(`${opVal}%`);
          subClauses.push(`${prefix}${col(key)} ILIKE ${p}`);
        } else if (op === 'endsWith') {
          const p = nextParam(); params.push(`%${opVal}`);
          subClauses.push(`${prefix}${col(key)} ILIKE ${p}`);
        } else {
          const p = nextParam(); params.push(opVal instanceof Date ? opVal.toISOString() : opVal);
          subClauses.push(`${prefix}${col(key)} = ${p}`);
        }
      }
      if (subClauses.length > 0) clauses.push(subClauses.join(' AND '));
    } else {
      const p = nextParam();
      params.push(val instanceof Date ? val.toISOString() : val);
      clauses.push(`${prefix}${col(key)} = ${p}`);
    }
  }
  return clauses.join(' AND ');
}

function buildOrderBy(orderBy) {
  if (!orderBy) return '';
  const orders = Array.isArray(orderBy) ? orderBy : [orderBy];
  const clauses = orders.map(o => {
    const [[key, dir]] = Object.entries(o);
    return `${col(key)} ${dir === 'desc' ? 'DESC' : 'ASC'}`;
  });
  return `ORDER BY ${clauses.join(', ')}`;
}

function buildColumnsAndValues(data, params) {
  const cols = [];
  const vals = [];
  for (const [key, val] of Object.entries(data)) {
    if (val === undefined) continue;
    cols.push(col(key));
    if (val === null) {
      vals.push('NULL');
    } else if (Array.isArray(val)) {
      const p = nextParam();
      params.push(val);
      vals.push(p);
    } else if (val instanceof Date) {
      const p = nextParam();
      params.push(val.toISOString());
      vals.push(p);
    } else {
      const p = nextParam();
      params.push(val);
      vals.push(p);
    }
  }
  return { cols, vals };
}

function buildSetClause(data, params) {
  const sets = [];
  for (const [key, val] of Object.entries(data)) {
    if (val === undefined) continue;
    if (val === null) {
      sets.push(`${col(key)} = NULL`);
    } else if (Array.isArray(val)) {
      const p = nextParam();
      params.push(val);
      sets.push(`${col(key)} = ${p}`);
    } else if (val instanceof Date) {
      const p = nextParam();
      params.push(val.toISOString());
      sets.push(`${col(key)} = ${p}`);
    } else if (typeof val === 'object' && val !== null && !Array.isArray(val) && !(val instanceof Date)) {
      // Prisma nested updates like { increment: 1 }
      if ('increment' in val) { const p = nextParam(); params.push(val.increment); sets.push(`${col(key)} = ${col(key)} + ${p}`); }
      else if ('decrement' in val) { const p = nextParam(); params.push(val.decrement); sets.push(`${col(key)} = ${col(key)} - ${p}`); }
      else if ('set' in val) {
        if (val.set === null) { sets.push(`${col(key)} = NULL`); }
        else { const p = nextParam(); params.push(val.set); sets.push(`${col(key)} = ${p}`); }
      } else {
        const p = nextParam();
        params.push(JSON.stringify(val));
        sets.push(`${col(key)} = ${p}`);
      }
    } else {
      const p = nextParam();
      params.push(val);
      sets.push(`${col(key)} = ${p}`);
    }
  }
  return sets.join(', ');
}

// Simple include handler - does separate queries for relations
const TABLE_MAP = {
  user: 'users', admin: 'admins', doctor: 'doctors', category: 'categories',
  clinic: 'clinics', doctorClinic: 'doctor_clinics', doctorCategory: 'doctor_categories',
  doctorAvailability: 'doctor_availabilities', timeSlot: 'time_slots',
  doctorVacation: 'doctor_vacations', blockedDate: 'blocked_dates',
  appointment: 'appointments', appointmentStatusHistory: 'appointment_status_history',
  review: 'reviews', favorite: 'favorites', notification: 'notifications',
  doctorNotification: 'doctor_notifications', otpCode: 'otp_codes',
  refreshToken: 'refresh_tokens', auditLog: 'audit_logs',
  medicalRecord: 'medical_records', appSetting: 'app_settings',
};

// ─── Model Accessor Class ────────────────────────────────────────────────────

class ModelAccessor {
  constructor(table, client) {
    this.table = table;
    this.client = client; // pg Pool or PoolClient
  }

  async query(sql, params) {
    const result = await this.client.query(sql, params);
    return result.rows;
  }

  async findUnique({ where, include, select } = {}) {
    return this.findFirst({ where, include, select });
  }

  async findFirst({ where, orderBy, include, select, take, skip } = {}) {
    const results = await this.findMany({ where, orderBy, include, select, take: take ?? 1, skip });
    return results[0] ?? null;
  }

  async findMany({ where, orderBy, include, select, take, skip, cursor, distinct } = {}) {
    resetParams();
    const params = [];
    const whereClause = where ? buildConditions(where, params) : '';
    const orderClause = buildOrderBy(orderBy);
    const limitClause = take != null ? `LIMIT ${parseInt(take)}` : '';
    const skipClause = skip != null ? `OFFSET ${parseInt(skip)}` : '';

    let sql = `SELECT * FROM "${this.table}"`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    if (orderClause) sql += ` ${orderClause}`;
    if (limitClause) sql += ` ${limitClause}`;
    if (skipClause) sql += ` ${skipClause}`;

    const rows = await this.query(sql, params);
    return rows;
  }

  async create({ data, include, select } = {}) {
    resetParams();
    const params = [];
    // Add updatedAt if not provided
    if (!data.updatedAt && !data.createdAt) {
      data = { ...data };
    }
    if (!data.id) {
      data = { ...data, id: require('crypto').randomUUID() };
    }
    const { cols, vals } = buildColumnsAndValues(data, params);
    if (cols.length === 0) throw new Error('No columns to insert');
    const sql = `INSERT INTO "${this.table}" (${cols.join(', ')}) VALUES (${vals.join(', ')}) RETURNING *`;
    const rows = await this.query(sql, params);
    return rows[0];
  }

  async update({ where, data } = {}) {
    resetParams();
    const params = [];
    // Only auto-update updatedAt for tables that have it (detected by checking if not already set)
    data = { ...data };
    const setClause = buildSetClause(data, params);
    const whereClause = buildConditions(where, params);
    if (!setClause) throw new Error('No data to update');
    let sql = `UPDATE "${this.table}" SET ${setClause}`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    sql += ' RETURNING *';
    const rows = await this.query(sql, params);
    return rows[0];
  }

  async updateMany({ where, data } = {}) {
    resetParams();
    const params = [];
    data = { ...data };
    const setClause = buildSetClause(data, params);
    const whereClause = buildConditions(where, params);
    if (!setClause) throw new Error('No data to update');
    let sql = `UPDATE "${this.table}" SET ${setClause}`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    const result = await this.client.query(sql, params);
    return { count: result.rowCount };
  }

  async delete({ where } = {}) {
    resetParams();
    const params = [];
    const whereClause = buildConditions(where, params);
    let sql = `DELETE FROM "${this.table}"`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    sql += ' RETURNING *';
    const rows = await this.query(sql, params);
    return rows[0];
  }

  async deleteMany({ where } = {}) {
    resetParams();
    const params = [];
    const whereClause = buildConditions(where, params);
    let sql = `DELETE FROM "${this.table}"`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    const result = await this.client.query(sql, params);
    return { count: result.rowCount };
  }

  async upsert({ where, create, update } = {}) {
    resetParams();
    const existing = await this.findFirst({ where });
    if (existing) {
      return this.update({ where, data: update });
    } else {
      const merged = { ...create };
      // Apply where conditions as fields
      for (const [k, v] of Object.entries(where)) {
        if (!merged[k]) merged[k] = v;
      }
      return this.create({ data: merged });
    }
  }

  async count({ where } = {}) {
    resetParams();
    const params = [];
    const whereClause = where ? buildConditions(where, params) : '';
    let sql = `SELECT COUNT(*) as cnt FROM "${this.table}"`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    const rows = await this.query(sql, params);
    return parseInt(rows[0]?.cnt ?? 0);
  }

  async aggregate({ where, _count, _sum, _avg, _min, _max } = {}) {
    resetParams();
    const params = [];
    const whereClause = where ? buildConditions(where, params) : '';
    const selects = ['COUNT(*) as _count_all'];
    if (_sum) for (const [k] of Object.entries(_sum)) selects.push(`SUM("${k}") as _sum_${k}`);
    if (_avg) for (const [k] of Object.entries(_avg)) selects.push(`AVG("${k}") as _avg_${k}`);
    if (_min) for (const [k] of Object.entries(_min)) selects.push(`MIN("${k}") as _min_${k}`);
    if (_max) for (const [k] of Object.entries(_max)) selects.push(`MAX("${k}") as _max_${k}`);
    let sql = `SELECT ${selects.join(', ')} FROM "${this.table}"`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    const rows = await this.query(sql, params);
    const r = rows[0] || {};
    return {
      _count: _count ? { _all: parseInt(r._count_all || 0) } : undefined,
      _sum: _sum ? Object.fromEntries(Object.keys(_sum).map(k => [k, r[`_sum_${k}`] ? parseFloat(r[`_sum_${k}`]) : null])) : undefined,
      _avg: _avg ? Object.fromEntries(Object.keys(_avg).map(k => [k, r[`_avg_${k}`] ? parseFloat(r[`_avg_${k}`]) : null])) : undefined,
      _min: _min ? Object.fromEntries(Object.keys(_min).map(k => [k, r[`_min_${k}`] ?? null])) : undefined,
      _max: _max ? Object.fromEntries(Object.keys(_max).map(k => [k, r[`_max_${k}`] ?? null])) : undefined,
    };
  }

  async groupBy({ by, where, having, _count, _sum, orderBy, take, skip } = {}) {
    resetParams();
    const params = [];
    const whereClause = where ? buildConditions(where, params) : '';
    const groupCols = by.map(b => col(b)).join(', ');
    const selects = [...by.map(b => col(b))];
    if (_count) selects.push('COUNT(*) as _count_all');
    if (_sum) for (const [k] of Object.entries(_sum)) selects.push(`SUM("${k}") as _sum_${k}`);
    let sql = `SELECT ${selects.join(', ')} FROM "${this.table}"`;
    if (whereClause) sql += ` WHERE ${whereClause}`;
    sql += ` GROUP BY ${groupCols}`;
    if (orderBy) sql += ` ${buildOrderBy(orderBy)}`;
    if (take) sql += ` LIMIT ${parseInt(take)}`;
    if (skip) sql += ` OFFSET ${parseInt(skip)}`;
    const rows = await this.query(sql, params);
    return rows.map(r => ({
      ...Object.fromEntries(by.map(b => [b, r[b]])),
      _count: _count ? { _all: parseInt(r._count_all || 0) } : undefined,
      _sum: _sum ? Object.fromEntries(Object.keys(_sum).map(k => [k, r[`_sum_${k}`] ? parseFloat(r[`_sum_${k}`]) : null])) : undefined,
    }));
  }
}

// ─── PrismaClient ────────────────────────────────────────────────────────────

class PrismaClient {
  constructor(options = {}) {
    this._options = options;
    this._pool = null;
    this._initModels();
  }

  _getPool() {
    if (!this._pool) {
      const url = process.env.DATABASE_URL;
      if (!url) throw new Error('DATABASE_URL environment variable not set');
      this._pool = new Pool({ connectionString: url, max: 10 });
    }
    return this._pool;
  }

  _initModels() {
    const self = this;
    const makeAccessor = (table) => new Proxy({}, {
      get(_, method) {
        return (...args) => {
          const accessor = new ModelAccessor(table, self._getPool());
          return accessor[method](...args);
        };
      }
    });

    this.user = makeAccessor('users');
    this.admin = makeAccessor('admins');
    this.doctor = makeAccessor('doctors');
    this.category = makeAccessor('categories');
    this.clinic = makeAccessor('clinics');
    this.doctorClinic = makeAccessor('doctor_clinics');
    this.doctorCategory = makeAccessor('doctor_categories');
    this.doctorAvailability = makeAccessor('doctor_availabilities');
    this.timeSlot = makeAccessor('time_slots');
    this.doctorVacation = makeAccessor('doctor_vacations');
    this.blockedDate = makeAccessor('blocked_dates');
    this.appointment = makeAccessor('appointments');
    this.appointmentStatusHistory = makeAccessor('appointment_status_history');
    this.review = makeAccessor('reviews');
    this.favorite = makeAccessor('favorites');
    this.notification = makeAccessor('notifications');
    this.doctorNotification = makeAccessor('doctor_notifications');
    this.otpCode = makeAccessor('otp_codes');
    this.refreshToken = makeAccessor('refresh_tokens');
    this.auditLog = makeAccessor('audit_logs');
    this.medicalRecord = makeAccessor('medical_records');
    this.appSetting = makeAccessor('app_settings');
  }

  async $connect() {
    // Pool connects lazily
    const pool = this._getPool();
    // Test connection
    const client = await pool.connect();
    client.release();
    console.log('✅ Database connected (pg pool)');
  }

  async $disconnect() {
    if (this._pool) {
      await this._pool.end();
      this._pool = null;
    }
  }

  async $transaction(fn, options) {
    if (Array.isArray(fn)) {
      // Batch mode
      const pool = this._getPool();
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const results = [];
        for (const op of fn) {
          results.push(await op);
        }
        await client.query('COMMIT');
        client.release();
        return results;
      } catch (e) {
        await client.query('ROLLBACK');
        client.release();
        throw e;
      }
    }
    // Callback mode
    const pool = this._getPool();
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      // Create a transaction-scoped prisma client
      const txClient = new PrismaClient(this._options);
      txClient._pool = { query: client.query.bind(client), connect: async () => ({ query: client.query.bind(client), release: () => {} }) };
      const result = await fn(txClient);
      await client.query('COMMIT');
      client.release();
      return result;
    } catch (e) {
      await client.query('ROLLBACK');
      client.release();
      throw e;
    }
  }

  async $queryRaw(sql, ...params) {
    const pool = this._getPool();
    const result = await pool.query(typeof sql === 'object' ? sql.strings.join('?') : sql, params);
    return result.rows;
  }

  async $executeRaw(sql, ...params) {
    const pool = this._getPool();
    const result = await pool.query(typeof sql === 'object' ? sql.strings.join('?') : sql, params);
    return result.rowCount;
  }
}

// ─── Prisma namespace (for error types) ─────────────────────────────────────

class PrismaClientKnownRequestError extends Error {
  constructor(message, { code, meta } = {}) {
    super(message);
    this.code = code;
    this.meta = meta;
    this.name = 'PrismaClientKnownRequestError';
  }
}

class PrismaClientValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'PrismaClientValidationError';
  }
}

const Prisma = {
  PrismaClientKnownRequestError,
  PrismaClientValidationError,
  Role, Gender, AppointmentStatus, DayOfWeek, NotificationChannel,
  NotificationType, SlotStatus, VerificationStatus, MedicalRecordType,
  sql: (strings, ...values) => ({ strings, values }),
  join: (arr, sep) => arr.join(sep ?? ', '),
  empty: { strings: [''], values: [] },
  raw: (str) => ({ strings: [str], values: [] }),
};

module.exports = {
  PrismaClient,
  Prisma,
  Role, Gender, AppointmentStatus, DayOfWeek, NotificationChannel,
  NotificationType, SlotStatus, VerificationStatus, MedicalRecordType,
  PrismaClientKnownRequestError,
  PrismaClientValidationError,
};
