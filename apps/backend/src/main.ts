import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  // Logger pino como logger de la app.
  app.useLogger(app.get(Logger));

  const apiPrefix = process.env.API_PREFIX ?? 'api/v1';
  app.setGlobalPrefix(apiPrefix);

  // Validación estricta de entrada (allowlist de campos) — PRD §16.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // CORS restringido (se endurece por ambiente en sprints posteriores).
  app.enableCors({ origin: true, credentials: true });

  const port = parseInt(process.env.PORT ?? '3000', 10);
  await app.listen(port);
  app.get(Logger).log(`Backend escuchando en http://localhost:${port}/${apiPrefix}`);
}

void bootstrap();
