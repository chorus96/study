#!/usr/bin/env bash
# 종목 손익지표(영업이익, 연간)를 받아 same-origin financials.json 으로 저장한다.
#  - 국내(KRX): DART(전자공시) 무료 오픈API. DART_API_KEY + CORP_CODE 필요.
#  - 미국(US) : Financial Modeling Prep 무료 API. FMP_API_KEY 필요.
# 키가 없거나 수집에 실패하면 조용히 건너뛴다(파일 미생성 → 앱이 카드 숨김).
# 배포를 막지 않도록 항상 exit 0.
set -uo pipefail

OUT="${OUT:-stock-analyzer/hynix/financials.json}"
NAME="${NAME:-SK하이닉스}"
SYMBOL="${SYMBOL:-}"
MARKET="${MARKET:-krx}"
CURRENCY="${CURRENCY:-KRW}"
CORP_CODE="${CORP_CODE:-}"          # DART 8자리 고유번호(국내)
UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

mkdir -p "$(dirname "$OUT")"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

if [ "$MARKET" = "krx" ]; then
  # ---------- DART: 연간 영업이익 ----------
  if [ -z "${DART_API_KEY:-}" ]; then echo "DART_API_KEY 미설정 → 영업이익 건너뜀(${NAME})" >&2; exit 0; fi
  if [ -z "$CORP_CODE" ]; then echo "CORP_CODE 미설정 → 영업이익 건너뜀(${NAME})" >&2; exit 0; fi

  years="$(python3 -c 'import datetime;y=datetime.datetime.now().year;print(" ".join(str(y-i) for i in range(1,6)))')"
  echo "영업이익(DART) 수집 시작: ${NAME} corp=${CORP_CODE}, years=${years}"
  : > "$tmp"
  for y in $years; do
    r="$(curl -sfL --max-time 30 -A "$UA" \
      "https://opendart.fss.or.kr/api/fnlttSinglAcntAll.json?crtfc_key=${DART_API_KEY}&corp_code=${CORP_CODE}&bsns_year=${y}&reprt_code=11011&fs_div=CFS" 2>/dev/null)" || continue
    printf '%s\n' "$r" >> "$tmp"
  done

  python3 - "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$tmp" <<'PY' || { echo "  · DART 영업이익 파싱 실패" >&2; exit 0; }
import sys, json
out, name, updated, currency, src = sys.argv[1:6]
by_year = {}
for line in open(src, encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        j = json.loads(line)
    except Exception:
        continue
    if j.get("status") != "000":
        continue
    for it in j.get("list", []):
        nm = (it.get("account_nm") or "").replace(" ", "")
        # 흑자·적자에 따라 "영업이익" 또는 "영업이익(손실)"로 표기되므로 부분일치.
        # 매출총이익/영업외이익 등 오탐 방지를 위해 정확히 그 두 형태만 허용.
        if nm not in ("영업이익", "영업이익(손실)", "영업손실"):
            continue
        if (it.get("sj_div") or "") not in ("IS", "CIS"):
            continue
        yr = it.get("bsns_year")
        amt = (it.get("thstrm_amount") or "").replace(",", "").strip()
        try:
            v = int(amt)
        except ValueError:
            continue
        if yr:
            by_year[str(yr)] = v
        break
pts = [{"period": y, "value": by_year[y]} for y in sorted(by_year)]
if len(pts) < 2:
    sys.exit("영업이익 데이터 부족")
data = {"name": name, "currency": currency, "updated": updated,
        "operatingIncome": {"unit": currency, "points": pts[-6:]}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print("영업이익(DART) 완료:", len(pts), "개년 · 최근", pts[-1]["period"], pts[-1]["value"])
PY

else
  # ---------- 미국: FMP → Alpha Vantage(폴백) ----------
  # FMP 무료 플랜은 일부 종목만 허용(예: NVDA 가능, MU 불가). FMP가 안 되는
  # 종목은 Alpha Vantage(무료 25회/일)로 income statement를 받는다.
  [ -z "$SYMBOL" ] && SYMBOL="$NAME"
  ok=0

  # 공용 파서: FMP(배열) / Alpha Vantage(annualReports) 응답을 영업이익으로 변환.
  PARSE="$(mktemp)"; trap 'rm -f "$tmp" "$PARSE"' EXIT
  cat > "$PARSE" <<'PY'
import sys, json
out, name, updated, currency, src, kind = sys.argv[1:7]
try:
    raw = json.load(open(src, encoding="utf-8"))
except Exception:
    sys.exit("JSON 파싱 실패")
by_year = {}
if kind == "fmp":
    if not isinstance(raw, list) or not raw:
        sys.exit("FMP 데이터 없음")
    for it in raw:
        yr = str(it.get("calendarYear") or it.get("fiscalYear") or (it.get("date") or "")[:4] or "")
        v = it.get("operatingIncome")
        if yr and isinstance(v, (int, float)):
            by_year[yr] = int(v)
else:  # Alpha Vantage
    reports = raw.get("annualReports") if isinstance(raw, dict) else None
    if not reports:
        sys.exit("AV 데이터 없음: " + json.dumps(raw, ensure_ascii=False)[:140])
    for it in reports:
        yr = (it.get("fiscalDateEnding") or "")[:4]
        try:
            v = int(it.get("operatingIncome"))
        except (TypeError, ValueError):
            v = None
        if yr and v is not None:
            by_year[yr] = v
pts = [{"period": y, "value": by_year[y]} for y in sorted(by_year)]
if len(pts) < 2:
    sys.exit("영업이익 데이터 부족")
data = {"name": name, "currency": currency, "updated": updated,
        "operatingIncome": {"unit": currency, "points": pts[-6:]}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print("영업이익 완료:", len(pts), "개년 · 최근", pts[-1]["period"], pts[-1]["value"])
PY

  if [ -n "${FMP_API_KEY:-}" ]; then
    echo "영업이익(FMP) 시도: ${NAME} (${SYMBOL})"
    code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
      "https://financialmodelingprep.com/stable/income-statement?symbol=${SYMBOL}&period=annual&limit=5&apikey=${FMP_API_KEY}" 2>/dev/null || echo 000)
    echo "  · FMP(stable) HTTP ${code}: $(head -c 140 "$tmp" 2>/dev/null | tr '\n' ' ')" >&2
    if [ "$code" = "200" ] && python3 "$PARSE" "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$tmp" fmp; then
      ok=1; echo "→ 성공: FMP (${NAME})"
    fi
  fi

  if [ "$ok" -ne 1 ] && [ -n "${ALPHAVANTAGE_API_KEY:-}" ]; then
    echo "영업이익(Alpha Vantage) 시도: ${NAME} (${SYMBOL})"
    code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
      "https://www.alphavantage.co/query?function=INCOME_STATEMENT&symbol=${SYMBOL}&apikey=${ALPHAVANTAGE_API_KEY}" 2>/dev/null || echo 000)
    echo "  · AV HTTP ${code}: $(head -c 140 "$tmp" 2>/dev/null | tr '\n' ' ')" >&2
    if [ "$code" = "200" ] && python3 "$PARSE" "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$tmp" av; then
      ok=1; echo "→ 성공: Alpha Vantage (${NAME})"
    fi
  fi

  [ "$ok" -ne 1 ] && echo "  · 미국 영업이익 수집 실패(${NAME})" >&2
  exit 0
fi
