# 9장: 문자열, string

### 1. string 명령어

string 명령어는 문자열 조작을 위한 다양한 서브커맨드를 제공합니다.

regular expression은 문자열 작업을 위해 매우 중요하고, 퇴근 시간을 앞당길 수 있는 기술입니다. :)

#### 1.1 주요 string 서브커맨드

* **length**: 문자열 길이 반환
* **index**: 특정 인덱스의 문자 반환
* **range**: 특정 범위의 부분 문자열 반환
* **tolower/toupper**: 소문자/대문자 변환
* **trim/trimleft/trimright**: 공백 또는 지정 문자 제거
* **map**: 문자 매핑
* **replace**: 부분 문자열 대체
* **match**: 글로브 패턴 매칭

#### 1.2 사용 예시

```tcl
set str "Hello, World!"

puts [string length $str]        # 13
puts [string index $str 7]       # W
puts [string range $str 0 4]     # Hello
puts [string tolower $str]       # hello, world!
puts [string trim "  abc  "]     # abc
puts [string map {o 0 l 1} $str] # He110, W0r1d!
puts [string replace $str 0 4 "Hi"] # Hi, World!
puts [string match "H*d!" $str]  # 1 (true)
```

### 2. regexp 명령어

regexp는 정규 표현식을 사용한 패턴 매칭을 수행합니다.

#### 2.1 기본 구문

```tcl
regexp 옵션 패턴 문자열 매치변수 서브매치변수1 서브매치변수2 ...
```

#### 2.2 주요 옵션

* **-nocase**: 대소문자 구분 없이 매칭

#### 2.3 사용 예시

```tcl
set str "The quick brown fox"

if {[regexp {(\w+)\s+(\w+)} $str -> first second]} {
    puts "First word: $first, Second word: $second"
}

regexp -nocase {fox} $str match
puts $match  # fox

regexp {(\d+)} "Age: 30" -> age
puts $age  # 30
```

### 3. regsub 명령어

regsub는 정규 표현식을 사용하여 문자열 내의 패턴을 대체합니다.

#### 3.1 기본 구문

```tcl
regsub 옵션 패턴 문자열 대체문자열 결과저장변수
```

#### 3.2 주요 옵션

* **-all**: 모든 매치를 대체
* **-nocase**: 대소문자 구분 없이 매칭

#### 3.3 사용 예시

```tcl
set str "The quick brown fox jumps over the lazy dog"

regsub {(\w+) (\w+)} $str {\2 \1} result
puts $result  # quick The brown fox jumps over the lazy dog

regsub -all {\w+} $str {[\0]} result
puts $result  # [The] [quick] [brown] [fox] [jumps] [over] [the] [lazy] [dog]

regsub -nocase -all {o} $str "0" result
puts $result  # The quick br0wn f0x jumps 0ver the lazy d0g
```

### 4. 정규 표현식 기본 문법

이보다 더 많은 정규 표현식이 있지만, 이 규칙으로 대부분의 처리를 할 수 있습니다.

regular expression은 매우 중요하니, 이것에 대해 자유로워질 때까지 학습하는 것을 추천합니다.

* **.**: 임의의 한 문자
* **^**: 행의 시작
* **$**: 행의 끝
* **\***: 앞 규칙 0회 이상 반복
* **\d**: 숫자
* **\w**: 단어 문자 (알파벳, 숫자, 밑줄)
* **\s**: 공백 문자

### 5. 팁과 요령 💡

* string 명령어는 간단한 문자열 조작에 효율적입니다.
* 복잡한 패턴 매칭이나 대체가 필요할 때는 regexp와 regsub을 사용하세요.
* 정규 표현식은 강력하지만 복잡할 수 있습니다. 가독성을 위해 복잡한 패턴은 주석을 달거나 분리하세요.
