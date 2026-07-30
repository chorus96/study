#!/usr/bin/env bash
# 종목 손익지표(영업이익, 분기)를 받아 same-origin financials.json 으로 저장한다.
#  - 국내(KRX): DART(전자공시) 무료 오픈API. DART_API_KEY + CORP_CODE 필요.
#               분기·반기보고서는 '당기 3개월' 실적, 사업보고서만 '연간 누적'이라
#               Q1·Q2·Q3는 그대로 쓰고 Q4 = 연간 − (Q1+Q2+Q3)로 계산한다.
#  - 미국(US) : Alpha Vantage(quarterlyReports, 20+분기) → FMP(무료 5분기) 폴백.
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
  # ---------- DART: 분기 영업이익(누적 → 이산) ----------
  if [ -z "${DART_API_KEY:-}" ]; then echo "DART_API_KEY 미설정 → 영업이익 건너뜀(${NAME})" >&2; exit 0; fi
  if [ -z "$CORP_CODE" ]; then echo "CORP_CODE 미설정 → 영업이익 건너뜀(${NAME})" >&2; exit 0; fi

  years="$(python3 -c 'import datetime;y=datetime.datetime.now().year;print(" ".join(str(y-i) for i in range(0,6)))')"
  echo "영업이익(DART·분기) 수집 시작: ${NAME} corp=${CORP_CODE}, years=${years}"
  work="$(mktemp -d)"; trap 'rm -rf "$tmp" "$work"' EXIT
  # 분기 reprt_code: 1Q=11013, 반기(누적2Q)=11012, 3Q(누적3Q)=11014, 사업보고서(연간)=11011
  for y in $years; do
    for rc in 11013 11012 11014 11011; do
      r="$(curl -sfL --max-time 30 -A "$UA" \
        "https://opendart.fss.or.kr/api/fnlttSinglAcntAll.json?crtfc_key=${DART_API_KEY}&corp_code=${CORP_CODE}&bsns_year=${y}&reprt_code=${rc}&fs_div=CFS" 2>/dev/null)" || continue
      printf '%s' "$r" > "$work/${y}_${rc}.json"
    done
  done

  python3 - "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$work" <<'PY' || { echo "  · DART 분기 영업이익 파싱 실패" >&2; exit 0; }
import sys, json, glob, os
out, name, updated, currency, workdir = sys.argv[1:6]
# reprt_code → 분기 인덱스(1·2·3분기는 3개월 실적, 4=사업보고서 연간 누적)
RC_K = {"11013": 1, "11012": 2, "11014": 3, "11011": 4}

def op_income(j):
    # 흑자·적자 표기가 달라 부분일치가 아닌 정확한 형태만 허용(오탐 방지).
    for it in j.get("list", []):
        nm = (it.get("account_nm") or "").replace(" ", "")
        if nm not in ("영업이익", "영업이익(손실)", "영업손실"):
            continue
        if (it.get("sj_div") or "") not in ("IS", "CIS"):
            continue
        amt = (it.get("thstrm_amount") or "").replace(",", "").strip()
        try:
            return int(amt)
        except ValueError:
            return None
    return None

# vals[year][k] = k분기 영업이익 (k=1·2·3은 3개월 실적, k=4는 연간 누적)
cum = {}
for path in sorted(glob.glob(os.path.join(workdir, "*.json"))):
    base = os.path.basename(path)[:-5]  # "YYYY_RC"
    try:
        y, rc = base.split("_")
    except ValueError:
        continue
    k = RC_K.get(rc)
    if not k:
        continue
    try:
        j = json.load(open(path, encoding="utf-8"))
    except Exception:
        continue
    if j.get("status") != "000":
        continue
    v = op_income(j)
    if v is not None:
        cum.setdefault(y, {})[k] = v

# Q1·Q2·Q3는 분기 보고서의 3개월 실적 그대로, Q4 = 연간 − (Q1+Q2+Q3).
pts = []
for y in sorted(cum):
    c = cum[y]
    sys.stderr.write("  [분기값] %s %s\n" % (y, {"Q%d" % k: c[k] for k in sorted(c)}))
    q1, q2, q3, ann = c.get(1), c.get(2), c.get(3), c.get(4)
    for k, v in ((1, q1), (2, q2), (3, q3)):
        if v is not None:
            pts.append({"period": "%sQ%d" % (y, k), "value": v})
    # 연간이 있고 1~3분기가 모두 있으면 Q4를 역산(둘 중 하나라도 없으면 Q4 생략)
    if ann is not None and None not in (q1, q2, q3):
        pts.append({"period": "%sQ4" % y, "value": ann - (q1 + q2 + q3)})

if len(pts) < 2:
    sys.exit("분기 영업이익 데이터 부족")
