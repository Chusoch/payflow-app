import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import authRoutes from './routes/auth';
import walletRoutes from './routes/wallet';
import paymentRoutes, { RawBodyRequest } from './routes/payments';
import usersRoutes from './routes/users';
import transfersRoutes from './routes/transfers';
import vtpassRoutes from './routes/vtpass';
import devicesRoutes from './routes/devices';
import kycRoutes from './routes/kyc';
import { initBackendSentry, scrubSensitiveFields } from './utils/sentry';
import { config } from './config';

// Initialize Sentry with field-based beforeSend PII scrubber
initBackendSentry();

const app: Express = express();

// Security middleware
app.use(helmet());

// Strictly anchored regex for localhost & 127.0.0.1 on any port (http or https)
const DEV_LOCAL_ORIGIN_REGEX = /^https?:\/\/(localhost|127\.0\.0\.1):\d+$/;

app.use(
  cors({
    origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
      // Allow non-browser requests with no origin header (e.g. mobile apps, server-to-server, curl)
      if (!origin) {
        return callback(null, true);
      }

      // 1. Check explicit environment variable whitelist first (CORS_ALLOWED_ORIGINS)
      if (config.corsAllowedOrigins.length > 0 && config.corsAllowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      // 2. Check strictly anchored localhost / 127.0.0.1 pattern
      if (DEV_LOCAL_ORIGIN_REGEX.test(origin)) {
        return callback(null, true);
      }

      // Reject unauthorized origins
      return callback(null, false);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Idempotency-Key'],
  })
);

// Middleware to capture raw body buffer for HMAC verification on webhooks
app.use(
  express.json({
    verify: (req: RawBodyRequest, _res: Response, buf: Buffer) => {
      req.rawBody = buf;
    },
  })
);

app.use(express.urlencoded({ extended: true }));

// Health Check
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', service: 'payflow-backend-server', timestamp: new Date().toISOString() });
});

// Mount Feature Routers
app.use('/v1/auth', authRoutes);
app.use('/v1/wallet', walletRoutes);
app.use('/v1/payments', paymentRoutes);
app.use('/v1/users', usersRoutes);
app.use('/v1/user', usersRoutes);
app.use('/v1/transfers', transfersRoutes);
app.use('/v1/vtpass', vtpassRoutes);
app.use('/v1/devices', devicesRoutes);
app.use('/v1/kyc', kycRoutes);

// Global Error Handler
app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Unhandled server error:', err);
  res.status(500).json({ error: 'Internal Server Error', details: err?.message || 'Unknown error' });
});

export default app;
