import jwt, { SignOptions } from 'jsonwebtoken';
import { randomUUID } from 'crypto';
import { env } from '../../config/env';
import { Role } from '@prisma/client';

export interface TokenPayload {
  id: string;
  role: Role;
  email?: string;
  phone?: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export function signAccessToken(payload: TokenPayload): string {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_EXPIRES_IN as SignOptions['expiresIn'],
    issuer: 'doctor-booking-api',
    audience: 'doctor-booking-client',
  });
}

export function signRefreshToken(payload: TokenPayload): string {
  return jwt.sign(payload, env.JWT_REFRESH_SECRET, {
    expiresIn: env.JWT_REFRESH_EXPIRES_IN as SignOptions['expiresIn'],
    issuer: 'doctor-booking-api',
    audience: 'doctor-booking-client',
    // Unique per token: two logins in the same second would otherwise produce an
    // identical JWT and collide on the UNIQUE refresh_tokens.token constraint.
    jwtid: randomUUID(),
  });
}

export function verifyAccessToken(token: string): TokenPayload {
  return jwt.verify(token, env.JWT_ACCESS_SECRET, {
    issuer: 'doctor-booking-api',
    audience: 'doctor-booking-client',
  }) as TokenPayload;
}

export function verifyRefreshToken(token: string): TokenPayload {
  return jwt.verify(token, env.JWT_REFRESH_SECRET, {
    issuer: 'doctor-booking-api',
    audience: 'doctor-booking-client',
  }) as TokenPayload;
}

export function generateTokenPair(payload: TokenPayload): TokenPair {
  return {
    accessToken: signAccessToken(payload),
    refreshToken: signRefreshToken(payload),
  };
}
