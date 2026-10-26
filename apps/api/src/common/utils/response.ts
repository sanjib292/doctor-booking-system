import { Response } from 'express';

const SENSITIVE_KEYS = new Set(['passwordHash']);

function isPlainObject(value: object): boolean {
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

export function stripSensitive<T>(value: T): T {
  if (Array.isArray(value)) {
    return value.map((item) => stripSensitive(item)) as unknown as T;
  }
  if (value && typeof value === 'object' && isPlainObject(value)) {
    const out: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
      if (SENSITIVE_KEYS.has(key)) continue;
      out[key] = stripSensitive(val);
    }
    return out as T;
  }
  return value;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };
  meta?: Record<string, unknown>;
}

export function sendSuccess<T>(
  res: Response,
  data: T,
  message?: string,
  statusCode = 200,
  meta?: Record<string, unknown>,
): Response {
  return res.status(statusCode).json({
    success: true,
    message,
    data: stripSensitive(data),
    meta,
  } satisfies ApiResponse<T>);
}

export function sendCreated<T>(res: Response, data: T, message?: string): Response {
  return sendSuccess(res, data, message ?? 'Created successfully', 201);
}

export function sendError(
  res: Response,
  message: string,
  statusCode: number,
  code: string,
  details?: unknown,
): Response {
  return res.status(statusCode).json({
    success: false,
    error: { code, message, details },
  } satisfies ApiResponse);
}
