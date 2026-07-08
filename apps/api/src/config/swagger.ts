import swaggerJsdoc from 'swagger-jsdoc';
import { env } from './env';

export const swaggerSpec = swaggerJsdoc({
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Doctor Booking System API',
      version: '1.0.0',
      description: 'Production-ready Doctor Appointment Booking Platform API',
      contact: { name: 'API Support', email: 'api@doctorbooking.com' },
    },
    servers: [
      { url: `http://localhost:${env.PORT}/api/${env.API_VERSION}`, description: 'Development' },
      { url: `https://api.doctorbooking.com/api/${env.API_VERSION}`, description: 'Production' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: ['./src/**/*.routes.ts'],
});
