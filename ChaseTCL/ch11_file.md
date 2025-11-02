# 11장: File in/out

### 1. 파일 열기와 닫기

#### 1.1 파일 열기 (open)

```tcl
set file [open 파일명 모드]
```

주요 모드:

* `r`: 읽기 (기본값)
* `w`: 쓰기 (파일이 존재하면 내용 삭제)
* `a`: 추가 (파일 끝에 쓰기)

예시:

```tcl
set fid [open "example.txt" w]
```

#### 1.2 파일 닫기 (close)

fclose는 fopen이 있다면 꼭 넣어주세요. 없더라도, 최신 OS에선 파일에 심각한 문제를 일으키지 않게 되어있지만, 리소스 관리 측면에서도 필요합니다.

```tcl
close $file
```

### 2. 파일 읽기

#### 2.1 한 줄씩 읽기 (gets)

```tcl
set file [open "read.txt" r]
while {[gets $file line] >= 0} {
    puts $line
}
```

#### 2.2 전체 파일 읽기 (read)

```tcl
set content [read $file]
```

특정 바이트 수만큼 읽기:

```tcl
set partial_content [read $file 100]
```

### 3. 파일 쓰기

#### 3.1 puts 사용

```tcl
set file [open "write.txt" r]
puts $file "Hello, World!"
```

#### 3.2 바이너리 데이터 쓰기

```tcl
# 바이너리 데이터 쓰기
puts -nonewline $file [binary format H* "48656C6C6F"]
```

### 4. 파일 위치 제어

#### 4.1 현재 위치 확인 (tell)

```tcl
set position [tell $file]
```

#### 4.2 위치 이동 (seek)

```tcl
seek $file 오프셋 위치옵션
```

&#x20;옵션:

* `start`: 파일 시작 (기본값)
* `current`: 현재 위치
* `end`: 파일 끝

예시:

```tcl
seek $file 10 start  # 파일 시작에서 10바이트 이동
seek $file -5 current  # 현재 위치에서 5바이트 뒤로
seek $file 0 end  # 파일 끝으로 이동
```

### 5. 파일 정보 및 조작

#### 5.1 파일 존재 여부 확인

```tcl
if {[file exists "filename.txt"]} {
    puts "File exists"
}
```

### 6. 디렉토리 작업

#### 6.1 현재 디렉토리 확인/변경

```tcl
cd "/new/directory/path"
```

#### 6.2 디렉토리 내용 나열

```tcl
set files [glob -directory "/path/to/dir" *]
```

### 7. 파일 채널 설정

파일을 메모리에 쓰는 방식을 정합니다. 대용량 파일 처리시, 퍼포먼스 측면에서 장점이 있습니다.

#### 7.1 버퍼링 설정

```tcl
fconfigure $file -buffering none|line|full
```

#### 7.2 인코딩 설정

```tcl
fconfigure $file -encoding utf-8
```

###
