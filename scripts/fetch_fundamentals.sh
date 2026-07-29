#!/usr/bin/env bash
# 국내 종목 PER 일별 추이를 생성한다.
# pykrx 재무 엔드포인트가 러너(Azure) IP에서 빈 응답을 주어, 대신 DART(무료)에서
# 연도별 EPS(기본주당이익)를 받아 이미 생성된 data.json의 일별 종가로
#   PER_t = 종가_t / EPS(해당 연도)
# 를 계산한다. DART_API_KEY + CORP_CODE 필요. 미국 종목은 무료 PER 시계열
# 소스가 없어 생략(파일 미생성 → 앱이 안내 표시). 배포를 막지 않도록 항상 exit 0.
set -uo pipefail

OUT="${OUT:-stock-analyzer/hynix/fundamentals.json}"
NAME="${NAME:-SK하이닉스}"
MARKET="${MARKET:-krx}"
CURRENCY="${CURRENCY:-KRW}"
CORP_CODE="${CORP_CODE:-}"
DATA="${DATA:-$(dirname "$OUT")/data.json}"     # 같은 폴더의 시세 파일
UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

mkdir -p "$(dirname "$OUT")"

if [ "$MARKET" != "krx" ]; then
  echo "PER: 미국 종목(${NAME})은 무료 PER 시계열 소스가 없어 생략" >&2; exit 0
fi
if [ -z "${DART_API_KEY:-}" ] || [ -z "$CORP_CODE" ]; then
  echo "PER: DART_API_KEY/CORP_CODE 미설정 → 생략(${NAME})" >&2; exit 0
fi
if [ ! -s "$DATA" ]; then
  echo "PER: 시세 data.json 없음 → 생략(${NAME})" >&2; exit 0
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
years="$(python3 -c 'import datetime;y=datetime.datetime.now().year;print(" ".join(str(y-i) for i in range(1,4)))')"
echo "PER(DART EPS) 수집 시작: ${NAME} corp=${CORP_CODE}, years=${years}"
: > "$tmp"
for y in $years; do
  r="$(curl -sfL --max-time 30 -A "$UA" \
    "https://opendart.fss.or.kr/api/fnlttSinglAcntAll.json?crtfc_key=${DART_API_KEY}&corp_code=${CORP_CODE}&bsns_year=${y}&reprt_code=11011&fs_div=CFS" 2>/dev/null)" || continue
  printf '%s\n' "$r" >> "$tmp"
done

python3 - "$OUT" "$NAME" "$UPDATED" "$CURRENCY" "$tmp" "$DATA" <<'PY' || { echo "  · PER 생성 실패" >&2; exit 0; }
import sys, json, datetime
out, name, updated, currency, dartsrc, datasrc = sys.argv[1:7]

def parse_amt(s):
    s = (s or "").strip().replace(",", "")
    neg = s.startswith("(") and s.endswith(")")
    s = s.strip("()")
    if s in ("", "-"):
        return None
    try:
        v = float(s)
    except ValueError:
        return None
    return -v if neg else v

# DART 연도별 기본주당이익(EPS)
eps_by_year = {}
for line in open(dartsrc, encoding="utf-8"):
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
        aid = it.get("account_id") or ""
        if aid == "ifrs-full_BasicEarningsLossPerShare" or "기본주당" in nm:
            yr = str(it.get("bsns_year") or "")
            v = parse_amt(it.get("thstrm_amount"))
            if yr and v is not None:
                eps_by_year[yr] = v
            break
if not eps_by_year:
    sys.exit("EPS 없음")
latest_year = max(eps_by_year)
latest_eps = eps_by_year[latest_year]

# 일별 종가 × 연도별 EPS → PER
data = json.load(open(datasrc, encoding="utf-8"))
pts = []
for p in data.get("points", []):
    c, t = p.get("c"), p.get("t")
    if not c or not t:
        continue
    yr = datetime.datetime.utcfromtimestamp(t).year
    eps = eps_by_year.get(str(yr), latest_eps)
    if eps and eps > 0:
        pts.append({"t": int(t), "v": round(c / eps, 2)})
pts = pts[-260:]
if len(pts) < 5:
    sys.exit("PER 유효 포인트 부족(EPS 음수/부족)")
out_data = {"name": name, "currency": currency, "updated": updated,
            "per": {"points": pts, "current": pts[-1]["v"]}}
with open(out, "w", encoding="utf-8") as f:
    json.dump(out_data, f, ensure_ascii=False)
print("PER(DART EPS) 완료:", len(pts), "포인트 · 현재 PER", pts[-1]["v"],
      "· 최신 EPS", latest_year, latest_eps)
PY
