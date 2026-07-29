#!/usr/bin/env bash
# SK하이닉스 최신 뉴스를 수집해 "키워드 기반 간이 심리"로 분석하고
# same-origin news.json으로 저장한다. GitHub Actions 러너에서 실행된다.
#
# LLM/API 키가 필요 없다(완전 무료·무키). Google News RSS(키 불필요)에서
# 헤드라인을 받아, 한국어 금융 키워드 규칙으로 긍정/중립/부정을 집계한다.
# RSS 수집에 실패하거나 헤드라인이 없으면 조용히 건너뛴다(앱은 news.json이
# 없으면 뉴스 카드를 숨긴다).
set -uo pipefail

OUT="${NEWS_OUT:-hynix-stock-analyzer/news.json}"
NAME="${NAME:-SK하이닉스}"
QUERY="${NEWS_QUERY:-SK하이닉스}"
MAXH="${NEWS_MAX_HEADLINES:-8}"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$(dirname "$OUT")"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# ---------- 1) Google News RSS 수집 (키 불필요) ----------
encoded="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$QUERY")"
rss="https://news.google.com/rss/search?q=${encoded}&hl=ko&gl=KR&ceid=KR:ko"
if ! curl -sfL --max-time 30 -A "$UA" "$rss" -o "$tmp"; then
  echo "뉴스 RSS 수집 실패(HTTP) → 건너뜀" >&2; exit 0
fi

# ---------- 2) 헤드라인 파싱 + 키워드 기반 심리 집계 → news.json ----------
python3 - "$tmp" "$OUT" "$MAXH" "$UPDATED" "$NAME" <<'PY'
import sys, json, datetime, email.utils
import xml.etree.ElementTree as ET

src, out, maxh, updated, name = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]

try:
    root = ET.parse(src).getroot()
except Exception:
    sys.exit(0)  # 파싱 실패 → 조용히 건너뜀(카드 숨김)

headlines = []
for it in root.findall('.//item')[:maxh]:
    title = (it.findtext('title') or '').strip()
    link = (it.findtext('link') or '').strip()
    s = it.find('{http://www.w3.org/2005/Atom}source')
    if s is None:
        s = it.find('source')
    source = (s.text.strip() if s is not None and s.text else '')
    pub = (it.findtext('pubDate') or '').strip()
    iso = ''
    if pub:
        try:
            iso = email.utils.parsedate_to_datetime(pub).astimezone(
                datetime.timezone.utc).isoformat()
        except Exception:
            iso = ''
    if title:
        headlines.append({'title': title, 'link': link, 'source': source, 'date': iso})

if not headlines:
    sys.exit(0)  # 헤드라인 없음 → 카드 숨김

# --- 한국어 금융 키워드 사전 (반도체/증시 맥락) ---
POS = ["급등", "상승", "강세", "신고가", "최고가", "사상 최대", "역대 최대", "최대 실적",
       "호실적", "실적 개선", "흑자", "순이익", "수주", "계약", "성장", "확대", "증설",
       "투자", "돌파", "반등", "회복", "개선", "호재", "기대", "낙관", "상향", "목표가 상향",
       "수요 증가", "수요 급증", "훈풍", "질주", "호황", "매수"]
NEG = ["급락", "하락", "약세", "신저가", "최저가", "적자", "손실", "부진", "감소", "축소",
       "둔화", "침체", "위기", "우려", "리스크", "악재", "하향", "목표가 하향", "규제",
       "제재", "소송", "조사", "과잉", "재고 증가", "경고", "부담", "쇼크", "충격", "매도",
       "파업", "공급 과잉", "먹구름", "빨간불"]

def score_title(t):
    p = sum(1 for k in POS if k in t)
    n = sum(1 for k in NEG if k in t)
    return p - n

def label(sc):
    return "긍정" if sc > 0 else ("부정" if sc < 0 else "중립")

per, counts = [], {"긍정": 0, "중립": 0, "부정": 0}
total = 0
for i, h in enumerate(headlines):
    sc = score_title(h["title"])
    lab = label(sc)
    per.append({"index": i + 1, "sentiment": lab})
    counts[lab] += 1
    total += sc

overall = label(total)

# 요약 문장
n = len(headlines)
summary = (f"최근 헤드라인 {n}건 중 긍정 {counts['긍정']}건·중립 {counts['중립']}건·"
           f"부정 {counts['부정']}건으로, 전반적으로 {overall} 흐름입니다.")

# 핵심 포인트: 심리가 뚜렷한 헤드라인 최대 4건
notable = []
for h, ps in zip(headlines, per):
    if ps["sentiment"] != "중립":
        notable.append((ps["sentiment"], h["title"]))
key_points = [f"{lab} 신호: {title}" for lab, title in notable[:4]]
if not key_points:
    key_points = ["뚜렷한 긍·부정 키워드가 없어 중립적 흐름입니다."]

data = {
    "name": name, "updated": updated, "method": "키워드 기반", "source": "Google News",
    "headlines": headlines,
    "analysis": {"sentiment": overall, "summary": summary,
                 "key_points": key_points, "headlines": per},
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print(f"뉴스 심리(간이) 완료: {overall} · 헤드라인 {n}건 "
      f"(긍정 {counts['긍정']}·중립 {counts['중립']}·부정 {counts['부정']})")
PY
