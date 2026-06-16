import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

/**
 * Cliente Supabase con `service_role` para operaciones administrativas
 * (PRD §9.2): borrado de usuario en Auth y subida de fotos a Storage.
 * Si no hay credenciales configuradas, las operaciones fallan de forma controlada.
 */
@Injectable()
export class SupabaseService {
  private readonly logger = new Logger(SupabaseService.name);
  private client?: SupabaseClient;
  static readonly AVATAR_BUCKET = 'avatars';

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>('supabase.url');
    const serviceKey = this.config.get<string>('supabase.serviceRoleKey');
    if (url && serviceKey && !url.includes('YOUR-PROJECT')) {
      this.client = createClient(url, serviceKey, {
        auth: { autoRefreshToken: false, persistSession: false },
      });
    } else {
      this.logger.warn('Supabase no configurado: foto y borrado de cuenta estarán deshabilitados');
    }
  }

  private get admin(): SupabaseClient {
    if (!this.client) {
      throw new ServiceUnavailableException('Supabase no está configurado en este entorno');
    }
    return this.client;
  }

  get isConfigured(): boolean {
    return !!this.client;
  }

  /** Sube una foto de avatar y devuelve su URL pública. */
  async uploadAvatar(userId: string, file: Buffer, contentType: string): Promise<string> {
    const ext = contentType.split('/')[1] ?? 'jpg';
    const path = `${userId}/${Date.now()}.${ext}`;
    const { error } = await this.admin.storage
      .from(SupabaseService.AVATAR_BUCKET)
      .upload(path, file, { contentType, upsert: true });
    if (error) throw error;
    const { data } = this.admin.storage.from(SupabaseService.AVATAR_BUCKET).getPublicUrl(path);
    return data.publicUrl;
  }

  /** Borra el usuario en Supabase Auth (parte del borrado de cuenta, Ley 8968). */
  async deleteAuthUser(userId: string): Promise<void> {
    const { error } = await this.admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  }
}