data = {"name": name, "currency": currency, "updated": updated,
        "operatingIncome": {"unit": currency, "granularity": "quarter", "points": pts[-20:]}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print("영업이익(DART·분기) 완료:", len(pts), "분기 · 최근", pts[-1]["period"], pts[-1]["value"])
PY

else
  # ---------- 미국: FMP(분기) → Alpha Vantage(분기) 폴백 ----------
  # FMP 무료 플랜은 일부 종목만 허용(예: NVDA 가능, MU 불가). FMP가 안 되는
  # 종목은 Alpha Vantage(무료 25회/일)의 quarterlyReports로 받는다.
  [ -z "$SYMBOL" ] && SYMBOL="$NAME"
  ok=0

  # 공용 파서: FMP(배열) / Alpha Vantage(quarterlyReports)를 분기 영업이익으로 변환.
  PARSE="$(mktemp)"; trap 'rm -f "$tmp" "$PARSE"' EXIT
  cat > "$PARSE" <<'PY'
import sys, json
out, name, updated, currency, src, kind = sys.argv[1:7]
try:
    raw = json.load(open(src, encoding="utf-8"))
except Exception:
    sys.exit("JSON 파싱 실패")

by_q = {}   # "YYYYQn" -> 영업이익
def add(year, q, v):
    if year and q and isinstance(v, (int, float)):
        by_q["%sQ%d" % (year, q)] = int(v)

if kind == "fmp":
    if not isinstance(raw, list) or not raw:
        sys.exit("FMP 데이터 없음")
    for it in raw:
        # 달력 기준으로 통일: 보고일(date)의 연·월로 연도·분기를 정한다.
        # (FMP calendarYear는 회계연도라 엔비디아처럼 결산이 앞선 종목은 어긋남)
        date = it.get("date") or ""
        if len(date) >= 7:
            year, q = date[:4], (int(date[5:7]) - 1) // 3 + 1
        else:
            per = (it.get("period") or "").upper()
            year = str(it.get("calendarYear") or it.get("fiscalYear") or "")
            q = int(per[1:]) if (per.startswith("Q") and per[1:].isdigit()) else None
        add(year, q, it.get("operatingIncome"))
else:  # Alpha Vantage
    reports = raw.get("quarterlyReports") if isinstance(raw, dict) else None
    if not reports:
        sys.exit("AV 데이터 없음: " + json.dumps(raw, ensure_ascii=False)[:140])
    for it in reports:
        fd = it.get("fiscalDateEnding") or ""
        if len(fd) < 7:
            continue
        year, q = fd[:4], (int(fd[5:7]) - 1) // 3 + 1
        try:
            v = int(it.get("operatingIncome"))
        except (TypeError, ValueError):
            v = None
        add(year, q, v)

keys = sorted(by_q)   # "2024Q4" < "2025Q1" (문자열 사전순 = 시간순)
pts = [{"period": k, "value": by_q[k]} for k in keys]
if len(pts) < 2:
    sys.exit("영업이익 데이터 부족")
data = {"name": name, "currency": currency, "updated": updated,
        "operatingIncome": {"unit": currency, "granularity": "quarter", "points": pts[-20:]}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print("영업이익(분기) 완료:", len(pts), "분기 · 최근", pts[-1]["period"], pts[-1]["value"])
PY

  # 5년(≈20분기)을 채우려면 Alpha Vantage(quarterlyReports 20+개)를 먼저 쓴다.
  # FMP 무료(stable)는 분기 limit이 최대 5라 5분기까지만 → AV 실패 시 폴백.
  if [ -n "${ALPHAVANTAGE_API_KEY:-}" ]; then
    echo "영업이익(Alpha Vantage·분기) 시도: ${NAME} (${SYMBOL})"
    code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
      "https://www.alphavantage.co/query?function=INCOME_STATEMENT&symbol=${SYMBOL}&apikey=${ALPHAVANTAGE_API_KEY}" 2>/dev/null || echo 000)
    echo "  · AV HTTP ${code}: $(head -c 140 "$tmp" 2>/dev/null | tr '\n' ' ')" >&2
    if [ "$code" = "200" ] && python3 "$PARSE" "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$tmp" av; then
      ok=1; echo "→ 성공: Alpha Vantage (${NAME})"
    fi
  fi

  if [ "$ok" -ne 1 ] && [ -n "${FMP_API_KEY:-}" ]; then
    echo "영업이익(FMP·분기) 시도: ${NAME} (${SYMBOL})"
    code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
      "https://financialmodelingprep.com/stable/income-statement?symbol=${SYMBOL}&period=quarter&limit=5&apikey=${FMP_API_KEY}" 2>/dev/null || echo 000)
    echo "  · FMP(stable) HTTP ${code}: $(head -c 140 "$tmp" 2>/dev/null | tr '\n' ' ')" >&2
    if [ "$code" = "200" ] && python3 "$PARSE" "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$tmp" fmp; then
      ok=1; echo "→ 성공: FMP (${NAME})"
    fi
  fi

  [ "$ok" -ne 1 ] && echo "  · 미국 영업이익 수집 실패(${NAME})" >&2
  exit 0
fi
