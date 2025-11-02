# 1장: 변수, set

### 1. set 명령은 TCL에서 변수를 생성하고 값을 할당하는 기본 도구입니다.

**기본 구문:**

```tcl
set 변수명 값
```

### 2. set 주요 특징

* 변수 생성과 값 할당을 동시에 수행
* 기존 변수 값을 직접 변경 가능
* 변수 값 읽기에도 사용 가능

### 3. set 사용 예시

puts에 대한 설명은 다음 장에 자세히 설명되는 '출력 명령'입니다.

연습을 위해 리눅스 터미널에서 tclsh를 실행합니다.

```tcl
set name Chase
set name
Chase
puts $name
Chase
set full_name "Chase Na"
set full_name
Chase Na
puts $full_name
set numbers {1 2 3 4 5}
set numbers
1 2 3 4 5
set person(age) 25
set person(age)
25
exit
```

### 4. set 고급 기능

* **띄어쓰기를 포함한 값 할당:** `set 변수명 "값1 값2"` 혹은 `set 변수명 {값1 값2}` 사용
* **배열 요소 설정:** `set 변수명(키) 값`형식 사용
* **변수 값 읽기:** `set 변수명`

### 5. 변수 제한사항

#### 5.1 변수명 제한 ⚠️

* **시작:** 문자, 숫자 또는 밑줄(\_)만 가능
* **사용 가능:** 문자, 숫자, 밑줄
* **사용 불가:** 공백, 특수문자 (예: @, #, $, %)
* **예약어 사용 불가** (if, else, proc 등)

#### 5.2 값 제한 🔢

* 기본적으로, 할당 값에 제한이 없는 Concept.
* 모든 값은 문자열 형태로 저장. (C언어처럼, int, char 고민 줄여도 됨.)
* 메모리 한계까지 긴 문자열 가능 (TCL 버전마다 다름)

### 6. 특수문자 처리 🔣

#### Quote 포함:

```tcl
set message {He said "Hello"}
puts $message
set message "He said \"Hello\""
puts $message
```

#### Bracket 포함:

<pre class="language-tcl"><code class="lang-tcl"><strong>set code {puts \[set x 10\]}
</strong><strong>puts $code
</strong></code></pre>

#### Dollar 기호 포함:

```tcl
set price \$5.99
puts $price
```

### 7. unset 명령 🗑️

unset 명령은 변수를 삭제하는 데 사용됩니다.

**기본 구문:**

```tcl
unset 변수명
```

#### 7.1 unset 사용 예시

```tcl
set x 10
puts $x
unset x
puts $x
```

#### 7.2 unset 특징

* 여러 변수 동시 삭제 가능: `unset 변수1 변수2 변수3`
* 배열 요소 삭제: `unset arr(key)`
* 전체 배열 삭제: `unset arr`

### 8. 팁과 요령 💡

* **변수 존재 여부 확인:** `info exists 변수명`
* **전역 변수 선언:** `global 선언된변수`
* **임시 변수 관리:** 사용 후 불필요한 변수는 리소스 최적화를 위해 unset으로 정리
* 리눅스의 환경 변수는 env(변수명)에 저장되어있습니다.
