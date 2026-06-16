import { BadRequestException } from '@nestjs/common';
import { ScoreValidatorService } from './score-validator.service';

describe('ScoreValidatorService', () => {
  const svc = new ScoreValidatorService();

  describe('partidos válidos', () => {
    it('best of 3: 2-1 en sets, gana lado 1', () => {
      const r = svc.validate(
        [
          { games1: 6, games2: 3 },
          { games1: 4, games2: 6 },
          { games1: 7, games2: 5 },
        ],
        3,
      );
      expect(r.winnerSide).toBe(1);
      expect(r.setsWon).toEqual([2, 1]);
      expect(r.gamesDiff).toBe(Math.abs(17 - 14));
    });

    it('best of 3: 2-0, gana lado 2', () => {
      const r = svc.validate(
        [
          { games1: 4, games2: 6 },
          { games1: 6, games2: 7, tiebreak1: 5, tiebreak2: 7 },
        ],
        3,
      );
      expect(r.winnerSide).toBe(2);
      expect(r.setsWon).toEqual([0, 2]);
    });

    it('best of 1: un solo set 6-4', () => {
      const r = svc.validate([{ games1: 6, games2: 4 }], 1);
      expect(r.winnerSide).toBe(1);
    });

    it('acepta 7-6 con tie-break', () => {
      const r = svc.validate(
        [
          { games1: 7, games2: 6, tiebreak1: 7, tiebreak2: 4 },
          { games1: 6, games2: 2 },
        ],
        3,
      );
      expect(r.winnerSide).toBe(1);
    });
  });

  describe('marcadores inválidos', () => {
    it('rechaza set 6-5', () => {
      expect(() => svc.validate([{ games1: 6, games2: 5 }], 1)).toThrow(BadRequestException);
    });

    it('rechaza set 8-6', () => {
      expect(() => svc.validate([{ games1: 8, games2: 6 }], 1)).toThrow(BadRequestException);
    });

    it('rechaza set empatado 6-6', () => {
      expect(() => svc.validate([{ games1: 6, games2: 6 }], 1)).toThrow(BadRequestException);
    });

    it('rechaza 6-4,6-4,6-4 (sets de más en best of 3)', () => {
      expect(() =>
        svc.validate(
          [
            { games1: 6, games2: 4 },
            { games1: 6, games2: 4 },
            { games1: 6, games2: 4 },
          ],
          3,
        ),
      ).toThrow(BadRequestException);
    });

    it('rechaza best of 3 sin un ganador (1-1)', () => {
      expect(() =>
        svc.validate(
          [
            { games1: 6, games2: 4 },
            { games1: 4, games2: 6 },
          ],
          3,
        ),
      ).toThrow(BadRequestException);
    });

    it('rechaza tie-break incoherente con el ganador del set', () => {
      expect(() =>
        svc.validate([{ games1: 7, games2: 6, tiebreak1: 3, tiebreak2: 7 }], 1),
      ).toThrow(BadRequestException);
    });

    it('rechaza bestOf inválido', () => {
      expect(() => svc.validate([{ games1: 6, games2: 0 }], 5)).toThrow(BadRequestException);
    });
  });
});
