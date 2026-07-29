#!/usr/bin/env bash
# SK하이닉스(000660) 일별 종가를 받아 same-origin data.json으로 저장한다.
# GitHub Actions 러너(외부망 개방)에서 실행된다. Yahoo Finance를 우선 사용하고
# 실패 시 Stooq CSV로 폴백한다.
set -euo pipefail

SYMBOL="${SYMBOL:-000660.KS}"
NAME="${NAME:-SK하이닉스}"
OUT="${OUT:-hynix-stock-analyzer/data.json}"
RANGE="${RANGE:-6mo}"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$(dirname "$OUT")"
tmp="$(mktemp)"
ok=0

# ---------- 1) Yahoo Finance ----------
for host in query1.finance.yahoo.com query2.finance.yahoo.com; do
  url="https://${host}/v8/finance/chart/${SYMBOL}?range=${RANGE}&interval=1d"
  if curl -sfL --max-time 30 -A "$UA" "$url" -o "$tmp"; then
    if jq -e '.chart.result[0].timestamp and .chart.result[0].indicators.quote[0].close' "$tmp" >/dev/null 2>&1; then
      jq --arg name "$NAME" --arg updated "$UPDATED" '
        .chart.result[0] as $r
        | { symbol: $r.meta.symbol, name: $name, currency: $r.meta.currency,
            price: $r.meta.regularMarketPrice, marketTime: $r.meta.regularMarketTime,
            updated: $updated,
            points: ([ $r.timestamp, $r.indicators.quote[0].close ]
                     | transpose | map(select(.[1] != null) | { t: .[0], c: .[1] })) }
      ' "$tmp" > "$OUT"
      ok=1; echo "출처: Yahoo Finance (${host})"; break
    fi
  fi
done

# ---------- 2) Stooq CSV 폴백 ----------
if [ "$ok" -ne 1 ]; then
  url="https://stooq.com/q/d/l/?s=000660.kr&i=d"
  if curl -sfL --max-time 30 -A "$UA" "$url" -o "$tmp" && head -1 "$tmp" | grep -qi "date"; then
    python3 - "$tmp" "$OUT" "$NAME" "$UPDATED" <<'PY'
import sys, json, csv, datetime
src, out, name, updated = sys.argv[1:5]
rows = []
with open(src, newline="") as f:
    for row in csv.DictReader(f):
        try:
            d = row["Date"]; c = float(row["Close"])
        except (KeyError, ValueError):
            continue
        t = int(datetime.datetime.strptime(d, "%Y-%m-%d")
                .replace(tzinfo=datetime.timezone.utc).timestamp())
        rows.append({"t": t, "c": c})
rows = rows[-140:]
if len(rows) < 5:
    sys.exit("Stooq: 데이터 부족")
data = {"symbol": "000660.KR", "name": name, "currency": "KRW",
        "price": rows[-1]["c"], "marketTime": rows[-1]["t"],
        "updated": updated, "points": rows}
with open(out, "w", encoding="utf-8") as g:
    json.dump(data, g, ensure_ascii=False)
PY
    ok=1; echo "출처: Stooq (폴백)"
  fi
fi

rm -f "$tmp"

if [ "$ok" -ne 1 ]; then
  echo "오류: 어떤 데이터 소스에서도 시세를 가져오지 못했습니다." >&2
  exit 1
fi

# 검증
jq -e '.points | length >= 5' "$OUT" >/dev/null || { echo "오류: 유효 포인트 부족" >&2; exit 1; }
echo "생성 완료: ${OUT}  포인트=$(jq '.points|length' "$OUT")  현재가=$(jq -r '.price' "$OUT")  갱신=${UPDATED}"
