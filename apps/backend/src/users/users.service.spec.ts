import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PlayerStatus } from '@prisma/client';
import { UsersService } from './users.service';

/** Mock mínimo de PrismaService con los métodos que toca UsersService. */
function makePrisma(overrides: any = {}) {
  return {
    profile: { findUnique: jest.fn().mockResolvedValue(null), upsert: jest.fn(), update: jest.fn() },
    player: {
      findUnique: jest.fn().mockResolvedValue(null),
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn(),
      update: jest.fn(),
    },
    $transaction: jest.fn(async (cb: any) => cb(makePrismaTx())),
    ...overrides,
  };
}

function makePrismaTx() {
  return {
    player: { create: jest.fn().mockResolvedValue({ id: 'p1' }), update: jest.fn() },
    profile: { update: jest.fn() },
    matchPlayer: { findMany: jest.fn().mockResolvedValue([]), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
    auditLog: { create: jest.fn() },
  };
}

const supabaseMock = { isConfigured: false, uploadAvatar: jest.fn(), deleteAuthUser: jest.fn() } as any;
const ratingQueueMock = { enqueueMatch: jest.fn(), enqueueRecompute: jest.fn() } as any;

describe('UsersService', () => {
  describe('completeOnboarding', () => {
    it('rechaza menores de 12 años', async () => {
      const prisma = makePrisma();
      const svc = new UsersService(prisma as any, supabaseMock, ratingQueueMock);
      const today = new Date().toISOString().slice(0, 10);
      await expect(
        svc.completeOnboarding('u1', { fullName: 'Niño', birthdate: today }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('uploadPhoto', () => {
    it('rechaza formatos no permitidos', async () => {
      const svc = new UsersService(makePrisma() as any, supabaseMock, ratingQueueMock);
      await expect(
        svc.uploadPhoto('u1', Buffer.from('x'), 'image/gif'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rechaza fotos de más de 5 MB', async () => {
      const svc = new UsersService(makePrisma() as any, supabaseMock, ratingQueueMock);
      const big = Buffer.alloc(5 * 1024 * 1024 + 1);
      await expect(svc.uploadPhoto('u1', big, 'image/png')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('claimGuest', () => {
    const myPlayerProfile = {
      player: { id: 'me', userId: 'u1', status: PlayerStatus.ACTIVE, fullName: 'Yo' },
    };

    it('falla si el invitado no existe', async () => {
      const prisma = makePrisma();
      prisma.profile.findUnique.mockResolvedValue(myPlayerProfile);
      prisma.player.findUnique.mockResolvedValue(null);
      const svc = new UsersService(prisma as any, supabaseMock, ratingQueueMock);
      await expect(svc.claimGuest('u1', 'guest1')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('falla si el jugador no es invitado reclamable', async () => {
      const prisma = makePrisma();
      prisma.profile.findUnique.mockResolvedValue(myPlayerProfile);
      prisma.player.findUnique.mockResolvedValue({
        id: 'guest1',
        status: PlayerStatus.ACTIVE,
        userId: 'otro',
      });
      const svc = new UsersService(prisma as any, supabaseMock, ratingQueueMock);
      await expect(svc.claimGuest('u1', 'guest1')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('createGuest', () => {
    it('crea el jugador con estado GUEST', async () => {
      const prisma = makePrisma();
      prisma.profile.findUnique.mockResolvedValue({ player: { id: 'me' } });
      prisma.player.create.mockResolvedValue({ id: 'g1', status: PlayerStatus.GUEST, fullName: 'Invitado' });
      const svc = new UsersService(prisma as any, supabaseMock, ratingQueueMock);
      await svc.createGuest('u1', { fullName: 'Invitado' });
      expect(prisma.player.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ status: PlayerStatus.GUEST }) }),
      );
    });
  });
});
