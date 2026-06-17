import { Injectable } from '@nestjs/common';
import { PozoMode } from '@prisma/client';

export interface PozoParticipant {
  playerId: string;
  rating: number;
}

export interface PozoMatchup {
  court: number;
  side1: string[]; // playerIds
  side2: string[];
}

export interface GeneratedRound {
  matchups: PozoMatchup[];
  byes: string[]; // jugadores que descansan esta ronda
}

/**
 * Emparejamiento de pozos balanceado por rating (PRD §7.7). Servicio puro y testeable.
 * - FIXED_PAIRS: las parejas son fijas (participantes en orden, de dos en dos).
 * - ROTATION: cada ronda forma parejas balanceadas (fuerte+débil) variando por ronda.
 * En ambos modos, las parejas se cruzan minimizando la diferencia de rating combinado.
 */
@Injectable()
export class PozoPairingService {
  generateRound(
    participants: PozoParticipant[],
    mode: PozoMode,
    courts: number,
    roundNo: number,
  ): GeneratedRound {
    const pairs = this.formPairs(participants, mode, roundNo);

    // Nº impar de parejas → la de menor rating combinado descansa.
    const byes: string[] = [];
    let working = [...pairs];
    if (working.length % 2 === 1) {
      working.sort((a, b) => this.combined(a) - this.combined(b));
      const resting = working.shift()!;
      byes.push(...resting.map((p) => p.playerId));
    }

    // Cruzar parejas por rating combinado cercano.
    working.sort((a, b) => this.combined(a) - this.combined(b));
    const matchups: PozoMatchup[] = [];
    let court = 1;
    for (let i = 0; i + 1 < working.length; i += 2) {
      matchups.push({
        court: ((court - 1) % Math.max(1, courts)) + 1,
        side1: working[i].map((p) => p.playerId),
        side2: working[i + 1].map((p) => p.playerId),
      });
      court++;
    }
    return { matchups, byes };
  }

  /** Forma parejas según el modo. Devuelve arrays de participantes (1–2 por pareja). */
  private formPairs(
    participants: PozoParticipant[],
    mode: PozoMode,
    roundNo: number,
  ): PozoParticipant[][] {
    if (mode === PozoMode.FIXED_PAIRS) {
      const pairs: PozoParticipant[][] = [];
      for (let i = 0; i + 1 < participants.length; i += 2) {
        pairs.push([participants[i], participants[i + 1]]);
      }
      if (participants.length % 2 === 1) pairs.push([participants[participants.length - 1]]);
      return pairs;
    }

    // ROTATION: ordenar por rating desc, rotar según la ronda para variar compañeros,
    // y emparejar el mejor con el peor (parejas de fuerza similar).
    const sorted = [...participants].sort((a, b) => b.rating - a.rating);
    const n = sorted.length;
    const offset = roundNo % Math.max(1, n);
    const rotated = [...sorted.slice(offset), ...sorted.slice(0, offset)];

    const pairs: PozoParticipant[][] = [];
    let i = 0;
    let j = rotated.length - 1;
    while (i < j) {
      pairs.push([rotated[i], rotated[j]]);
      i++;
      j--;
    }
    if (i === j) pairs.push([rotated[i]]); // impar de jugadores → pareja de 1 (descansará)
    return pairs;
  }

  private combined(pair: PozoParticipant[]): number {
    return pair.reduce((s, p) => s + p.rating, 0);
  }
}
