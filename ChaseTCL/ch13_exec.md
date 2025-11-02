# 13장: 실행 exec, eval

### 1. exec 명령어

exec는 외부 시스템 명령을 실행하는 데 사용됩니다.

#### 1.1 사용예시

```tcl
set result [exec whoami]
puts $result
```

### 2. eval 명령어

eval은 문자열을 TCL 코드로 해석하고 실행합니다.

#### 2.1 기본 구문

```tcl
eval 인자
```

#### 2.2 사용 예시

```tcl
# 단순한 문자열 평가
set command "puts \"Hello, World!\""
eval $command

# 동적으로 생성된 코드 실행
set op "+"
set a 5
set b 3
set result [eval expr $a $op $b]
puts $result  # 출력: 8

# 리스트를 명령으로 실행
set cmd [list set var 10]
eval $cmd
puts $var  # 출력: 10
```

#### 2.3 중요 포인트

* eval은 인자들을 하나의 문자열로 연결한 후 실행합니다.
* 여러 단계의 변수 치환이 필요한 경우 유용합니다.

### 3. exec와 eval 비교

* exec: 외부 시스템 명령 실행
* eval: TCL 코드 문자열 실행

### 4. 성능 고려사항 🚀

* exec는 새 프로세스를 생성하므로 빈번한 사용은 성능에 영향을 줄 수 있습니다. tcl 내장명령으로 실행 가능한 경우, tcl 내장 명령을 사용하세요.
