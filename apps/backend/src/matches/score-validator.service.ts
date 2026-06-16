import { BadRequestException, Injectable } from '@nestjs/common';

export interface SetScore {
  games1: number;
  games2: number;
  tiebreak1?: number | null;
  tiebreak2?: number | null;
}

export interface ScoreResult {
  winnerSide: 1 | 2;
  gamesDiff: number; // games del ganador − games del perdedor (positivo)
  setsWon: [number, number]; // [sets lado 1, sets lado 2]
}

/**
 * Validación de marcador de pádel (PRD §7.2). Servicio puro y testeable:
 * - Set: se gana con 6 games y diferencia ≥ 2; con 5-5 se va a 7 (7-5);
 *   a 6-6 se juega tie-break (7-6).
 * - Partido al mejor de 1 o 3 sets; rechaza marcadores imposibles
 *   (p.ej. 3 sets ganados por el mismo lado, o tres sets sin un 2-1).
 */
@Injectable()
export class ScoreValidatorService {
  validate(sets: SetScore[], bestOf: number): ScoreResult {
    if (bestOf !== 1 && bestOf !== 3) {
      throw new BadRequestException('bestOf debe ser 1 o 3');
    }
    if (!Array.isArray(sets) || sets.length === 0) {
      throw new BadRequestException('Debes registrar al menos un set');
    }

    const setsToWin = bestOf === 1 ? 1 : 2;
    const maxSets = bestOf === 1 ? 1 : 3;
    if (sets.length > maxSets) {
      throw new BadRequestException(`Demasiados sets para un partido al mejor de ${bestOf}`);
    }

    let won1 = 0;
    let won2 = 0;
    let games1 = 0;
    let games2 = 0;
    let decided = false;

    sets.forEach((s, idx) => {
      if (decided) {
        // Ya había un ganador del partido: no debería haber más sets.
        throw new BadRequestException('Hay sets de más: el partido ya estaba decidido');
      }
      const winner = this.validateSet(s, idx + 1);
      games1 += s.games1;
      games2 += s.games2;
      if (winner === 1) won1++;
      else won2++;
      if (won1 === setsToWin || won2 === setsToWin) decided = true;
    });

    if (won1 !== setsToWin && won2 !== setsToWin) {
      throw new BadRequestException('Ningún lado alcanzó los sets necesarios para ganar');
    }

    const winnerSide: 1 | 2 = won1 > won2 ? 1 : 2;
    const gamesDiff = Math.abs(games1 - games2);
    return { winnerSide, gamesDiff, setsWon: [won1, won2] };
  }

  /** Valida un set y devuelve el lado ganador (1 o 2). */
  private validateSet(s: SetScore, setNo: number): 1 | 2 {
    const { games1: a, games2: b } = s;
    if (!Number.isInteger(a) || !Number.isInteger(b) || a < 0 || b < 0) {
      throw new BadRequestException(`Set ${setNo}: games inválidos`);
    }
    if (a === b) {
      throw new BadRequestException(`Set ${setNo}: no puede terminar empatado (${a}-${b})`);
    }
    const high = Math.max(a, b);
    const low = Math.min(a, b);

    const valid =
      (high === 6 && low <= 4) || // 6-0 … 6-4
      (high === 7 && low === 5) || // 7-5
      (high === 7 && low === 6); // 7-6 (tie-break)

    if (!valid) {
      throw new BadRequestException(`Set ${setNo}: marcador imposible (${a}-${b})`);
    }

    // Si es 7-6, el tie-break (si se envía) debe ser coherente con el ganador del set.
    if (high === 7 && low === 6 && s.tiebreak1 != null && s.tiebreak2 != null) {
      const tbWinner = s.tiebreak1 > s.tiebreak2 ? 1 : 2;
      const setWinner = a > b ? 1 : 2;
      if (tbWinner !== setWinner) {
        throw new BadRequestException(`Set ${setNo}: el tie-break no coincide con el ganador`);
      }
    }

    return a > b ? 1 : 2;
  }
}
