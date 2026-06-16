import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Analítica de producto (PostHog, PRD §15). Emisión server-side fiable.
 * Si no hay POSTHOG_API_KEY, es no-op (igual que FCM/Supabase en modo dev).
 */
@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);
  private readonly apiKey?: string;
  private readonly host: string;

  constructor(config: ConfigService) {
    this.apiKey = process.env.POSTHOG_API_KEY || undefined;
    this.host = process.env.POSTHOG_HOST || 'https://us.i.posthog.com';
  }

  capture(distinctId: string, event: string, properties: Record<string, unknown> = {}) {
    if (!this.apiKey) {
      this.logger.debug(`analytics no-op: ${event}`);
      return;
    }
    // Fire-and-forget; no bloquea la request.
    void fetch(`${this.host}/capture/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: this.apiKey,
        event,
        distinct_id: distinctId,
        properties,
      }),
    }).catch((err) => this.logger.warn(`PostHog falló: ${(err as Error).message}`));
  }
}
