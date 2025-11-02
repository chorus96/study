# 5장: 조건, if

### 1. if 문

if 문은 조건에 따라 코드 블록을 실행하는 데 사용됩니다.

#### 1.1 기본 구문

```tcl
if {조건} {
    # 조건이 참일 때 실행할 코드
} elseif {다른 조건} {
    # 다른 조건이 참일 때 실행할 코드
} else {
    # 모든 조건이 거짓일 때 실행할 코드
}
```

#### 1.2 사용 예시

```tcl
set x 10
if {$x > 0} {
    puts "x is positive"
} elseif {$x < 0} {
    puts "x is negative"
} else {
    puts "x is zero"
}
```

#### 1.3 주의사항 ⚠️

* 조건문과 괄호 사이에 space가 있어야 합니다.
* }와 {사이에도 space가 있어야합니다.
* 조건은 중괄호 `{}` 안에 작성해야 합니다.
* `elseif`와 `else`는 선택사항입니다.
* 조건에는 일반적으로 비교 연산자나 `expr` 명령을 사용합니다.

### 2. switch 문

switch 문은 여러 가능한 값에 따라 다른 코드 블록을 실행하는 데 사용됩니다.

#### 2.1 기본 구문

```tcl
switch [옵션] 문자열 {
    패턴1 {코드1}
    패턴2 {코드2}
    ...
    default {기본 코드}
}
```

#### 2.2 사용 예시

```tcl
set fruit "apple"
switch $fruit {
    "apple" {puts "It's an apple"}
    "banana" {puts "It's a banana"}
    "orange" {puts "It's an orange"}
    default {puts "Unknown fruit"}
}
```

#### 2.3 switch 옵션

* **-exact**: 정확한 문자열 조건 비교
* **-glob**: glob 형태로 문자열 조건 비교
* **-regexp**: Regular expression 형태로 문자열 조건 비교

#### 2.4 고급 사용 예시

```tcl
# -glob 옵션 사용
switch -glob $filename {
    *.txt {puts "Text file"}
    *.jpg {puts "JPEG image"}
    *.* {puts "File with extension"}
    default {puts "Unknown file type"}
}

# -regexp 옵션 사용
switch -regexp $input {
    {^[0-9]+$} {puts "Number"}
    {^[a-zA-Z]+$} {puts "Word"}
    default {puts "Other"}
}
```

### 3. if와 switch 비교

* **if**: 복잡한 조건이나 범위 비교에 적합
* **switch**: 단일 변수나 표현식의 여러 가능한 값을 비교할 때 코드 가독성 높이기 좋음.

### 4. 팁과 요령 💡

* if 문에서 복잡한 조건은 `expr` 명령을 사용하여 평가할 수 있습니다.

  ```tcl
  if {[expr {$x > 0 && $y < 10}]} {
      puts "Condition met"
  }
  ```
* switch 문에서 여러 패턴에 대해 같은 코드를 실행하려면 fall-through를 사용합니다.

  ```tcl
  switch $day {
      "Monday" -
      "Tuesday" -
      "Wednesday" -
      "Thursday" -
      "Friday" {puts "Weekday"}
      "Saturday" -
      "Sunday" {puts "Weekend"}
      default {puts "Invalid day"}
  }
  ```
* 긴 if-elseif 체인은 가독성을 위해 switch 문으로 대체하는 것을 고려하세요.

###
