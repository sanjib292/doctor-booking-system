import bcrypt from 'bcryptjs';
import { randomInt } from 'crypto';

const SALT_ROUNDS = 12;

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export async function comparePassword(plain: string, hashed: string): Promise<boolean> {
  return bcrypt.compare(plain, hashed);
}

export function generateOtp(length = 6): string {
  const min = Math.pow(10, length - 1);
  const max = Math.pow(10, length);
  return randomInt(min, max).toString();
}
