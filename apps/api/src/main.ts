import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { requestLogger } from './common/middleware/request-logger';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Behind a load balancer the socket address is the balancer's. Without this every client shares
  // one rate-limit bucket (and one IP in logs). Set TRUST_PROXY to the number of proxies in front.
  const proxies = Number(process.env.TRUST_PROXY?.trim());
  if (proxies > 0) app.set('trust proxy', proxies);

  app.use(helmet());
  app.use(requestLogger());
  app.setGlobalPrefix('api/v1');
  // Blank CORS_ORIGIN= (as in .env.example) means "unset", not "allow nothing". Production
  // requires it to be set explicitly; see config/env.validation.ts.
  const corsOrigins = process.env.CORS_ORIGIN?.split(',').map((o) => o.trim()).filter(Boolean);
  app.enableCors({ origin: corsOrigins?.length ? corsOrigins : true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.useGlobalFilters(new AllExceptionsFilter());
  // Finish in-flight requests and close the database on SIGTERM (rolling deploys, autoscaling).
  app.enableShutdownHooks();
  await app.listen(process.env.PORT?.trim() || 4000);
}
bootstrap();
