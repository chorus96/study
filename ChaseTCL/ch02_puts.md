# 2장: 출력, puts

### 1. puts 명령 개요

puts 명령은 TCL에서 텍스트를 출력하는 기본 도구입니다.

**기본 구문:**

```tcl
puts 옵션 문자열
```

### 2. 주요 특징

* 콘솔이나 파일에 텍스트 출력
* 기본적으로 마지막에 줄바꿈 자동 추가
* 변수 값, 연산 결과 등 다양한 형태의 출력 지원

### 3. 사용 예시

```tcl
puts "Hello, World!"
Hello, World!
set name "Chase"
puts "Welcome, $name!"
Welcome, Chase!
puts {This is a multi-line
text output example}
This is a multi-line
text output example
```

### 4. 옵션 및 고급 기능

* **-nonewline:** 줄바꿈 없이 출력

  ```tcl
  puts -nonewline "Enter your name: "
  puts "Chase"
  Enter your name: Chase
  ```
* **채널 지정:** 출력 대상 지정 (예: output.txt라는 파일에 저장하기)

  ```tcl
  set file [open "output.txt" w]
  puts $file "Chase"
  close $file
  ```

### 5. Backslash Sequences 🔤

Backslash Sequences는 특수 문자나 제어 문자를 표현하는 데 사용됩니다. 주로 큰따옴표로 묶인 문자열 내에서 사용됩니다.

#### 5.1 Backslash Sequences 사용 예시

```tcl
puts "Hello\nWorld"           # 줄바꿈
puts "Tab\tSeparated\tValues" # 탭으로 구분
puts "Quotes: \"Example\""    # 큰따옴표 출력
puts "Path: C:\\Program Files"  # 백슬래시 출력
puts "Unicode: \u03B1\u03B2\u03B3"  # 그리스 문자 알파, 베타, 감마
puts "Octal: \141\142\143"   # a, b, c (8진수 ASCII)
puts "Hex: \x61\x62\x63"     # a, b, c (16진수 ASCII)
```

#### 5.2 주의사항 ⚠️

* 중괄호로 묶인 문자열에서는 Backslash Sequences가 처리되지 않습니다.

  ```tcl
  puts {This \n will not create a new line}
  ```
* 변수 치환과 Backslash Sequences를 함께 사용할 때 주의가 필요합니다.

  ```tcl
  set name "Chase"
  puts "Hello, $name\nWelcome!"  # 변수 치환과 줄바꿈 함께 사용
  ```

### 6. 팁과 요령 💡

* **디버깅용 출력:** 변수 값이나 프로그램 상태 확인에 유용

  ```tcl
  puts "Debug: value of x is $x"
  ```
* **형식화된 출력:** format 명령과 함께 사용

  ```tcl
  puts [format "Pi: %.2f" 3.14159]
  ```
* **에러 메시지:** stderr 채널 사용

  ```tcl
  puts stderr "Error: File not found"
  ```
* **Backslash Sequences 활용:** 복잡한 문자열 구성 시 유용

  ```tcl
  puts "Menu:\n1. Open\n2. Save\n3. Exit"
  ```

Curly braces는 { }, Squeare bracket은 \[] 입니다. 이 키워드를 알면 에러 디버그가 수월해집니다.
