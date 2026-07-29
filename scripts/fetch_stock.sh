#!/usr/bin/env bash
# 종목 일별 종가를 받아 same-origin data.json으로 저장한다. 국내(KRX)·미국(US)
# 종목을 모두 지원한다. GitHub Actions 러너에서 실행되며 여러 소스를 순서대로
# 시도하고, 각 시도의 HTTP 상태를 로그로 남긴다. (진단 가능하도록 -e 미사용)
#
# 시장별 소스:
#   krx: Yahoo → Stooq(.kr) → pykrx(KRX 공식, 무키) → TwelveData/FMP(선택)
#   us : Yahoo → Stooq(.us, 무키) → TwelveData/FMP(선택)   ※ pykrx 제외
set -uo pipefail

SYMBOL="${SYMBOL:-000660.KS}"          # Yahoo 형식(예: 000660.KS, NVDA)
NUMCODE="${NUMCODE:-000660}"           # 코드/티커(예: 000660, NVDA)
NAME="${NAME:-SK하이닉스}"
OUT="${OUT:-stock-analyzer/hynix/data.json}"
RANGE="${RANGE:-1y}"
MARKET="${MARKET:-krx}"                # krx | us
CURRENCY="${CURRENCY:-KRW}"            # KRW | USD
STOOQ_S="${STOOQ_S:-${NUMCODE}.kr}"    # Stooq 심볼(국내 ${코드}.kr, 미국 ${티커}.us)
SYMLABEL="${SYMLABEL:-$SYMBOL}"        # data.json 에 기록할 심볼 표기
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$(dirname "$OUT")"
tmp="$(mktemp)"
ok=0

# curl 래퍼: HTTP 코드를 stdout으로 반환하고, 본문은 $tmp에 저장. 진단 로그 출력.
fetch() { # $1=label $2=url [$3..=extra curl args]
  local label="$1" url="$2"; shift 2
  local code
  code=$(curl -sS -m 30 -A "$UA" -H "Accept: application/json, text/csv, */*" \
              -w '%{http_code}' -o "$tmp" "$@" "$url" 2>/tmp/curl_err || true)
  [ -z "$code" ] && code="000"
  # 진단은 stderr로(=로그에만), 반환값(HTTP코드)만 stdout으로.
  echo "  · ${label}: HTTP ${code}, $(wc -c <"$tmp" 2>/dev/null || echo 0) bytes $( [ -s /tmp/curl_err ] && echo "($(tr '\n' ' ' </tmp/curl_err | cut -c1-100))" )" >&2
  printf '%s' "$code"
}

echo "데이터 수집 시작 (symbol=${SYMBOL}, code=${NUMCODE})"

# ---------- 1) Yahoo Finance ----------
# Yahoo는 GitHub Actions(Azure) IP에 429(rate-limit)를 자주 주지만 간헐적으로 통과한다.
# 미국 종목은 무키로 쓸 다른 소스가 없어, 통과할 때까지 여러 번 재시도한다.
# 국내(KRX) 종목은 pykrx가 안정적이므로 Yahoo를 건너뛰어 US용 rate 여유를 남긴다.
# 단, TwelveData/FMP 무료 키가 있으면 그쪽이 안정적이므로 Yahoo 재시도를 줄여
# 빠르게 키 소스로 넘어간다(빌드 단축·Yahoo 부하 감소).
if [ "$MARKET" != "krx" ]; then
  if [ -n "${TWELVEDATA_API_KEY:-}" ] || [ -n "${FMP_API_KEY:-}" ]; then
    attempts="${YAHOO_ATTEMPTS:-1}"
  else
    attempts="${YAHOO_ATTEMPTS:-6}"
  fi
  for try in $(seq 1 "$attempts"); do
    [ "$ok" -eq 1 ] && break
    for host in query1.finance.yahoo.com query2.finance.yahoo.com; do
      code=$(fetch "Yahoo(${host}) #${try}" "https://${host}/v8/finance/chart/${SYMBOL}?range=${RANGE}&interval=1d")
      if [ "$code" = "200" ] && jq -e '.chart.result[0].timestamp and .chart.result[0].indicators.quote[0].close' "$tmp" >/dev/null 2>&1; then
        jq --arg name "$NAME" --arg updated "$UPDATED" '
          .chart.result[0] as $r
          | { symbol: $r.meta.symbol, name: $name, currency: $r.meta.currency,
              price: $r.meta.regularMarketPrice, marketTime: $r.meta.regularMarketTime, updated: $updated,
              points: ([ $r.timestamp, $r.indicators.quote[0].close ]
                       | transpose | map(select(.[1] != null) | { t: .[0], c: .[1] })) }' "$tmp" > "$OUT"
        ok=1; echo "→ 성공: Yahoo Finance (${host}, 시도 ${try})"; break
      fi
    done
    [ "$ok" -ne 1 ] && [ "$try" -lt "$attempts" ] && sleep 4
  done
fi

# ---------- 2) Stooq CSV (국내 .kr / 미국 .us, 무키) ----------
if [ "$ok" -ne 1 ]; then
  code=$(fetch "Stooq(${STOOQ_S})" "https://stooq.com/q/d/l/?s=${STOOQ_S}&i=d")
  if [ "$code" = "200" ] && head -1 "$tmp" | grep -qi "date"; then
    if python3 - "$tmp" "$OUT" "$NAME" "$UPDATED" "$SYMLABEL" "$CURRENCY" <<'PY'
import sys, json, csv, datetime
src, out, name, updated, symbol, currency = sys.argv[1:7]
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
rows = rows[-260:]
if len(rows) < 5:
    sys.exit("Stooq: 데이터 부족")
