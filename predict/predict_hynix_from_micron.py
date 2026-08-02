#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
마이크론(MU)·엔비디아(NVDA) '밤사이' 움직임으로 SK하이닉스(000660)를 예측한다.

■ 아이디어(왜 되는가)
  마이크론·엔비디아·하이닉스는 같은 반도체 업종이라 상관이 높다. 게다가 미국
  종목은 한국시간 '밤'에 장을 마치므로, 하이닉스의 '다음 거래일' 종가보다 정보가
  먼저 확정된다. 이 시차(lead-lag)를 이용해
      하이닉스 로그수익률  ~  '직전에 마감된' 미국 종목 로그수익률(마이크론·엔비디아)
  을 예측한다. 각 하이닉스 종가 시각 '직전'의 미국 종가만 쓰므로 미래참조가 없다.

■ 이 버전의 개선점
  1) 정밀 시점 정렬 : UTC 날짜로 묶지 않고, 각 하이닉스 종가 '직전'에 마감된 미국
     종가를 타임스탬프로 직접 찾는다(서머타임·휴장일에도 정확, look-ahead 제거).
  2) 선행지표 확대 : 마이크론에 더해 엔비디아 밤사이 수익률을 특징으로 추가.
  3) 방향 예측(로지스틱) : 수익률 크기 회귀(예상 종가용)와 별도로, 상승/하락 확률을
     로지스틱 회귀로 직접 예측한다. 특징 표준화 + 릿지(L2)로 안정화.
  4) 정직한 평가 : 단일 분할 대신 워크포워드(확장창) 표본외 검증, 그리고
     '항상 상승 / 하이닉스 모멘텀 / 미국 신호 그대로' 베이스라인과 비교한다.

■ 데이터(무료·무키) — 배포된 대시보드의 공개 JSON(약 5년 일봉)
      https://chorus96.github.io/study/hynix/data.json
      https://chorus96.github.io/study/micron/data.json
      https://chorus96.github.io/study/nvidia/data.json
  형식: { "points": [ { "t": <unix초>, "c": <종가> }, ... ] }
  같은 형식의 로컬 파일을 --hynix/--micron/--nvidia로 넘겨도 된다.

■ 실행
    python3 predict_hynix_from_micron.py
    python3 predict_hynix_from_micron.py --no-nvidia          # 마이크론만
    python3 predict_hynix_from_micron.py --hynix hy.json --micron mu.json --nvidia nv.json

■ 주의
  학습·연구용 예시이며 투자 자문·매매 권유가 아니다. 일간 예측의 설명력(R²)은 원래
  낮은 것이 정상이고, 표본외 방향적중이 베이스라인과 비슷하면 실질 예측력이 거의
  없다는 뜻이다. 결과는 비판적으로 해석할 것.

