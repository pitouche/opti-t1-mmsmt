# T1 — hook mul_mat MTP-verify (anyei mmsmt)

**Verdict : NO-GO — rejeté, non déployé.**

## Question

Le PR anyei **mmsmt** ajoute un hook sur `mul_mat` pour le chemin MTP verify
(les n_max positions de verify sont des `mul_mat` batchés). Hypothèse : traiter
ce chemin de façon dédiée (batching des positions, pas de copie) doit accélérer
le decode MTP. À tester **sur le .so T3** (T1 est un additif, T3 reste la base FA).

## Résultats (`t1_bench.py`, MTP ON config prod, -b 2048, ctx 167k, 2 reps interleave, .so T3)

| ctx | A-t3 (base) | B-t1t3 (T1+T3) | C-smt0 (T1 désactivé) | Δ B vs A |
|---|---|---|---|---|
| 114 688 | 45,73 t/s | 45,91 t/s | 45,70 t/s | **+0,35 %** |
| 160 000 | 40,85 t/s | 36,23 t/s | 40,86 t/s | **−11,30 %** |

Lecture :
- **Court ctx (114 k)** : T1 est **neutre** (le +0,35 % est du bruit) — le hook
  n'apporte rien sur la shape dominante.
- **Long ctx (160 k)** : T1 est **régressif de −11,3 %** — le coût du hook
  (ou du chemin batché) pèse au long ctx.
- Le leg C-smt0 confirme que T3 seul = base (aucun résidu de l'infra T1).
- Prefill identique partout (~610 / ~370 t/s) → T1 ne touche pas le prefill (attendu).

## Décision

**NO-GO.** Pas de gain sur la shape dominante, régression sur le long ctx, et le
bench e2e MTP ON à 160 k est déjà à la limite du fit (167 k) → pas de marge pour
négocier. Le hook mmsmt est **rejeté** ; le .so prod T3 (puis +vldg, +FA16) ne le
contient pas.

## Contenu

```
src/   # mmsmt.cu / mmsmt.cuh (le hook) + ggml-cuda.cu.t1 (branch T1) + ggml-cuda.cu.t1t3 (branch T1+T3) + build_t1.sh
results/  # t1_bench_summary.md + t1_bench_results.jsonl + t1_bench_gputimes.tsv
bench/  # t1_bench.py, t1_h2_bench.py, gguf_mtp_probe.py
```

## `.so` associés

| md5 | état |
|---|---|
| `d2df07b8` | T3 seul (leg A/C de référence) |
| `ecc70a9f` | T1 seul (diagnostic) |
| `04f41b70` | T1+T3 (leg B) — **le rejet** |

## Re-validation

`python3 bench/bench/supervisor_bench.py run bench/t1_bench.py --detach`
→ 3 legs × 2 reps × 2 ctx, ~40 min. Comparer à `results/t1_bench_results.jsonl`
(A-t3 ≈ 45,7 / 40,85 ; B-t1t3 ≈ 45,9 / 36,2 ; C-smt0 ≈ 45,7 / 40,85).
Le delta B vs A est le critère : > +5 % e2e pour être GO, ici −11 % @160 k.

## Caveats

- Mesuré MTP ON (c'est le seul mode où T1 a un effet). La comparaison T3 seul
  comme base isole l'effet T1.
- 2 reps par leg (le long ctx est cher) ; le −11,3 % est loin du bruit (±2 %).
- Le port mmsmt n'était pas sur base T3+FA16 (fa16 arrive le 31/10) ; si un jour
  on ré-essaie, ré-appliquer sur la base prod actuelle.
