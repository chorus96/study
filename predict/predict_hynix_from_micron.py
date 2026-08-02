#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
마이크론(MU) 주가로 SK하이닉스(000660) 주가를 예측하는 간단한 통계 모델.

■ 아이디어(왜 되는가)
  마이크론과 하이닉스는 같은 메모리 반도체(DRAM/NAND) 업종이라 주가 상관이 매우 높다.
  게다가 마이크론은 미국 시장에서 한국시간 '밤'에 거래를 마치므로, 하이닉스의 '다음
  거래일' 종가보다 먼저 정보를 준다. 이 시차(lead-lag)를 이용해
      하이닉스 당일 로그수익률  ~  마이크론 '전일' 로그수익률(들)
  을 선형회귀로 예측한다. (전일 이상만 쓰므로 미래참조(look-ahead)가 없다.)

■ 데이터(무료·무키)
  이미 배포된 대시보드의 공개 JSON(약 5년 일봉)을 그대로 사용한다:
      https://chorus96.github.io/study/micron/data.json
      https://chorus96.github.io/study/hynix/data.json
  형식: { "points": [ { "t": <unix초>, "c": <종가> }, ... ], ... }
  로컬 파일(위와 같은 형식)을 --micron/--hynix로 넘겨도 된다.

■ 실행
    python3 predict_hynix_from_micron.py                 # 대시보드 공개 데이터
    python3 predict_hynix_from_micron.py --lags 1 2      # 마이크론 1·2일 전 수익률 사용
    python3 predict_hynix_from_micron.py --micron mu.json --hynix hy.json

■ 주의
  학습·연구용 예시이며 투자 자문·매매 권유가 아니다. 과거 상관이 미래를 보장하지 않는다.
  일간 수익률 예측의 설명력(R²)은 원래 낮은 것이 정상이며, 방향 적중률이 50%를 크게
  웃돌기는 어렵다. 결과는 비판적으로 해석할 것.

