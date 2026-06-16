import { IsEnum, IsString, MinLength } from 'class-validator';
import { DevicePlatform } from '@prisma/client';

/** Registrar/actualizar el token FCM del dispositivo (PRD §11.6 POST /devices). */
export class RegisterDeviceDto {
  @IsString()
  @MinLength(10)
  fcmToken!: string;

  @IsEnum(DevicePlatform)
  platform!: DevicePlatform;
}
