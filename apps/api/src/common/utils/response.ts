import { Response } from 'express';

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
    data,
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
