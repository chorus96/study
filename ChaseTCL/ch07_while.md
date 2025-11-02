# 7장: 반복, while

### 1. for 루프

for 루프는 지정된 횟수만큼 코드 블록을 반복 실행합니다.

#### 1.1 기본 구문

```tcl
for {시작코드} {조건} {증감} {
    # 반복 실행할 코드
}
```

#### incr은 반복문의 친구입니다. incr 명령은 인자의 값을 1 증가시키고, decr은 감소시킵니다.&#x20;

#### 1.2 사용 예시

```tcl
for {set i 0} {$i < 5} {incr i} {
    puts "Iteration $i"
}
```

#### 1.3 주의사항 ⚠️

* 각 부분(초기화, 조건, 증감)은 중괄호 `{}` 안에 작성해야 합니다.
* 조건이 false가 되면 루프가 종료됩니다.
* 무한 반복 식이 되면, 강제로 종료 되기 이전까지 계속 실행됩니다.

### 2. foreach 루프

foreach 루프는 리스트의 각 요소에 대해 코드 블록을 반복 실행합니다.

tcl 사용자들이 가장 많이 사용하는 반복문입니다.

#### 2.1 기본 구문

```tcl
foreach 변수 리스트 {
    # 반복 실행할 코드
}
```

#### 2.2 사용 예시

```tcl
set fruit_list {apple banana orange}
foreach fruit $fruit_list {
    puts "I like $fruit"
}
```

#### 2.3 고급 사용법

여러 변수와 리스트 사용:

```tcl
set data {John 25 Mary 30 Tom 22}
foreach {name age} $data {
    puts "$name is $age years old"
}
```

```tcl
set data1_list {a b c}
set data2_list {1 2 3}
foreach data1 $data1_list data2 $data2_list {
    puts "$data1 $data2"
}
```

2.4 주의사항 ⚠️

* 리스트의 요소 수가 변수의 수로 나누어 떨어지지 않으면 마지막 반복에서 일부 변수가 빈 문자열로 설정될 수 있습니다.

### 3. while 루프

while 루프는 조건이 참인 동안 코드 블록을 반복 실행합니다.

#### 3.1 기본 구문

```tcl
while {조건} {
    # 반복 실행할 코드
}
```

#### 3.2 사용 예시

```tcl
set count 0
while {$count < 5} {
    puts "Count: $count"
    incr count
}
```

#### 3.3 주의사항 ⚠️

* 무한 루프를 피하기 위해 루프 내에서 조건을 변경하는 코드가 필요합니다.

### 4. 루프 제어 명령어

* **break**: 현재 반복문을 종료하고&#x20;
* **continue**: 현재 반복에서 중도 종료하고, 다음 반복으로 이동

사용 예시:

```tcl
for {set i 0} {$i < 10} {incr i} {
    if {$i == 5} {
        continue  # 5일 때 건너뛰기
    }
    if {$i == 8} {
        break  # 8일 때 루프 종료
    }
    puts $i
}
```

### 5. 루프 선택 가이드

* **for**: 정해진 횟수만큼 반복할 때 사용
* **foreach**: 리스트나 배열의 모든 요소를 처리할 때 사용
* **while**: 조건이 참인 동안 계속 반복해야 할 때 사용

### 6. 팁과 요령 💡

* 성능이 중요한 경우, 가능하면 foreach를 사용하세요. TCL에서 foreach는 일반적으로 가장 빠른 루프 구조입니다.
* 반복문은 Big O의 시간복잡도를 크게 높이는 항목입니다. 다중 루프문을 최소화하세요.
* 큰 리스트를 처리할 때는 메모리 사용에 주의하세요. 필요하다면 리스트를 청크로 나누어 처리하세요.
* 루프 내에서 리스트를 수정할 때는 주의가 필요합니다. 특히 foreach 루프에서 현재 처리 중인 리스트를 수정하면 예상치 못한 결과가 발생할 수 있습니다.
