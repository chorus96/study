#!/usr/bin/env bash
# 종목 재무지표(현재는 PER 일별 추이)를 받아 same-origin fundamentals.json 으로 저장한다.
# 국내(KRX)는 pykrx(무키)로 일별 PER 시계열을 받는다.
# 미국(US)은 무료 소스에 과거 PER 시계열이 없어 생략한다(파일 미생성 → 앱이 안내 표시).
# 실패해도 배포를 막지 않도록 항상 exit 0.
set -uo pipefail

OUT="${OUT:-stock-analyzer/hynix/fundamentals.json}"
NUMCODE="${NUMCODE:-000660}"
NAME="${NAME:-SK하이닉스}"
MARKET="${MARKET:-krx}"
CURRENCY="${CURRENCY:-KRW}"
UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$(dirname "$OUT")"

if [ "$MARKET" != "krx" ]; then
  echo "재무지표: 미국 종목(${NAME})은 무료 PER 시계열 소스가 없어 생략" >&2
  exit 0
fi

echo "재무지표(PER) 수집 시작 (code=${NUMCODE})"
if ! python3 -m pip install --quiet --disable-pip-version-check pykrx >/tmp/pip_fund.log 2>&1; then
  echo "  · pykrx 설치 실패: $(tail -1 /tmp/pip_fund.log 2>/dev/null)" >&2; exit 0
fi

python3 - "$OUT" "$NAME" "$UPDATED" "$NUMCODE" "$CURRENCY" <<'PY' || { echo "  · PER 수집 실패" >&2; exit 0; }
import sys, json, datetime, time
out, name, updated, code, currency = sys.argv[1:6]
try:
    from pykrx import stock
except Exception as e:
    sys.exit("pykrx import 실패: %s" % e)
end = datetime.datetime.now()
start = end - datetime.timedelta(days=400)
s, e = start.strftime("%Y%m%d"), end.strftime("%Y%m%d")

# KRX 재무 엔드포인트는 시세 조회 직후 호출하면 빈 응답(rate-limit)을 주는 경우가
# 있어, 잠깐 쉬고 여러 번 재시도한다. (컬럼: BPS, PER, PBR, EPS, DIV, DPS)
df = None
for attempt in range(1, 6):
    time.sleep(2 if attempt == 1 else 3)
    try:
        d = stock.get_market_fundamental(s, e, code)
    except Exception as ex:
        sys.stderr.write("  · PER 시도 %d 오류: %s\n" % (attempt, ex))
        continue
    if d is not None and not d.empty and "PER" in d.columns:
        df = d
        sys.stderr.write("  · PER 시도 %d 성공\n" % attempt)
        break
    sys.stderr.write("  · PER 시도 %d 빈 응답\n" % attempt)
if df is None or df.empty or "PER" not in df.columns:
    sys.exit("PER 데이터 없음(재시도 소진)")
pts = []
for idx, row in df.iterrows():
    d = idx.to_pydatetime().replace(tzinfo=datetime.timezone.utc)
    try:
        per = float(row["PER"])
    except (TypeError, ValueError):
        continue
    if per and per > 0:                       # 적자(PER 0/음수) 구간은 제외
        pts.append({"t": int(d.timestamp()), "v": round(per, 2)})
pts = pts[-260:]
if len(pts) < 5:
    sys.exit("PER 유효 포인트 부족")
data = {"code": code, "name": name, "currency": currency, "updated": updated,
        "per": {"points": pts, "current": pts[-1]["v"]}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print("PER 수집 완료:", len(pts), "포인트 · 현재 PER", pts[-1]["v"])
PY
