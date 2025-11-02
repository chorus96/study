# 8장: 반환, return

### 1. break 명령어

break는 현재의 루프나 switch 문을 즉시 종료합니다.

#### 1.1 사용 예시

```tcl
for {set i 0} {$i < 10} {incr i} {
    if {$i == 5} {
        break
    }
    puts $i
}
puts "Loop ended"
```

#### 1.2 주의사항 ⚠️

* 가장 안쪽의 루프만 종료합니다. 중첩된 루프에서 외부 루프를 종료하려면 추가 로직이 필요합니다.

### 2. continue 명령어

continue는 현재 루프 반복을 중단하고 다음 반복으로 건너뜁니다.

#### 2.1 사용 예시

```tcl
for {set i 0} {$i < 5} {incr i} {
    if {$i == 2} {
        continue
    }
    puts $i
}
```

#### 2.2 주의사항 ⚠️

* while 루프에서 사용 시, 증감식이 실행되지 않을 수 있으므로 주의가 필요합니다.

### 3. catch 명령어

catch는 명령 실행 중 발생하는 오류를 캐치합니다.

#### 3.1 기본 구문

```tcl
catch {스크립트} [결과변수] [옵션]
```

#### 3.2 사용 예시

```tcl
if {[catch {open "nonexistent.txt" r} fid]} {
    puts "Couldn't open the file: $fid"
} else {
    puts "File opened successfully"
    close $fid
}
```

### 4. return 명령어

return은 현재 프로시저에서 값을 반환하고 실행을 종료합니다.

#### 4.1 기본 구문

```tcl
return [값]
```

#### 4.2 사용 예시

```tcl
proc add {a b} {
    return [expr {$a + $b}]
}
puts [add 3 4]  # 출력: 7
```

#### 4.3 주의사항 ⚠️

* 전역 스코프에서 사용 시 스크립트 전체 실행을 종료합니다.

### 5. error 명령어

error는 오류를 발생시키고 스크립트 실행을 중단합니다.

#### 5.1 기본 구문

```tcl
error 메시지 [정보] [코드]
```

#### 5.2 사용 예시

```tcl
proc divide {a b} {
    if {$b == 0} {
        error "Division by zero" "in divide function" DIVIDE_BY_ZERO
    }
    return [expr {$a / $b}]
}

if {[catch {divide 10 0} result options]} {
    puts "Error: $result"
    puts "Info: [dict get $options -errorinfo]"
    puts "Code: [dict get $options -errorcode]"
}
```

### 6. 제어 흐름 명령어 조합 사용

```tcl
proc process_data {data} {
    foreach item $data {
        if {[catch {process_item $item} result]} {
            puts "Error processing item $item: $result"
            continue
        }
        if {$result eq "STOP"} {
            break
        }
    }
    return "Processing complete"
}
```

### 7. 팁과 요령 💡

* catch를 과도하게 사용하면 디버깅이 어려워질 수 있습니다. 필요한 곳에만 사용하세요.
* return -code error를 사용하여 error 명령어와 유사한 효과를 낼 수 있습니다.
