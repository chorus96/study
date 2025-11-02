# 설치

## TCL 설치 가이드 🛠️

Linux와 macOS는 기본적으로 TCL이 설치되어있습니다. 그리고 대부분 TCL을 사용하는 응용프로그램은 Linux를 기반으로 합니다. 그래서 Linux 환경에서 익숙해지시는 것을 권장하지만, Linux를 사용 할 수 없는 경우를 위해 설명합니다.

그리고, 이 글은 Linux를 기준으로 설명합니다. Linux 설치는 'Linux virtualbox 설치'를 검색하시면 됩니다.

온라인으로도 TCL 연습이 가능한데, 'TCL Online Compiler'로 검색하면, 간단한 연습이 가능합니다. Windows에서 꼭 하고싶으신 경우를 위해 아래 방식을 설명합니다.

### Windows에 TCL 설치하기

1. ActiveState TCL 다운로드:
   * [ActiveState TCL 웹사이트](https://www.activestate.com/products/tcl/)에 접속합니다.
   * "Download ActiveTcl" 버튼을 클릭합니다.
   * 운영 체제와 비트에 맞는 버전을 선택하여 다운로드합니다.
2. 설치 파일 실행:
   * 다운로드한 .exe 파일을 더블클릭하여 실행합니다.
   * 설치 마법사의 지시에 따라 설치를 진행합니다.
3. 설치 확인:
   * 명령 프롬프트를 열고 `tclsh` 명령을 입력하여 TCL 셸이 실행되는지 확인합니다.

### 시작합니다.

### 1. 실행

#### 1.1 tclsh 인터프리터 호출 방식

TCL 스크립트 파일에 다음과 같이 작성하고 hello\_world.tcl 파일으로 저장합니다.

```tcl
puts "Hello, World!"
```

#### Linux 터미널에서 다음 첫 줄처럼 실행하면, 두번째 줄 처럼 출력 되는 것을 볼 수 있습니다.

```sh
tclsh hello_world.tcl
Hello, World!
```

그리고 아래 방식도 가능합니다.&#x20;

```tcl
tclsh
source hello_world.tcl
Hello, World!
```

#### 1.2 TCL 스크립트에서 #! (Shebang) 사용

TCL 스크립트 파일의 첫 줄에 다음과 같이 작성하고, hello\_world\_shebang.tcl으로 저장합니다.

```tcl
#!/usr/bin/tclsh
puts "Hello, World!"
```

#### 1.3 #!의 의미

* `#!`: 이 두 문자로 시작하여 운영 체제에 이 파일이 Script 임을 알립니다. 2 Byte 의 Magic Number로, 스크립트의 맨 앞에서 이 파일이 어떤 명령어 해석기의 명령어 집합인지를 시스템에 알려주는 역할을 합니다. 바로 뒤에 나오는 것은 인터프리터 위치를 지정해주시면 됩니다.
* `/usr/bin/tclsh`: TCL 인터프리터의 경로를 지정합니다. 혹은 `/usr/bin/env tclsh`를 사용하면 시스템 환경 변수에 설정된 TCL 인터프리터를 찾아 실행합니다.

#### Linux 터미널에서 다음처럼 실행합니다.

#### 첫번째 줄은, 나에게만 파일의 읽기, 쓰기, 실행 권한을 부여합니다. 두번째 줄처럼 실행하면, 세번째 줄 처럼 출력 되는 것을 볼 수 있습니다.

```tcl
chmod 700 hello_world_shebang.tcl
./hello_world_shebang.tcl
Hello, World!
```

#### 1.4 #! 사용의 장점

1. 스크립트 파일을 직접 실행 가능하게 만듭니다.
2. 올바른 인터프리터를 자동으로 선택합니다.
3. 다양한 환경에서 스크립트의 이식성을 높입니다.
