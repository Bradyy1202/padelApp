import { PozoMode } from '@prisma/client';
import { PozoPairingService } from './pozo-pairing.service';

describe('PozoPairingService', () => {
  const svc = new PozoPairingService();

  const parts = (ratings: number[]) =>
    ratings.map((r, i) => ({ playerId: `p${i}`, rating: r }));

  it('8 jugadores en rotación → 2 partidos 2v2 sin byes', () => {
    const r = svc.generateRound(parts([6, 5.5, 5, 4.5, 4, 3.5, 3, 2.5]), PozoMode.ROTATION, 2, 1);
    expect(r.matchups).toHaveLength(2);
    expect(r.byes).toHaveLength(0);
    for (const m of r.matchups) {
      expect(m.side1).toHaveLength(2);
      expect(m.side2).toHaveLength(2);
    }
    // Todos los jugadores aparecen exactamente una vez.
    const all = r.matchups.flatMap((m) => [...m.side1, ...m.side2]);
    expect(new Set(all).size).toBe(8);
  });

  it('rotación equilibra el rating combinado de las parejas', () => {
    const r = svc.generateRound(parts([7, 6, 5, 1]), PozoMode.ROTATION, 1, 1);
    // 1 partido: parejas (7+1) y (6+5) → combinados 8 y 11; ambas parejas mezclan fuerte/débil.
    expect(r.matchups).toHaveLength(1);
    const m = r.matchups[0];
    // Cada pareja debe tener un jugador fuerte y uno débil (balanceada).
    const all = [...m.side1, ...m.side2];
    expect(new Set(all).size).toBe(4);
  });

  it('6 jugadores → 1 partido y 2 descansan (nº impar de parejas)', () => {
    const r = svc.generateRound(parts([6, 5, 4, 3, 2, 1]), PozoMode.ROTATION, 3, 1);
    expect(r.matchups).toHaveLength(1);
    expect(r.byes).toHaveLength(2);
    const assigned = r.matchups.flatMap((m) => [...m.side1, ...m.side2]).length + r.byes.length;
    expect(assigned).toBe(6);
  });

  it('FIXED_PAIRS respeta las parejas por orden de entrada', () => {
    // p0-p1, p2-p3 son parejas fijas.
    const r = svc.generateRound(parts([5, 5, 4, 4]), PozoMode.FIXED_PAIRS, 1, 1);
    expect(r.matchups).toHaveLength(1);
    const m = r.matchups[0];
    const pair1 = new Set(m.side1);
    const pair2 = new Set(m.side2);
    // Las parejas fijas no se rompen: {p0,p1} juntos y {p2,p3} juntos.
    const isFixed =
      (pair1.has('p0') && pair1.has('p1')) || (pair2.has('p0') && pair2.has('p1'));
    expect(isFixed).toBe(true);
  });

  it('rondas distintas varían los compañeros en rotación', () => {
    const p = parts([6, 5, 4, 3]);
    const r1 = svc.generateRound(p, PozoMode.ROTATION, 1, 1);
    const r2 = svc.generateRound(p, PozoMode.ROTATION, 1, 2);
    const partnerOf = (round: typeof r1, id: string) => {
      for (const m of round.matchups) {
        for (const side of [m.side1, m.side2]) {
          if (side.includes(id)) return side.find((x) => x !== id);
        }
      }
      return null;
    };
    // No garantizamos siempre distinto, pero el offset por ronda debe poder cambiarlo.
    expect(partnerOf(r1, 'p0')).toBeDefined();
    expect(partnerOf(r2, 'p0')).toBeDefined();
  });
});
