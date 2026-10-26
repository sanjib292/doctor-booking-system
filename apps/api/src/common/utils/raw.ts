import { prisma } from '../../config/database';

/**
 * Raw SQL helper.
 *
 * The runtime uses the pg-based Prisma shim, which accepts `(sql, ...params)`,
 * while Prisma's own typings only permit tagged templates. This wrapper keeps
 * the call-style usage working and contains the cast in one place.
 */
export function rawQuery<T = any>(sql: string, ...params: unknown[]): Promise<T> {
  return (prisma as unknown as {
    $queryRaw: (query: string, ...values: unknown[]) => Promise<T>;
  }).$queryRaw(sql, ...params);
}
