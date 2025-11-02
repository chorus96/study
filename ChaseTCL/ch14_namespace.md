# 14장: namespace

### 1. namespace 개요

TCL의 namespace는 변수와 프로시저를 논리적으로 그룹화하여 이름 충돌을 방지하고 코드를 모듈화하는 메커니즘입니다.

namespace, double colon, array는 대규모 변수 data 처리를 하는데 유리합니다. 소규모 변수 스크립팅만 하는 경우, 14\~16장은 넘어가셔도 됩니다. (난이도가 있어서, 포기하실까봐 :joy:)

### 2. namespace 생성 및 사용

#### 2.1 namespace 생성

```tcl
namespace eval MyNamespace {
    variable myVar 10
    proc myProc {} {
        puts "Hello from MyNamespace"
    }
}
```

#### 2.2 namespace 내 요소 접근

::는 Double colon이라고 불립니다. 다음 장에서 자세히 살펴봅니다.

```tcl
puts $MyNamespace::myVar 
# 출력: 10
MyNamespace::myProc 
# 출력: Hello from MyNamespace
```

### 3. namespace 명령어

#### 3.1 현재 namespace 확인

```tcl
puts [namespace current]
```

#### 3.2 namespace 목록 조회

```tcl
puts [namespace children ::]
```

#### 3.3 namespace 존재 여부 확인

```tcl
if {[namespace exists MyNamespace]} {
    puts "MyNamespace exists"
}
```

#### 3.4 namespace 삭제

```tcl
namespace delete MyNamespace
```

### 4. namespace 중첩

namespace는 중첩될 수 있습니다.

```tcl
namespace eval Outer {
    namespace eval Inner {
        variable innerVar 20
        proc innerProc {} {
            puts "Inner procedure"
        }
    }
}

puts $Outer::Inner::innerVar
Outer::Inner::innerProc
```

### 5. namespace import/export

#### 5.1 명령어 export

```tcl
namespace eval MyNS {
    namespace export myCmd
    proc myCmd {} {
        puts "MyNS command"
    }
}
```

#### 5.2 명령어 import

```tcl
namespace import MyNS::myCmd
myCmd  
# 이제 현재 namespace에서 직접 사용 가능
```

### 6. namespace path

다른 namespace의 명령어를 import 없이 사용할 수 있게 합니다.

```tcl
namespace eval MyNS {
    proc myProc {} {
        puts "MyNS procedure"
    }
}

namespace eval OtherNS {
    namespace path ::MyNS
    myProc  
    # MyNS::myProc를 직접 호출
}
```

### 7. namespace 변수

#### 7.1 변수 선언

```tcl
namespace eval MyNS {
    variable myVar 30
}
```

#### 7.2 변수 접근

```tcl
puts $MyNS::myVar

namespace eval MyNS {
    puts $myVar  
    # namespace 내에서는 직접 접근 가능
}
```

### 8. namespace ensemble

관련 명령어들을 그룹화하여 사용할 수 있습니다.

```tcl
namespace eval math {
    namespace export add subtract
    proc add {a b} {return [expr {$a + $b}]}
    proc subtract {a b} {return [expr {$a - $b}]}
    namespace ensemble create -command math -subcommands {add subtract}
}

puts [math add 5 3]      # 출력: 8
puts [math subtract 10 4] # 출력: 6
```

### 9. 주의사항 ⚠️

* 전역 namespace를 과도하게 오염시키지 않도록 주의하세요.
* namespace 이름 충돌에 주의하세요.
* import 사용 시 이름 충돌 가능성을 고려하세요.

### 10. 팁과 요령 💡

* 큰 프로젝트에서는 namespace를 사용하여 코드를 모듈화하세요.
* namespace 이름은 의미있고 명확하게 지으세요.
* 필요한 경우 namespace 별칭을 사용하여 긴 이름을 간소화할 수 있습니다.
* namespace 내부에서 변수를 사용할 때는 `variable` 명령어를 사용하세요.

### 11. 성능 고려사항 🚀

* namespace를 과도하게 중첩하면 성능에 영향을 줄 수 있습니다.
* **자주 사용되는 명령어의 경우, 전체 경로를 사용하는 것보다 import하여 사용하는 것이 약간 더 빠를 수 있습니다.**

TCL의 namespace를 마스터하여 깔끔하고 모듈화된 코드를 작성하세요!
