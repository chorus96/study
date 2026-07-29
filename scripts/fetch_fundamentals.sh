#!/usr/bin/env bash
# 종목 PER 일별 추이를 생성한다. 단일 최근 EPS(주당순이익)로
#   PER_t = 종가_t / EPS
# 를 계산해 부드러운(끊김 없는) 추이선을 만든다.
#  - 국내(KRX): DART 최근 사업보고서의 기본주당이익
#  - 미국(US) : FMP income-statement의 eps → 실패 시 Alpha Vantage OVERVIEW의 EPS
# 시세는 같은 폴더 data.json에서 읽는다. 키/데이터가 없거나 EPS≤0이면 조용히
# 건너뛴다(파일 미생성 → 앱이 카드 숨김/안내). 배포를 막지 않도록 항상 exit 0.
set -uo pipefail

OUT="${OUT:-stock-analyzer/hynix/fundamentals.json}"
NAME="${NAME:-SK하이닉스}"
SYMBOL="${SYMBOL:-}"
MARKET="${MARKET:-krx}"
CURRENCY="${CURRENCY:-KRW}"
CORP_CODE="${CORP_CODE:-}"
DATA="${DATA:-$(dirname "$OUT")/data.json}"
UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

mkdir -p "$(dirname "$OUT")"
if [ ! -s "$DATA" ]; then echo "PER: 시세 data.json 없음 → 건너뜀(${NAME})" >&2; exit 0; fi
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
eps=""

if [ "$MARKET" = "krx" ]; then
  # ---------- 국내: DART 기본주당이익(최근 연도) ----------
  if [ -z "${DART_API_KEY:-}" ] || [ -z "$CORP_CODE" ]; then
    echo "PER: DART_API_KEY/CORP_CODE 미설정 → 건너뜀(${NAME})" >&2; exit 0
  fi
  years="$(python3 -c 'import datetime;y=datetime.datetime.now().year;print(" ".join(str(y-i) for i in range(1,4)))')"
  echo "PER(DART EPS) 수집: ${NAME} corp=${CORP_CODE}"
  : > "$tmp"
  for y in $years; do
    r="$(curl -sfL --max-time 30 -A "$UA" \
      "https://opendart.fss.or.kr/api/fnlttSinglAcntAll.json?crtfc_key=${DART_API_KEY}&corp_code=${CORP_CODE}&bsns_year=${y}&reprt_code=11011&fs_div=CFS" 2>/dev/null)" || continue
    printf '%s\n' "$r" >> "$tmp"
  done
  eps="$(python3 - "$tmp" <<'PY'
import sys, json

def amt(s):
    s = (s or "").strip().replace(",", "")
    neg = s.startswith("(") and s.endswith(")"); s = s.strip("()")
    try:
        v = float(s)
    except ValueError:
        return None
    return -v if neg else v

best_year, best = None, None
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        j = json.loads(line)
    except Exception:
        continue
    if j.get("status") != "000":
        continue
    # 진단: 이 보고서의 모든 '주당' 계정을 로그로 덤프
    for it in j.get("list", []):
        nm = (it.get("account_nm") or "")
        if "주당" in nm:
            sys.stderr.write("  [EPS후보] y=%s sj=%s id=%s nm=%s thstrm=%s\n" % (
                it.get("bsns_year"), it.get("sj_div"), it.get("account_id"),
                nm.strip(), it.get("thstrm_amount")))
    # 선택: 기본주당이익(손실)
    for it in j.get("list", []):
        nm = (it.get("account_nm") or "").replace(" ", "")
        aid = it.get("account_id") or ""
        if aid == "ifrs-full_BasicEarningsLossPerShare" or "기본주당" in nm:
            yr = str(it.get("bsns_year") or "")
            v = amt(it.get("thstrm_amount"))
            if yr and v is not None and (best_year is None or yr > best_year):
                best_year, best = yr, v
            break
sys.stderr.write("  [EPS선택] year=%s eps=%s\n" % (best_year, best))
print("" if best is None else repr(best))
PY
)"
else
  # ---------- 미국: FMP eps → Alpha Vantage OVERVIEW EPS ----------
  [ -z "$SYMBOL" ] && SYMBOL="$NAME"
  echo "PER(US EPS) 수집: ${NAME} (${SYMBOL})"
  if [ -n "${FMP_API_KEY:-}" ]; then
    code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
      "https://financialmodelingprep.com/stable/income-statement?symbol=${SYMBOL}&period=annual&limit=1&apikey=${FMP_API_KEY}" 2>/dev/null || echo 000)
    echo "  · FMP eps HTTP ${code}" >&2
    if [ "$code" = "200" ]; then
      eps="$(python3 -c 'import sys,json
try:
    a=json.load(open(sys.argv[1]))
    e=a[0].get("eps") if isinstance(a,list) and a else None
    print(repr(float(e)) if e not in (None,"") else "")
except Exception:
    print("")' "$tmp" 2>/dev/null || echo "")"
    fi
  fi
  if [ -z "$eps" ] && [ -n "${ALPHAVANTAGE_API_KEY:-}" ]; then
    code=$(curl -sS --max-time 30 -A "$UA" -w '%{http_code}' -o "$tmp" \
      "https://www.alphavantage.co/query?function=OVERVIEW&symbol=${SYMBOL}&apikey=${ALPHAVANTAGE_API_KEY}" 2>/dev/null || echo 000)
    echo "  · AV OVERVIEW HTTP ${code}: $(head -c 100 "$tmp" 2>/dev/null | tr '\n' ' ')" >&2
    if [ "$code" = "200" ]; then
      eps="$(python3 -c 'import sys,json
try:
    d=json.load(open(sys.argv[1]))
    e=d.get("EPS") if isinstance(d,dict) else None
    print(repr(float(e)) if e not in (None,"","None") else "")
except Exception:
    print("")' "$tmp" 2>/dev/null || echo "")"
    fi
  fi
fi

if [ -z "$eps" ]; then echo "PER: EPS 확보 실패 → 건너뜀(${NAME})" >&2; exit 0; fi

python3 - "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$DATA" "$eps" <<'PY' || { echo "  · PER 생성 실패(${NAME})" >&2; exit 0; }
import sys, json
out, name, updated, currency, datasrc, eps = sys.argv[1:7]
eps = float(eps)
if eps <= 0:
    sys.exit("EPS<=0(적자) → PER 생략")
data = json.load(open(datasrc, encoding="utf-8"))
pts = []
for p in data.get("points", []):
    c, t = p.get("c"), p.get("t")
    if c and t:
        pts.append({"t": int(t), "v": round(c / eps, 2)})
pts = pts[-260:]
if len(pts) < 5:
    sys.exit("PER 포인트 부족")
out_data = {"name": name, "currency": currency, "updated": updated,
            "per": {"points": pts, "current": pts[-1]["v"], "eps": round(eps, 2)}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(out_data, f, ensure_ascii=False)
print("PER 완료:", len(pts), "포인트 · 현재 PER", pts[-1]["v"], "· EPS", eps)
PY
