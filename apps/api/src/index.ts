import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import swaggerUi from 'swagger-ui-express';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';

import { env } from './config/env';
import { prisma, connectDatabase, disconnectDatabase } from './config/database';
import { initializeFirebase } from './config/firebase';
import { initializeCloudinary } from './config/cloudinary';
import { swaggerSpec } from './config/swagger';
import { startScheduler, stopScheduler } from './jobs/scheduler';
import { errorHandler, notFoundHandler } from './common/middleware/errorHandler';
import { logger } from './common/utils/logger';

// Route imports
import authRoutes from './auth/auth.routes';
import doctorRoutes from './doctors/doctors.routes';
import appointmentRoutes from './appointments/appointments.routes';
import userRoutes from './users/users.routes';
import reviewRoutes from './reviews/reviews.routes';
import adminRoutes from './admin/admin.routes';

const app = express();
const server = http.createServer(app);

// ─── Socket.IO (for real-time slot updates) ──────────────────────────────────
const socketOrigins = env.CORS_ORIGINS.split(',').map(o => o.trim()).filter(Boolean);

export const io = new SocketIOServer(server, {
  cors: { origin: socketOrigins, credentials: true },
  path: '/socket.io',
});

io.on('connection', (socket) => {
  logger.debug(`Socket connected: ${socket.id}`);

  socket.on('join:doctor-slots', (data: { doctorId: string; date: string }) => {
    socket.join(`slots:${data.doctorId}:${data.date}`);
  });

  socket.on('disconnect', () => {
    logger.debug(`Socket disconnected: ${socket.id}`);
  });
});

// Trust Railway / reverse-proxy X-Forwarded-For so rate-limit sees real IPs
app.set("trust proxy", 1);

// ─── Security ────────────────────────────────────────────────────────────────
app.use(helmet());

const allowedOrigins = env.CORS_ORIGINS.split(',').map(o => o.trim()).filter(Boolean);
const isProduction = env.NODE_ENV === 'production';
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) return callback(null, true);
    // Allow any localhost origin in development (Flutter web dev server uses a random port)
    if (!isProduction && (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:'))) {
      return callback(null, true);
    }
    // Allow explicitly listed origins
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(null, false);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
// Respond to all OPTIONS preflight requests immediately
app.options('*', cors());

// ─── Rate Limiting ───────────────────────────────────────────────────────────
const globalLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX_REQUESTS,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'TOO_MANY_REQUESTS', message: 'Too many requests' } },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { success: false, error: { code: 'TOO_MANY_REQUESTS', message: 'Too many auth attempts' } },
});

if (env.NODE_ENV !== 'test') app.use(globalLimiter);

// ─── General Middleware ──────────────────────────────────────────────────────
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan(env.NODE_ENV === 'production' ? 'combined' : 'dev', {
  stream: { write: (msg) => logger.http(msg.trim()) },
}));

// ─── Health Check ────────────────────────────────────────────────────────────
const healthHandler = async (_req: any, res: any) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ status: 'ok', timestamp: new Date().toISOString(), version: env.API_VERSION });
  } catch (err) {
    logger.error('Health check failed:', err);
    res.status(503).json({ status: 'degraded', timestamp: new Date().toISOString(), version: env.API_VERSION });
  }
};
app.get('/health', healthHandler);
app.get('/api/v1/health', healthHandler);

// ─── API Routes ──────────────────────────────────────────────────────────────
const apiPrefix = `/api/${env.API_VERSION}`;

app.use(`${apiPrefix}/auth`, ...(env.NODE_ENV === 'test' ? [] : [authLimiter]), authRoutes);
app.use(`${apiPrefix}/doctors`, doctorRoutes);
app.use(`${apiPrefix}/appointments`, appointmentRoutes);
app.use(`${apiPrefix}/users`, userRoutes);
app.use(`${apiPrefix}/reviews`, reviewRoutes);
app.use(`${apiPrefix}/admin`, adminRoutes);

// ─── Swagger Docs ────────────────────────────────────────────────────────────
if (env.NODE_ENV !== 'production') {
  app.use(`${apiPrefix}/docs`, swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  logger.info(`Swagger docs: http://localhost:${env.PORT}${apiPrefix}/docs`);
}

// ─── Error Handling ──────────────────────────────────────────────────────────
app.use(notFoundHandler);
app.use(errorHandler);

// ─── Startup ─────────────────────────────────────────────────────────────────
async function bootstrap(): Promise<void> {
  await connectDatabase();
  logger.info('Database connected');

  initializeFirebase();
  initializeCloudinary();
  startScheduler();

  server.listen(env.PORT, () => {
    logger.info(`🚀 Server running on port ${env.PORT} [${env.NODE_ENV}]`);
  });
}

async function shutdown(): Promise<void> {
  logger.info('Shutting down...');
  stopScheduler();
  await disconnectDatabase();
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

bootstrap().catch((err) => {
  logger.error('Failed to start server:', err);
  process.exit(1);
});

export default app;
