# 10장: 함수, procedure

### 1. 프로시저 개요

TCL의 프로시저는 재사용 가능한 코드 블록을 정의하는 방법입니다. 함수나 서브루틴과 유사한 개념입니다.

### 2. 프로시저 정의

#### 2.1 기본 구문

```tcl
proc 프로시저이름 {인자리스트} {
    프로시저 본문
}
```

#### 2.2 간단한 예시

```tcl
proc greet {name} {
    puts "Hello, $name!"
}

greet "Chase"  # 출력: Hello, Chase!
```

### 3. 인자 처리

#### 3.1 기본 인자

```tcl
proc add {a b} {
    return [expr {$a + $b}]
}

puts [add 3 4]  # 출력: 7
```

#### 3.2 인자 기본값 설정

```tcl
proc greet {name {greeting "Hello"}} {
    puts "$greeting, $name!"
}

greet "World"            # 출력: Hello, World!
greet "TCL" "Welcome"    # 출력: Welcome, TCL!
```

### 4. 반환

#### 4.1 return 명령어 사용

```tcl
proc multiply {a b} {
    return [expr {$a * $b}]
}

puts [multiply 6 7]  # 출력: 42
```

#### 4.2 암시적 반환

프로시저의 마지막 명령의 결과가 자동으로 반환됩니다.

```tcl
proc last_element {list} {
    lindex $list end
}

puts [last_element {1 2 3 4 5}]  # 출력: 5
```

### 5. 변수 스코프

#### 5.1 지역 변수

프로시저 내에서 선언된 변수는 기본적으로 지역 변수입니다.

기본적으로, 전역 스코프 -> proc 변수에 접근할 수 없습니다.

```tcl
proc local_var_example {} {
    set x 10
    puts $x
}

local_var_example  # 출력: 10
puts $x  # 오류: x는 정의되지 않음
```

#### 5.2 전역 변수 사용

global 키워드를 사용하면, proc -> 전역 변수에 접근할 수 있습니다.

```tcl
set global_var 100

proc global_var_example {} {
    global global_var
    puts $global_var
}

global_var_example  # 출력: 100
```

#### 5.3 upvar 사용

상위 스코프의 변수를 참조할 수 있습니다.

```tcl
proc modify_var {var_name new_value} {
    upvar $var_name local_var
    set local_var $new_value
}

set x 5
modify_var x 10
puts $x  # 출력: 10
```

### 6. 프로시저 정보 얻기

#### 6.1 info 명령어 사용

```tcl
proc example {a {b 10} args} {
    # 프로시저 본문
}

puts [info args example]     # 출력: a b args
puts [info body example]     # 프로시저 본문 출력
puts [info default example b default_value]  # 출력: 1 10
```

### 7. 재귀 함수

TCL은 재귀 프로시저를 지원합니다.

<pre class="language-tcl"><code class="lang-tcl">proc factorial {n} {
    if {$n &#x3C;= 1} {
        return 1
    } else {
        return [expr {$n * [factorial [expr {$n - 1}]]}]
    }
<strong>}
</strong>
puts [factorial 5]  # 출력: 120
</code></pre>

### 8. 성능 고려사항 🚀

* 프로시저 호출에는 약간의 오버헤드가 있습니다. 인라인 코드가 더 빠릅니다.
* 자주 호출되는 프로시저의 경우, 인자 검사와 기본값 처리를 최소화하는 것이 좋습니다.

### 10. 팁과 요령 💡

* 프로시저 이름은 의미있고 설명적으로 짓습니다.
* 복잡한 프로시저는 주석을 통해 목적과 사용법을 설명합니다.
* 프로시저가 예상치 못한 상황에서 오류를 발생시키려면 `error` 명령을 사용합니다. 그렇지 않으면 디버그가 매우 어렵습니다.