의존성: 표준 라이브러리만 사용(numpy/pandas 불필요).
"""

import argparse
import bisect
import datetime as dt
import json
import math
import sys
import urllib.request

DEFAULT_HY = "https://chorus96.github.io/study/hynix/data.json"
DEFAULT_MU = "https://chorus96.github.io/study/micron/data.json"
DEFAULT_NV = "https://chorus96.github.io/study/nvidia/data.json"


# ----------------------------- 데이터 로드 -----------------------------
def load_series(src):
    """URL/로컬 경로 → 타임스탬프 오름차순 [(t, c), ...] (t 중복 시 마지막 값)."""
    if src.startswith("http://") or src.startswith("https://"):
        with urllib.request.urlopen(src, timeout=30) as r:
            j = json.load(r)
    else:
        with open(src, encoding="utf-8") as f:
            j = json.load(f)
    m = {}
    for p in j.get("points", []):
        try:
            t = int(p.get("t")); c = float(p.get("c"))
        except (TypeError, ValueError):
            continue
        if c > 0:
            m[t] = c
    return sorted(m.items())


def last_before(series, ts, t):
    """series(오름차순 [(t,c)]) + 타임스탬프 ts에서 시각 t '미만' 중 가장 최근 종가."""
    i = bisect.bisect_left(ts, t)     # ts[i-1] < t <= ts[i]
    return series[i - 1][1] if i > 0 else None


# ----------------------------- 선형대수(소형) -----------------------------
def solve(A, b):
    """A x = b 풀이(가우스 소거, 부분 피벗). A: n×n, b: n."""
    n = len(A)
    M = [list(A[i]) + [b[i]] for i in range(n)]
    for col in range(n):
        piv = max(range(col, n), key=lambda r: abs(M[r][col]))
        if abs(M[piv][col]) < 1e-15:
            M[piv][col] = 1e-15
        M[col], M[piv] = M[piv], M[col]
        pv = M[col][col]
        M[col] = [x / pv for x in M[col]]
        for r in range(n):
            if r != col and M[r][col] != 0.0:
                f = M[r][col]
                M[r] = [a - f * m for a, m in zip(M[r], M[col])]
    return [M[i][n] for i in range(n)]


# ----------------------------- 표준화 -----------------------------
def fit_scaler(X):
    k = len(X[0])
    mu = [sum(r[j] for r in X) / len(X) for j in range(k)]
    sd = []
    for j in range(k):
        v = sum((r[j] - mu[j]) ** 2 for r in X) / len(X)
        sd.append(math.sqrt(v) or 1.0)
    return mu, sd


def apply_scaler(X, mu, sd):
    return [[(r[j] - mu[j]) / sd[j] for j in range(len(mu))] for r in X]


# ----------------------------- 모델 -----------------------------
def ols_ridge(Xs, y, lam):
    """절편 포함 릿지 최소제곱(절편은 벌점 제외). Xs: 표준화된 행렬. 반환 beta[0..k]."""
    Xi = [[1.0] + list(r) for r in Xs]
    k = len(Xi[0])
    XtX = [[sum(Xi[r][i] * Xi[r][j] for r in range(len(Xi))) for j in range(k)] for i in range(k)]
    for i in range(1, k):
        XtX[i][i] += lam
    Xty = [sum(Xi[r][i] * y[r] for r in range(len(Xi))) for i in range(k)]
    return solve(XtX, Xty)


def logistic_irls(Xs, y01, lam, iters=30):
    """절편 포함 로지스틱 회귀(IRLS, 릿지). 반환 gamma[0..k]."""
    Xi = [[1.0] + list(r) for r in Xs]
    n, k = len(Xi), len(Xi[0])
    g = [0.0] * k
    for _ in range(iters):
        XtWX = [[0.0] * k for _ in range(k)]
        XtWz = [0.0] * k
        for r in range(n):
            eta = sum(g[j] * Xi[r][j] for j in range(k))
            p = 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, eta))))
            w = max(p * (1 - p), 1e-6)
            z = eta + (y01[r] - p) / w
            for i in range(k):
                wi = w * Xi[r][i]
                XtWz[i] += wi * z
                for jj in range(k):
                    XtWX[i][jj] += wi * Xi[r][jj]
        for i in range(1, k):
            XtWX[i][i] += lam
        g_new = solve(XtWX, XtWz)
        if max(abs(a - b) for a, b in zip(g, g_new)) < 1e-8:
            g = g_new
            break
        g = g_new
    return g


def dot(beta, row):
    return beta[0] + sum(beta[i + 1] * row[i] for i in range(len(row)))


def sigmoid(x):
    return 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, x))))


# ----------------------------- 데이터셋 구성 -----------------------------
def build(hy, feeds):
    """정밀 정렬로 (X, y, dates, hy_close, prev_y)를 만든다.
    feeds: [(이름, series), ...]  각 series는 오름차순 [(t,c)].
    hy[i] 예측 특징 = 각 feed의 '직전 마감 종가' 로그수익률(hy 종가 사이 구간)."""
    tss = [[x[0] for x in s] for _, s in feeds]
    X, y, dates, hyc, prevy = [], [], [], [], []
    for i in range(1, len(hy)):
        t0, t1 = hy[i - 1][0], hy[i][0]
        feats, ok = [], True
        for (_, s), ts in zip(feeds, tss):
            a, b = last_before(s, ts, t0), last_before(s, ts, t1)
            if not a or not b or a <= 0 or b <= 0:
                ok = False
                break
            feats.append(math.log(b / a))
        if not ok:
            continue
        X.append(feats)
        y.append(math.log(hy[i][1] / hy[i - 1][1]))
        dates.append(dt.datetime.utcfromtimestamp(t1).strftime("%Y-%m-%d"))
        hyc.append(hy[i][1])
        prevy.append(y[-2] if len(y) >= 2 else 0.0)
    return X, y, dates, hyc, prevy


def next_features(hy, feeds):
    """다음(미공개) 하이닉스 종가 예측용 특징 — 지금까지 확정된 미국 종가 사용."""
    t_last = hy[-1][0]
    feats = []
    for _, s in feeds:
        ts = [x[0] for x in s]
        base = last_before(s, ts, t_last)     # 마지막 하이닉스 종가 직전 미국 종가
        latest = s[-1][1]                 # 현재까지 가장 최근 미국 종가
        if not base or base <= 0 or latest <= 0:
            return None
        feats.append(math.log(latest / base))
    return feats


# ----------------------------- 평가 -----------------------------
def walk_forward(X, y, prevy, lam, init, step):
    """확장창 워크포워드 표본외 예측 수집.
    반환 oos: [(yhat_ret, p_up, y_true, feat_mu, prev_y), ...]."""
    n = len(X)
    oos = []
    i = max(init, step)
    while i < n:
        Xtr, ytr = X[:i], y[:i]
        mu, sd = fit_scaler(Xtr)
        Xs = apply_scaler(Xtr, mu, sd)
        beta = ols_ridge(Xs, ytr, lam)
        y01 = [1.0 if v > 0 else 0.0 for v in ytr]
        gam = logistic_irls(Xs, y01, lam, 25)
        for j in range(i, min(i + step, n)):
            xs = apply_scaler([X[j]], mu, sd)[0]
            oos.append((dot(beta, xs), sigmoid(dot(gam, xs)), y[j], X[j][0], prevy[j]))
        i += step
    return oos


def summarize(oos):
    n = len(oos)
    yt = [o[2] for o in oos]
    my = sum(yt) / n
    ssr = sum((o[2] - o[0]) ** 2 for o in oos)
    sst = sum((v - my) ** 2 for v in yt)
    r2 = 1 - ssr / sst if sst > 0 else float("nan")
    rmse = math.sqrt(ssr / n)
    acc_logit = sum(1 for o in oos if (o[1] >= 0.5) == (o[2] > 0)) / n
    up_rate = sum(1 for o in oos if o[2] > 0) / n
    base_up = max(up_rate, 1 - up_rate)                       # '항상 같은 방향'
    base_mom = sum(1 for o in oos if (o[4] >= 0) == (o[2] > 0)) / n   # 하이닉스 모멘텀
    base_us = sum(1 for o in oos if (o[3] >= 0) == (o[2] > 0)) / n    # 미국 신호 그대로
    return dict(n=n, r2=r2, rmse=rmse, acc=acc_logit,
                base_up=base_up, base_mom=base_mom, base_us=base_us)


# ----------------------------- 메인 -----------------------------
def fmt_krw(v):
    return "{:,.0f}원".format(v)


def main():
    ap = argparse.ArgumentParser(description="마이크론·엔비디아로 하이닉스 예측")
    ap.add_argument("--hynix", default=DEFAULT_HY)
    ap.add_argument("--micron", default=DEFAULT_MU)
    ap.add_argument("--nvidia", default=DEFAULT_NV)
    ap.add_argument("--no-nvidia", action="store_true", help="엔비디아 특징 제외(마이크론만)")
    ap.add_argument("--lam", type=float, default=1.0, help="릿지(L2) 세기")
    ap.add_argument("--step", type=int, default=10, help="워크포워드 재학습 간격(일)")
    args = ap.parse_args()

    try:
        hy = load_series(args.hynix)
        feeds = [("마이크론", load_series(args.micron))]
        if not args.no_nvidia:
            try:
                feeds.append(("엔비디아", load_series(args.nvidia)))
            except Exception:
                print("  (엔비디아 데이터를 불러오지 못해 마이크론만 사용합니다)")
    except Exception as e:
        sys.exit("데이터 로드 실패: %s\n  (네트워크 차단 시 로컬 JSON 경로를 넘기세요)" % e)

    X, y, dates, hyc, prevy = build(hy, feeds)
    if len(X) < 120:
        sys.exit("표본이 너무 적습니다(%d일). 데이터를 확인하세요." % len(X))

    names = " · ".join(n for n, _ in feeds)
    print("■ 데이터")
    print("  하이닉스 %d일, 특징: %s" % (len(hy), names))
    print("  정밀 정렬 표본 %d일 (%s ~ %s)" % (len(X), dates[0], dates[-1]))

    # 전체 데이터로 최종 모델(다음 거래일 예측용)
    mu, sd = fit_scaler(X)
    Xs = apply_scaler(X, mu, sd)
    beta = ols_ridge(Xs, y, args.lam)
    gam = logistic_irls(Xs, [1.0 if v > 0 else 0.0 for v in y], args.lam, 30)

    print("\n■ 모델 계수(표준화 특징 기준)")
    print("  [수익률 회귀]  절편 %+.5f" % beta[0])
    for (nm, _), b in zip(feeds, beta[1:]):
        print("    %s 밤사이 수익률 계수 %+.4f" % (nm, b))
    print("  [방향 로지스틱] 절편 %+.4f" % gam[0])
    for (nm, _), g in zip(feeds, gam[1:]):
        print("    %s 계수 %+.4f" % (nm, g))

    # 워크포워드 표본외 평가
    init = max(120, int(len(X) * 0.5))
    oos = walk_forward(X, y, prevy, args.lam, init, args.step)
    s = summarize(oos)
    print("\n■ 표본외(워크포워드) 성능  — 표본 %d일" % s["n"])
    print("  방향적중(로지스틱)   %5.1f%%" % (s["acc"] * 100))
    print("  R²                   %+.3f" % s["r2"])
    print("  RMSE                 %.4f" % s["rmse"])
    print("  · 베이스라인 비교(방향적중)")
    print("      항상 같은 방향     %5.1f%%" % (s["base_up"] * 100))
    print("      하이닉스 모멘텀    %5.1f%%" % (s["base_mom"] * 100))
    print("      미국 신호 그대로   %5.1f%%" % (s["base_us"] * 100))
    edge = (s["acc"] - max(s["base_up"], s["base_mom"], s["base_us"])) * 100
    verdict = "베이스라인 대비 우위 있음" if edge > 1.0 else \
              ("사실상 베이스라인 수준(실질 예측력 미미)" if edge > -1.0 else "베이스라인보다 못함")
    print("  → 최고 베이스라인 대비 %+.1f%%p : %s" % (edge, verdict))

    # 다음 거래일 예측
    nf = next_features(hy, feeds)
    print("\n■ 다음 하이닉스 거래일 예측  (기준일: %s)" % dates[-1])
    if nf is None:
        print("  (미국 종가가 부족해 예측 특징을 만들 수 없습니다)")
    else:
        xs = apply_scaler([nf], mu, sd)[0]
        pred_ret = dot(beta, xs)
        p_up = sigmoid(dot(gam, xs))
        last_hy = hyc[-1]
        pred_close = last_hy * math.exp(pred_ret)
        arrow = "▲ 상승" if p_up >= 0.5 else "▼ 하락"
        print("  최근 하이닉스 종가: %s" % fmt_krw(last_hy))
        print("  상승 확률(로지스틱): %.1f%%  →  %s" % (p_up * 100, arrow))
        print("  예상 수익률(회귀):  %+.2f%%" % (pred_ret * 100))
        print("  예상 종가:          %s" % fmt_krw(pred_close))

    print("\n※ 학습·연구용 예시입니다. 일간 예측의 설명력은 본래 낮으며, 표본외 방향적중이")
    print("  베이스라인과 비슷하면 실질 예측력이 거의 없다는 뜻입니다. 투자 판단은 본인")
    print("  책임이며, 본 결과는 매매 권유가 아닙니다.")


if __name__ == "__main__":
    main()