의존성: 표준 라이브러리만 사용(numpy/pandas 불필요).
"""

import argparse
import datetime as dt
import json
import math
import sys
import urllib.request

DEFAULT_MU = "https://chorus96.github.io/study/micron/data.json"
DEFAULT_HY = "https://chorus96.github.io/study/hynix/data.json"


# ----------------------------- 데이터 로드 -----------------------------
def load_points(src):
    """URL 또는 로컬 경로에서 { 날짜(YYYY-MM-DD): 종가 } 딕셔너리를 만든다."""
    if src.startswith("http://") or src.startswith("https://"):
        with urllib.request.urlopen(src, timeout=30) as r:
            j = json.load(r)
    else:
        with open(src, encoding="utf-8") as f:
            j = json.load(f)
    out = {}
    for p in j.get("points", []):
        t, c = p.get("t"), p.get("c")
        try:
            t = int(t); c = float(c)
        except (TypeError, ValueError):
            continue
        if c > 0:
            d = dt.datetime.utcfromtimestamp(t).strftime("%Y-%m-%d")
            out[d] = c        # 같은 날짜면 마지막 값
    return out


# ----------------------------- 선형대수(소형) -----------------------------
def _solve(A, b):
    """정규방정식 A x = b 풀이(가우스 소거, 부분 피벗). A: n×n, b: n."""
    n = len(A)
    M = [list(A[i]) + [b[i]] for i in range(n)]
    for col in range(n):
        piv = max(range(col, n), key=lambda r: abs(M[r][col]))
        if abs(M[piv][col]) < 1e-12:
            raise ValueError("특이행렬(공선성) — 서로 다른 lag를 쓰세요")
        M[col], M[piv] = M[piv], M[col]
        pv = M[col][col]
        M[col] = [x / pv for x in M[col]]
        for r in range(n):
            if r != col and M[r][col] != 0.0:
                f = M[r][col]
                M[r] = [a - f * m for a, m in zip(M[r], M[col])]
    return [M[i][n] for i in range(n)]


def ols(X, y):
    """절편 포함 최소제곱. X: 행 리스트(각 행=특징들, 절편 제외). 반환: [절편, 계수...]."""
    Xi = [[1.0] + list(row) for row in X]
    k = len(Xi[0])
    XtX = [[sum(Xi[r][i] * Xi[r][j] for r in range(len(Xi))) for j in range(k)] for i in range(k)]
    Xty = [sum(Xi[r][i] * y[r] for r in range(len(Xi))) for i in range(k)]
    return _solve(XtX, Xty)


def predict(beta, X):
    return [beta[0] + sum(b * x for b, x in zip(beta[1:], row)) for row in X]


# ----------------------------- 지표 -----------------------------
def _mean(a):
    return sum(a) / len(a) if a else float("nan")


def pearson(a, b):
    n = len(a)
    if n < 2:
        return float("nan")
    ma, mb = _mean(a), _mean(b)
    cov = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    va = math.sqrt(sum((x - ma) ** 2 for x in a))
    vb = math.sqrt(sum((y - mb) ** 2 for y in b))
    return cov / (va * vb) if va > 0 and vb > 0 else float("nan")


def metrics(y, yhat):
    n = len(y)
    my = _mean(y)
    ss_res = sum((a - b) ** 2 for a, b in zip(y, yhat))
    ss_tot = sum((a - my) ** 2 for a in y)
    r2 = 1 - ss_res / ss_tot if ss_tot > 0 else float("nan")
    rmse = math.sqrt(ss_res / n) if n else float("nan")
    dir_acc = _mean([1.0 if (a >= 0) == (b >= 0) else 0.0 for a, b in zip(y, yhat)])
    return r2, rmse, dir_acc, pearson(y, yhat)


# ----------------------------- 데이터셋 구성 -----------------------------
def log_returns(closes):
    return [math.log(closes[i] / closes[i - 1]) for i in range(1, len(closes))]


def build(mu, hy, lags):
    """공통 날짜만 사용해 (X, y, 날짜, mu_ret, hy_ret, 종가들)을 만든다."""
    dates = sorted(set(mu) & set(hy))
    if len(dates) < 60:
        raise SystemExit("공통 거래일이 너무 적습니다(%d일). 데이터를 확인하세요." % len(dates))
    mu_c = [mu[d] for d in dates]
    hy_c = [hy[d] for d in dates]
    mu_ret = log_returns(mu_c)          # index i ↔ 날짜 dates[i+1]
    hy_ret = log_returns(hy_c)
    rdates = dates[1:]
    maxlag = max(lags)
    X, y, xd = [], [], []
    # 하이닉스[t] 예측에 마이크론[t-L] (L>=1) 수익률 사용 → 미래참조 없음
    for i in range(maxlag, len(hy_ret)):
        X.append([mu_ret[i - L] for L in lags])
        y.append(hy_ret[i])
        xd.append(rdates[i])
    return X, y, xd, mu_ret, hy_ret, hy_c, dates


# ----------------------------- 메인 -----------------------------
def fmt_krw(v):
    return "{:,.0f}원".format(v)


def main():
    ap = argparse.ArgumentParser(description="마이크론 주가로 하이닉스 주가 예측")
    ap.add_argument("--micron", default=DEFAULT_MU, help="마이크론 data.json URL/경로")
    ap.add_argument("--hynix", default=DEFAULT_HY, help="하이닉스 data.json URL/경로")
    ap.add_argument("--lags", type=int, nargs="+", default=[1],
                    help="사용할 마이크론 수익률 시차(일). 기본 1 (전일). 예: --lags 1 2")
    ap.add_argument("--test-frac", type=float, default=0.2, help="검증(테스트) 비율(뒤쪽)")
    args = ap.parse_args()

    if min(args.lags) < 1:
        sys.exit("오류: lag는 1 이상이어야 합니다(당일 마이크론 종가는 하이닉스 종가보다 늦어 사용 불가).")

    try:
        mu = load_points(args.micron)
        hy = load_points(args.hynix)
    except Exception as e:
        sys.exit("데이터 로드 실패: %s\n  (네트워크 차단 시 로컬 JSON 파일 경로를 --micron/--hynix로 넘기세요)" % e)

    common = sorted(set(mu) & set(hy))
    print("■ 데이터")
    print("  마이크론 %d일, 하이닉스 %d일, 공통 거래일 %d일 (%s ~ %s)"
          % (len(mu), len(hy), len(common), common[0], common[-1]))

    # 참고: 당일(동시점) 상관 — 예측용은 아니고 '얼마나 같이 움직이나' 설명용
    dts = common
    mu_r = log_returns([mu[d] for d in dts])
    hy_r = log_returns([hy[d] for d in dts])
    print("  참고) 당일 수익률 상관계수: %+.3f  (동시점, 예측엔 사용 불가)" % pearson(mu_r, hy_r))

    # 예측 모델
    X, y, xd, mu_ret, hy_ret, hy_c, dates = build(mu, hy, args.lags)
    n = len(y)
    ntr = max(30, int(n * (1 - args.test_frac)))
    Xtr, ytr, Xte, yte = X[:ntr], y[:ntr], X[ntr:], y[ntr:]
    beta = ols(Xtr, ytr)

    print("\n■ 모델:  하이닉스 당일 로그수익률  ~  마이크론 %s일 전 로그수익률" %
          "·".join(str(l) for l in args.lags))
    print("  절편 %+.5f" % beta[0])
    for L, b in zip(args.lags, beta[1:]):
        print("  마이크론 lag%d 계수 %+.4f   (마이크론이 1%% 오르면 하이닉스 %+.3f%% 방향)"
              % (L, b, b))
    print("\n■ 성능")
    print("  구간   R²      RMSE     방향적중   상관")
    for label, Xs, ys in (("학습", Xtr, ytr), ("검증", Xte, yte)):
        r2, rmse, da, corr = metrics(ys, predict(beta, Xs))
        print("  %-5s %+6.3f  %.4f   %5.1f%%   %+.3f" % (label, r2, rmse, da * 100, corr))
    # 베이스라인: 항상 '상승' 예측했을 때의 방향적중(=상승일 비율)
    up_rate = _mean([1.0 if v >= 0 else 0.0 for v in yte]) * 100
    print("  (베이스라인: 검증구간에서 '항상 상승' 시 방향적중 %.1f%%)" % up_rate)

    # 다음 거래일 예측 — 최신 마이크론 수익률(들)로
    last_feats = [mu_ret[len(mu_ret) - L] for L in args.lags]   # lag L → 최근에서 L번째
    pred_ret = predict(beta, [last_feats])[0]
    last_hy = hy_c[-1]
    last_date = dates[-1]
    pred_close = last_hy * math.exp(pred_ret)
    arrow = "▲ 상승" if pred_ret > 0 else ("▼ 하락" if pred_ret < 0 else "― 보합")
    print("\n■ 다음 하이닉스 거래일 예측  (기준일: %s)" % last_date)
    print("  최근 하이닉스 종가: %s" % fmt_krw(last_hy))
    print("  예상 수익률: %+.2f%%  →  %s" % (pred_ret * 100, arrow))
    print("  예상 종가:   %s" % fmt_krw(pred_close))

    print("\n※ 학습·연구용 예시입니다. 일간 예측의 설명력은 본래 낮으며(R²가 작은 것이 정상),")
    print("  방향적중이 베이스라인과 비슷하면 실질적 예측력이 거의 없다는 뜻입니다. 투자 판단은")
    print("  본인 책임이며, 본 결과는 매매 권유가 아닙니다.")


if __name__ == "__main__":
    main()
