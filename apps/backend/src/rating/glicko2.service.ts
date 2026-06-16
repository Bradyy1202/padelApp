import { Injectable } from '@nestjs/common';

/** Estado de rating en unidades Glicko (rating ~1500, rd, volatilidad sigma). */
export interface GlickoState {
  rating: number;
  rd: number;
  sigma: number;
}

export interface Opponent {
  rating: number;
  rd: number;
}

// Constantes Glicko-2 (Glickman). PRD §12.
export const GLICKO = {
  DEFAULT_RATING: 1500,
  DEFAULT_RD: 350,
  DEFAULT_SIGMA: 0.06,
  TAU: 0.5, // restringe el cambio de volatilidad
  SCALE: 173.7178,
  // Mapeo a escala visible 1.0–7.0 y confidence.
  R_MIN: 1000,
  R_MAX: 2000,
  RD_MIN: 30,
  RD_MAX: 350,
  ESTABLISHED_CONFIDENCE: 50,
};

/**
 * Motor Glicko-2 (PRD §12). Servicio puro y determinista.
 * Para dobles, cada jugador se actualiza contra el equipo rival tratado como un
 * único oponente (rating = promedio, rd = RMS de los rd). El "score observado"
 * se modula con el margen de victoria (MOV) acotado.
 */
@Injectable()
export class Glicko2Service {
  /** Aplica un encuentro (un oponente, un score en [0,1]) y devuelve el nuevo estado. */
  update(player: GlickoState, opponent: Opponent, score: number): GlickoState {
    const mu = (player.rating - GLICKO.DEFAULT_RATING) / GLICKO.SCALE;
    const phi = player.rd / GLICKO.SCALE;
    const muJ = (opponent.rating - GLICKO.DEFAULT_RATING) / GLICKO.SCALE;
    const phiJ = opponent.rd / GLICKO.SCALE;

    const g = 1 / Math.sqrt(1 + (3 * phiJ * phiJ) / (Math.PI * Math.PI));
    const e = 1 / (1 + Math.exp(-g * (mu - muJ)));

    const v = 1 / (g * g * e * (1 - e));
    const delta = v * g * (score - e);

    const sigma = this.newSigma(phi, v, delta, player.sigma);
    const phiStar = Math.sqrt(phi * phi + sigma * sigma);
    const phiPrime = 1 / Math.sqrt(1 / (phiStar * phiStar) + 1 / v);
    const muPrime = mu + phiPrime * phiPrime * g * (score - e);

    return {
      rating: GLICKO.SCALE * muPrime + GLICKO.DEFAULT_RATING,
      rd: GLICKO.SCALE * phiPrime,
      sigma,
    };
  }

  /** Iteración (algoritmo de Illinois) para la nueva volatilidad. */
  private newSigma(phi: number, v: number, delta: number, sigma: number): number {
    const a = Math.log(sigma * sigma);
    const tau = GLICKO.TAU;
    const f = (x: number) => {
      const ex = Math.exp(x);
      const num = ex * (delta * delta - phi * phi - v - ex);
      const den = 2 * Math.pow(phi * phi + v + ex, 2);
      return num / den - (x - a) / (tau * tau);
    };

    let A = a;
    let B: number;
    if (delta * delta > phi * phi + v) {
      B = Math.log(delta * delta - phi * phi - v);
    } else {
      let k = 1;
      while (f(a - k * tau) < 0) k++;
      B = a - k * tau;
    }

    let fA = f(A);
    let fB = f(B);
    let iter = 0;
    while (Math.abs(B - A) > 1e-6 && iter < 100) {
      const C = A + ((A - B) * fA) / (fB - fA);
      const fC = f(C);
      if (fC * fB <= 0) {
        A = B;
        fA = fB;
      } else {
        fA = fA / 2;
      }
      B = C;
      fB = fC;
      iter++;
    }
    return Math.exp(A / 2);
  }

  /** Margen de victoria acotado [0.5, 1.0] para el ganador (PRD §12.4). */
  movScore(gamesDiff: number, totalGames: number, isWinner: boolean, k = 0.5): number {
    const ratio = totalGames > 0 ? gamesDiff / totalGames : 0;
    const winnerScore = Math.min(1, Math.max(0.5, 0.5 + k * ratio));
    return isWinner ? winnerScore : 1 - winnerScore;
  }

  /** Combina ratings de un equipo: rating = promedio, rd = RMS (PRD §12.3). */
  teamOpponent(members: Array<{ rating: number; rd: number }>): Opponent {
    const n = members.length || 1;
    const rating = members.reduce((s, m) => s + m.rating, 0) / n;
    const rd = Math.sqrt(members.reduce((s, m) => s + m.rd * m.rd, 0) / n);
    return { rating, rd };
  }

  /** Rating interno → escala visible 1.0–7.0. */
  toDisplay(rating: number): number {
    const d = 1 + ((rating - GLICKO.R_MIN) * 6) / (GLICKO.R_MAX - GLICKO.R_MIN);
    return Math.round(Math.min(7, Math.max(1, d)) * 10) / 10;
  }

  /** RD → confidence 0–100. */
  toConfidence(rd: number): number {
    const t = (rd - GLICKO.RD_MIN) / (GLICKO.RD_MAX - GLICKO.RD_MIN);
    const clamped = Math.min(1, Math.max(0, t));
    return Math.round(100 * (1 - clamped));
  }

  isEstablished(rd: number): boolean {
    return this.toConfidence(rd) >= GLICKO.ESTABLISHED_CONFIDENCE;
  }

  defaultState(): GlickoState {
    return {
      rating: GLICKO.DEFAULT_RATING,
      rd: GLICKO.DEFAULT_RD,
      sigma: GLICKO.DEFAULT_SIGMA,
    };
  }
}