json.dump({"symbol": symbol, "name": name, "currency": currency,
           "price": rows[-1]["c"], "marketTime": rows[-1]["t"],
           "updated": updated, "points": rows},
          open(out, "w", encoding="utf-8"), ensure_ascii=False)
print("  Stooq rows:", len(rows))
PY
    then ok=1; echo "→ 성공: Stooq (${STOOQ_S})"; fi
  fi
fi

# ---------- 3) pykrx (KRX 공식 데이터, API 키 불필요) — 국내 종목만 ----------
if [ "$ok" -ne 1 ] && [ "$MARKET" = "krx" ]; then
  echo "  · pykrx: 설치 및 조회 시도..." >&2
  if python3 -m pip install --quiet --disable-pip-version-check pykrx >/tmp/pip.log 2>&1; then
    if python3 - "$OUT" "$NAME" "$UPDATED" "$NUMCODE" <<'PY'
import sys, json, datetime
out, name, updated, numcode = sys.argv[1:5]
try:
    from pykrx import stock
except Exception as e:
    sys.exit("pykrx import 실패: %s" % e)
end = datetime.datetime.now()
start = end - datetime.timedelta(days=400)
df = stock.get_market_ohlcv(start.strftime("%Y%m%d"), end.strftime("%Y%m%d"), numcode)
if df is None or df.empty:
    sys.exit("pykrx: 빈 데이터")
points = []
for idx, row in df.iterrows():
    d = idx.to_pydatetime().replace(tzinfo=datetime.timezone.utc)
    c = float(row["종가"])
    if c > 0:
        points.append({"t": int(d.timestamp()), "c": c})
points = points[-260:]
if len(points) < 5:
    sys.exit("pykrx: 데이터 부족")
json.dump({"symbol": numcode + ".KS", "name": name, "currency": "KRW",
           "price": points[-1]["c"], "marketTime": points[-1]["t"],
           "updated": updated, "points": points},
          open(out, "w", encoding="utf-8"), ensure_ascii=False)
print("  pykrx rows:", len(points))
PY
    then ok=1; echo "→ 성공: pykrx (KRX)"; else echo "  · pykrx 조회 실패" >&2; fi
  else
    echo "  · pykrx 설치 실패: $(tail -1 /tmp/pip.log 2>/dev/null)" >&2
  fi
fi

# ---------- 4) Twelve Data (무료 API 키, 클라우드 IP 허용) ----------
# GitHub Secret TWELVEDATA_API_KEY 가 설정된 경우에만 시도.
# 국내는 exchange=KRX가 필요하고, 미국은 심볼만으로 조회한다.
if [ "$ok" -ne 1 ] && [ -n "${TWELVEDATA_API_KEY:-}" ]; then
  td_ex=""; [ "$MARKET" = "krx" ] && td_ex="&exchange=KRX"
  code=$(fetch "TwelveData" "https://api.twelvedata.com/time_series?symbol=${NUMCODE}${td_ex}&interval=1day&outputsize=260&order=ASC&apikey=${TWELVEDATA_API_KEY}")
  if [ "$code" = "200" ] && jq -e '.values and (.values|length>0)' "$tmp" >/dev/null 2>&1; then
    jq --arg name "$NAME" --arg updated "$UPDATED" --arg sym "$SYMLABEL" --arg cur "$CURRENCY" '
      { symbol: $sym, name: $name, currency: $cur,
        price: (.values | last | .close | tonumber),
        marketTime: (.values | last | .datetime | (strptime("%Y-%m-%d") | mktime)),
        updated: $updated,
        points: [ .values[] | { t: (.datetime | strptime("%Y-%m-%d") | mktime), c: (.close | tonumber) } ] }' "$tmp" > "$OUT"
    ok=1; echo "→ 성공: Twelve Data"
  fi
fi

# ---------- 5) Financial Modeling Prep (무료 API 키) ----------
if [ "$ok" -ne 1 ] && [ -n "${FMP_API_KEY:-}" ]; then
  code=$(fetch "FMP" "https://financialmodelingprep.com/api/v3/historical-price-full/${SYMBOL}?serietype=line&apikey=${FMP_API_KEY}")
  if [ "$code" = "200" ] && jq -e '.historical and (.historical|length>0)' "$tmp" >/dev/null 2>&1; then
    jq --arg name "$NAME" --arg updated "$UPDATED" --arg sym "$SYMLABEL" --arg cur "$CURRENCY" '
      { symbol: $sym, name: $name, currency: $cur,
        price: (.historical[0].close),
        marketTime: (.historical[0].date | strptime("%Y-%m-%d") | mktime),
        updated: $updated,
        points: [ .historical | reverse | .[-260:][] | { t: (.date | strptime("%Y-%m-%d") | mktime), c: .close } ] }' "$tmp" > "$OUT"
    ok=1; echo "→ 성공: Financial Modeling Prep"
  fi
fi

rm -f "$tmp" /tmp/curl_err

if [ "$ok" -ne 1 ]; then
  echo "오류: 모든 데이터 소스 실패. 위 HTTP 코드를 확인하세요." >&2
  echo "  · 403 = 해당 호스트가 GitHub Actions(Azure) IP를 차단함 → 무료 API 키 방식(TwelveData/FMP) 사용 권장." >&2
  exit 1
fi

jq -e '.points | length >= 5' "$OUT" >/dev/null || { echo "오류: 유효 포인트 부족" >&2; exit 1; }
echo "생성 완료: ${OUT}  포인트=$(jq '.points|length' "$OUT")  현재가=$(jq -r '.price' "$OUT")  갱신=${UPDATED}"
