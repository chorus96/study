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
  # ---------- FMP: 연간 영업이익 ----------
  if [ -z "${FMP_API_KEY:-}" ]; then echo "FMP_API_KEY 미설정 → 영업이익 건너뜀(${NAME})" >&2; exit 0; fi
  [ -z "$SYMBOL" ] && SYMBOL="$NAME"
  echo "영업이익(FMP) 수집 시작: ${NAME} (${SYMBOL})"
  # FMP 무료 플랜은 현재 stable 엔드포인트를 사용(레거시 /api/v3 는 유료 전환됨).
  # stable 실패 시 v3 로 폴백하고, 진단을 위해 HTTP 코드·본문 앞부분을 로그로 남긴다.
  code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
    "https://financialmodelingprep.com/stable/income-statement?symbol=${SYMBOL}&period=annual&limit=5&apikey=${FMP_API_KEY}" 2>/dev/null || echo 000)
  echo "  · FMP(stable) HTTP ${code}: $(head -c 160 "$tmp" 2>/dev/null | tr '\n' ' ')" >&2
  if [ "$code" != "200" ]; then
    code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
      "https://financialmodelingprep.com/api/v3/income-statement/${SYMBOL}?period=annual&limit=5&apikey=${FMP_API_KEY}" 2>/dev/null || echo 000)
    echo "  · FMP(v3) HTTP ${code}: $(head -c 160 "$tmp" 2>/dev/null | tr '\n' ' ')" >&2
  fi
  if [ "$code" != "200" ]; then echo "  · FMP 요청 실패(HTTP ${code})" >&2; exit 0; fi
  python3 - "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$tmp" <<'PY' || { echo "  · FMP 영업이익 파싱 실패" >&2; exit 0; }
import sys, json
out, name, updated, currency, src = sys.argv[1:6]
try:
    arr = json.load(open(src, encoding="utf-8"))
except Exception:
    sys.exit("FMP JSON 파싱 실패")
if not isinstance(arr, list) or not arr:
    sys.exit("FMP 데이터 없음")
by_year = {}
for it in arr:
    yr = str(it.get("calendarYear") or it.get("fiscalYear") or (it.get("date") or "")[:4] or "")
    v = it.get("operatingIncome")
    if yr and isinstance(v, (int, float)):
        by_year[yr] = int(v)
pts = [{"period": y, "value": by_year[y]} for y in sorted(by_year)]
if len(pts) < 2:
    sys.exit("영업이익 데이터 부족")
data = {"name": name, "currency": currency, "updated": updated,
        "operatingIncome": {"unit": currency, "points": pts[-6:]}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print("영업이익(FMP) 완료:", len(pts), "개년 · 최근", pts[-1]["period"], pts[-1]["value"])
PY
fi
